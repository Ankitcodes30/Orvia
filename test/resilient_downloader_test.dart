import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import 'package:Orvia/services/updater/orvia_update_service.dart';

void main() {
  final payloadBytes = Uint8List.fromList(
    List<int>.generate(256 * 1024, (i) => (i * 31 + 7) & 0xFF),
  );
  final payloadSha256 = sha256.convert(payloadBytes).toString();
  const testUrl = 'https://ankitcodes30.github.io/Orvia/downloads/app-release.apk';

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('orvia_resilient_dl_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  List<File> listPartFiles(Directory dir) {
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).contains('.part_'))
        .toList();
  }

  group('OrviaUpdateService Resilient Downloader Tests', () {
    test('1. successful full download verifies size, progress, and SHA-256',
        () async {
      final client = MockClient.streaming((request, bodyStream) async {
        expect(request.headers.containsKey('range'), isFalse);
        final mid = payloadBytes.length ~/ 2;
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable([
            payloadBytes.sublist(0, mid),
            payloadBytes.sublist(mid),
          ]),
          200,
          contentLength: payloadBytes.length,
          headers: {'etag': '"v1"', 'accept-ranges': 'bytes'},
        );
      });

      final service = OrviaUpdateService(client: client);
      final dest = File(p.join(tempDir.path, 'app-release.apk'));
      final progressEvents = <int>[];

      final out = await service.downloadAndVerifyFile(
        downloadUrl: testUrl,
        expectedSha256: payloadSha256,
        expectedFileSize: payloadBytes.length,
        initialBackoff: Duration.zero,
        destinationFile: dest,
        onProgress: (received, total) {
          expect(total, payloadBytes.length);
          progressEvents.add(received);
        },
      );

      expect(out.existsSync(), isTrue);
      expect(out.lengthSync(), payloadBytes.length);
      expect(sha256.convert(out.readAsBytesSync()).toString(), payloadSha256);
      expect(progressEvents.last, payloadBytes.length);
      expect(listPartFiles(tempDir), isEmpty);
    });

    test(
        '2. connection interrupted halfway resumes cleanly using HTTP 206 and If-Range',
        () async {
      final split = 100 * 1024;
      int callCount = 0;
      String? seenRange;
      String? seenIfRange;

      final client = MockClient.streaming((request, bodyStream) async {
        callCount++;
        if (callCount == 1) {
          final controller = StreamController<List<int>>();
          () async {
            controller.add(payloadBytes.sublist(0, split));
            await Future<void>.delayed(const Duration(milliseconds: 10));
            controller.addError(
              http.ClientException(
                'Connection closed while receiving data',
                request.url,
              ),
            );
            await controller.close();
          }();
          return http.StreamedResponse(
            controller.stream,
            200,
            contentLength: payloadBytes.length,
            headers: {'etag': '"etag-v1"', 'accept-ranges': 'bytes'},
          );
        }

        seenRange = request.headers['range'];
        seenIfRange = request.headers['if-range'];
        final remaining = payloadBytes.sublist(split);
        return http.StreamedResponse(
          Stream<List<int>>.value(remaining),
          206,
          contentLength: remaining.length,
          headers: {
            'etag': '"etag-v1"',
            'content-range':
                'bytes $split-${payloadBytes.length - 1}/${payloadBytes.length}',
          },
        );
      });

      final service = OrviaUpdateService(client: client);
      final dest = File(p.join(tempDir.path, 'resumed.apk'));

      final out = await service.downloadAndVerifyFile(
        downloadUrl: testUrl,
        expectedSha256: payloadSha256,
        expectedFileSize: payloadBytes.length,
        initialBackoff: Duration.zero,
        destinationFile: dest,
      );

      expect(callCount, 2);
      expect(seenRange, 'bytes=$split-');
      expect(seenIfRange, '"etag-v1"');
      expect(out.lengthSync(), payloadBytes.length);
      expect(sha256.convert(out.readAsBytesSync()).toString(), payloadSha256);
      expect(listPartFiles(tempDir), isEmpty);
    });

    test('3. server ignores Range and returns HTTP 200 restarts safely',
        () async {
      final split = 64 * 1024;
      int callCount = 0;

      final client = MockClient.streaming((request, bodyStream) async {
        callCount++;
        if (callCount == 1) {
          final controller = StreamController<List<int>>();
          () async {
            controller.add(payloadBytes.sublist(0, split));
            await Future<void>.delayed(const Duration(milliseconds: 5));
            controller.addError(
              http.ClientException('Connection closed while receiving data'),
            );
            await controller.close();
          }();
          return http.StreamedResponse(
            controller.stream,
            200,
            contentLength: payloadBytes.length,
            headers: {'etag': '"etag-200"'},
          );
        }

        // Server ignores Range and returns full 200 OK
        return http.StreamedResponse(
          Stream<List<int>>.value(payloadBytes),
          200,
          contentLength: payloadBytes.length,
          headers: {'etag': '"etag-200"'},
        );
      });

      final service = OrviaUpdateService(client: client);
      final dest = File(p.join(tempDir.path, 'fallback200.apk'));

      final out = await service.downloadAndVerifyFile(
        downloadUrl: testUrl,
        expectedSha256: payloadSha256,
        expectedFileSize: payloadBytes.length,
        initialBackoff: Duration.zero,
        destinationFile: dest,
      );

      expect(callCount, 2);
      expect(out.lengthSync(), payloadBytes.length);
      expect(sha256.convert(out.readAsBytesSync()).toString(), payloadSha256);
      expect(listPartFiles(tempDir), isEmpty);
    });

    test('4. invalid Content-Range on HTTP 206 is rejected without corrupting destination',
        () async {
      final split = 32 * 1024;
      int callCount = 0;

      final client = MockClient.streaming((request, bodyStream) async {
        callCount++;
        if (callCount == 1) {
          final controller = StreamController<List<int>>();
          () async {
            controller.add(payloadBytes.sublist(0, split));
            controller.addError(
              http.ClientException('Connection closed while receiving data'),
            );
            await controller.close();
          }();
          return http.StreamedResponse(
            controller.stream,
            200,
            contentLength: payloadBytes.length,
          );
        }
        // Wrong start offset (0 instead of split)
        return http.StreamedResponse(
          Stream<List<int>>.value(payloadBytes.sublist(split)),
          206,
          contentLength: payloadBytes.length - split,
          headers: {
            'content-range':
                'bytes 0-${payloadBytes.length - 1}/${payloadBytes.length}',
          },
        );
      });

      final service = OrviaUpdateService(client: client);
      final dest = File(p.join(tempDir.path, 'bad_range.apk'));

      await expectLater(
        () => service.downloadAndVerifyFile(
          downloadUrl: testUrl,
          expectedSha256: payloadSha256,
          initialBackoff: Duration.zero,
          destinationFile: dest,
        ),
        throwsA(isA<HttpException>()),
      );

      expect(dest.existsSync(), isFalse);
      expect(listPartFiles(tempDir), isEmpty);
    });

    test('5. ETag changes during resume restarts cleanly from byte 0',
        () async {
      final split = 50 * 1024;
      int callCount = 0;

      final client = MockClient.streaming((request, bodyStream) async {
        callCount++;
        if (callCount == 1) {
          final controller = StreamController<List<int>>();
          () async {
            controller.add(payloadBytes.sublist(0, split));
            controller.addError(
              http.ClientException('Connection closed while receiving data'),
            );
            await controller.close();
          }();
          return http.StreamedResponse(
            controller.stream,
            200,
            contentLength: payloadBytes.length,
            headers: {'etag': '"old-etag"'},
          );
        }
        if (callCount == 2) {
          // Proxy ignores If-Range and returns 206 with new ETag
          return http.StreamedResponse(
            Stream<List<int>>.value(payloadBytes.sublist(split)),
            206,
            contentLength: payloadBytes.length - split,
            headers: {
              'etag': '"new-etag"',
              'content-range':
                  'bytes $split-${payloadBytes.length - 1}/${payloadBytes.length}',
            },
          );
        }
        // Attempt 3: fresh full download after ETag mismatch reset
        expect(request.headers.containsKey('range'), isFalse);
        return http.StreamedResponse(
          Stream<List<int>>.value(payloadBytes),
          200,
          contentLength: payloadBytes.length,
          headers: {'etag': '"new-etag"'},
        );
      });

      final service = OrviaUpdateService(client: client);
      final dest = File(p.join(tempDir.path, 'etag_change.apk'));

      final out = await service.downloadAndVerifyFile(
        downloadUrl: testUrl,
        expectedSha256: payloadSha256,
        expectedFileSize: payloadBytes.length,
        initialBackoff: Duration.zero,
        destinationFile: dest,
      );

      expect(callCount, 3);
      expect(out.lengthSync(), payloadBytes.length);
      expect(sha256.convert(out.readAsBytesSync()).toString(), payloadSha256);
    });

    test('6. repeated network interruptions across multiple chunks succeed within retry budget',
        () async {
      final chunkSize = 64 * 1024;
      int callCount = 0;

      final client = MockClient.streaming((request, bodyStream) async {
        callCount++;
        if (callCount == 1) {
          final c = StreamController<List<int>>();
          () async {
            c.add(payloadBytes.sublist(0, chunkSize));
            c.addError(http.ClientException('Drop 1'));
            await c.close();
          }();
          return http.StreamedResponse(
            c.stream,
            200,
            contentLength: payloadBytes.length,
            headers: {'etag': '"multi"'},
          );
        }

        final rangeHeader = request.headers['range'] ?? '';
        final match = RegExp(r'^bytes=(\d+)-$').firstMatch(rangeHeader);
        final offset = int.parse(match!.group(1)!);
        final end = (offset + chunkSize).clamp(0, payloadBytes.length);

        if (end < payloadBytes.length) {
          final c = StreamController<List<int>>();
          () async {
            c.add(payloadBytes.sublist(offset, end));
            c.addError(const SocketException('Drop mid-chunk'));
            await c.close();
          }();
          return http.StreamedResponse(
            c.stream,
            206,
            contentLength: payloadBytes.length - offset,
            headers: {
              'etag': '"multi"',
              'content-range':
                  'bytes $offset-${payloadBytes.length - 1}/${payloadBytes.length}',
            },
          );
        }

        return http.StreamedResponse(
          Stream<List<int>>.value(payloadBytes.sublist(offset)),
          206,
          contentLength: payloadBytes.length - offset,
          headers: {
            'etag': '"multi"',
            'content-range':
                'bytes $offset-${payloadBytes.length - 1}/${payloadBytes.length}',
          },
        );
      });

      final service = OrviaUpdateService(client: client);
      final dest = File(p.join(tempDir.path, 'multi_drop.apk'));

      final out = await service.downloadAndVerifyFile(
        downloadUrl: testUrl,
        expectedSha256: payloadSha256,
        expectedFileSize: payloadBytes.length,
        maxRetries: 4,
        initialBackoff: Duration.zero,
        destinationFile: dest,
      );

      expect(callCount, 4);
      expect(sha256.convert(out.readAsBytesSync()).toString(), payloadSha256);
    });

    test('7. retry exhaustion cleans up partial files and leaves no incomplete APK',
        () async {
      int callCount = 0;
      final client = MockClient.streaming((request, bodyStream) async {
        callCount++;
        final c = StreamController<List<int>>();
        () async {
          c.add(payloadBytes.sublist(0, 1024));
          c.addError(http.ClientException('Persistent drop #$callCount'));
          await c.close();
        }();
        final offset = (callCount - 1) * 1024;
        return http.StreamedResponse(
          c.stream,
          callCount == 1 ? 200 : 206,
          contentLength: payloadBytes.length - offset,
          headers: callCount == 1
              ? {'etag': '"exhaust"'}
              : {
                  'etag': '"exhaust"',
                  'content-range':
                      'bytes $offset-${payloadBytes.length - 1}/${payloadBytes.length}',
                },
        );
      });

      final service = OrviaUpdateService(client: client);
      final dest = File(p.join(tempDir.path, 'exhausted.apk'));

      await expectLater(
        () => service.downloadAndVerifyFile(
          downloadUrl: testUrl,
          expectedSha256: payloadSha256,
          maxRetries: 2,
          initialBackoff: Duration.zero,
          destinationFile: dest,
        ),
        throwsA(isA<http.ClientException>()),
      );

      expect(callCount, 3);
      expect(dest.existsSync(), isFalse);
      expect(listPartFiles(tempDir), isEmpty);
    });

    test('8. per-chunk stall timeout triggers retry and Range resume',
        () async {
      final split = 40 * 1024;
      int callCount = 0;

      final client = MockClient.streaming((request, bodyStream) async {
        callCount++;
        if (callCount == 1) {
          final c = StreamController<List<int>>();
          c.add(payloadBytes.sublist(0, split));
          // Intentionally never close or send more chunks -> stall
          return http.StreamedResponse(
            c.stream,
            200,
            contentLength: payloadBytes.length,
            headers: {'etag': '"stall"'},
          );
        }

        final remaining = payloadBytes.sublist(split);
        return http.StreamedResponse(
          Stream<List<int>>.value(remaining),
          206,
          contentLength: remaining.length,
          headers: {
            'etag': '"stall"',
            'content-range':
                'bytes $split-${payloadBytes.length - 1}/${payloadBytes.length}',
          },
        );
      });

      final service = OrviaUpdateService(client: client);
      final dest = File(p.join(tempDir.path, 'stall.apk'));

      final out = await service.downloadAndVerifyFile(
        downloadUrl: testUrl,
        expectedSha256: payloadSha256,
        expectedFileSize: payloadBytes.length,
        chunkTimeout: const Duration(milliseconds: 60),
        initialBackoff: Duration.zero,
        destinationFile: dest,
      );

      expect(callCount, 2);
      expect(sha256.convert(out.readAsBytesSync()).toString(), payloadSha256);
    });

    test('9. incorrect SHA-256 throws IntegrityCheckException and deletes artifact',
        () async {
      final client = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream<List<int>>.value(payloadBytes),
          200,
          contentLength: payloadBytes.length,
        );
      });

      final service = OrviaUpdateService(client: client);
      final dest = File(p.join(tempDir.path, 'bad_sha.apk'));

      await expectLater(
        () => service.downloadAndVerifyFile(
          downloadUrl: testUrl,
          expectedSha256: 'f' * 64,
          expectedFileSize: payloadBytes.length,
          initialBackoff: Duration.zero,
          destinationFile: dest,
        ),
        throwsA(isA<IntegrityCheckException>()),
      );

      expect(dest.existsSync(), isFalse);
      expect(listPartFiles(tempDir), isEmpty);
    });

    test('10. truncated APK stream is rejected and never promoted to destination',
        () async {
      final truncated = payloadBytes.sublist(0, payloadBytes.length - 1024);
      final client = MockClient.streaming((request, bodyStream) async {
        if (request.headers.containsKey('range')) {
          return http.StreamedResponse(
            const Stream<List<int>>.empty(),
            206,
            contentLength: 1024,
            headers: {
              'content-range':
                  'bytes ${truncated.length}-${payloadBytes.length - 1}/${payloadBytes.length}',
            },
          );
        }
        return http.StreamedResponse(
          Stream<List<int>>.value(truncated),
          200,
          contentLength: payloadBytes.length,
        );
      });

      final service = OrviaUpdateService(client: client);
      final dest = File(p.join(tempDir.path, 'truncated.apk'));

      await expectLater(
        () => service.downloadAndVerifyFile(
          downloadUrl: testUrl,
          expectedSha256: payloadSha256,
          expectedFileSize: payloadBytes.length,
          maxRetries: 1,
          initialBackoff: Duration.zero,
          destinationFile: dest,
        ),
        throwsA(isA<HttpException>()),
      );

      expect(dest.existsSync(), isFalse);
      expect(listPartFiles(tempDir), isEmpty);
    });

    test('11. insufficient disk space fails fast with DownloadStorageException',
        () async {
      bool httpCalled = false;
      final client = MockClient.streaming((request, bodyStream) async {
        httpCalled = true;
        return http.StreamedResponse(
          Stream<List<int>>.value(payloadBytes),
          200,
          contentLength: payloadBytes.length,
        );
      });

      final service = OrviaUpdateService(client: client);
      final dest = File(p.join(tempDir.path, 'no_space.apk'));

      await expectLater(
        () => service.downloadAndVerifyFile(
          downloadUrl: testUrl,
          expectedSha256: payloadSha256,
          expectedFileSize: payloadBytes.length,
          freeSpaceBytesProvider: (_) async => 1024,
          destinationFile: dest,
        ),
        throwsA(isA<DownloadStorageException>()),
      );

      expect(httpCalled, isFalse);
      expect(dest.existsSync(), isFalse);
      expect(listPartFiles(tempDir), isEmpty);
    });

    test('12. cancellation during download aborts stream and cleans up partial file',
        () async {
      final token = DownloadCancellationToken();
      final client = MockClient.streaming((request, bodyStream) async {
        final c = StreamController<List<int>>();
        () async {
          c.add(payloadBytes.sublist(0, 16 * 1024));
          await Future<void>.delayed(const Duration(milliseconds: 20));
          token.cancel();
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (!c.isClosed) {
            c.add(payloadBytes.sublist(16 * 1024));
            await c.close();
          }
        }();
        return http.StreamedResponse(
          c.stream,
          200,
          contentLength: payloadBytes.length,
        );
      });

      final service = OrviaUpdateService(client: client);
      final dest = File(p.join(tempDir.path, 'cancelled.apk'));

      await expectLater(
        () => service.downloadAndVerifyFile(
          downloadUrl: testUrl,
          expectedSha256: payloadSha256,
          cancellationToken: token,
          initialBackoff: Duration.zero,
          destinationFile: dest,
        ),
        throwsA(isA<DownloadCancelledException>()),
      );

      expect(dest.existsSync(), isFalse);
      expect(listPartFiles(tempDir), isEmpty);
    });

    test('13. concurrent downloads to the same destination file cannot corrupt each other',
        () async {
      final client = MockClient.streaming((request, bodyStream) async {
        final mid = payloadBytes.length ~/ 2;
        final c = StreamController<List<int>>();
        () async {
          c.add(payloadBytes.sublist(0, mid));
          await Future<void>.delayed(const Duration(milliseconds: 15));
          c.add(payloadBytes.sublist(mid));
          await c.close();
        }();
        return http.StreamedResponse(
          c.stream,
          200,
          contentLength: payloadBytes.length,
        );
      });

      final service = OrviaUpdateService(client: client);
      final dest = File(p.join(tempDir.path, 'concurrent.apk'));

      final results = await Future.wait([
        service.downloadAndVerifyFile(
          downloadUrl: testUrl,
          expectedSha256: payloadSha256,
          expectedFileSize: payloadBytes.length,
          initialBackoff: Duration.zero,
          destinationFile: dest,
        ),
        service.downloadAndVerifyFile(
          downloadUrl: testUrl,
          expectedSha256: payloadSha256,
          expectedFileSize: payloadBytes.length,
          initialBackoff: Duration.zero,
          destinationFile: dest,
        ),
      ]);

      expect(results[0].lengthSync(), payloadBytes.length);
      expect(results[1].lengthSync(), payloadBytes.length);
      expect(sha256.convert(dest.readAsBytesSync()).toString(), payloadSha256);
      expect(listPartFiles(tempDir), isEmpty);
    });

    test('14. integration test: real local TCP socket drop + HTTP 206 resume',
        () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close());

      final split = 90 * 1024;
      int requestNum = 0;

      server.listen((Socket socket) async {
        requestNum++;
        final currentReq = requestNum;
        final headerBuf = StringBuffer();
        final headersDone = Completer<void>();
        final sub = socket.listen(
          (data) {
            if (!headersDone.isCompleted) {
              headerBuf.write(utf8.decode(data, allowMalformed: true));
              if (headerBuf.toString().contains('\r\n\r\n')) {
                headersDone.complete();
              }
            }
          },
          onError: (_) {
            if (!headersDone.isCompleted) headersDone.complete();
          },
          onDone: () {
            if (!headersDone.isCompleted) headersDone.complete();
          },
        );
        await headersDone.future;
        final reqText = headerBuf.toString();

        if (currentReq == 1) {
          final headers = 'HTTP/1.1 200 OK\r\n'
              'Content-Length: ${payloadBytes.length}\r\n'
              'Accept-Ranges: bytes\r\n'
              'ETag: "local-v1"\r\n'
              'Connection: close\r\n\r\n';
          socket.add(ascii.encode(headers));
          socket.add(payloadBytes.sublist(0, split));
          await socket.flush();
          await sub.cancel();
          socket.destroy();
          return;
        }

        expect(reqText.toLowerCase(), contains('range: bytes=$split-'));
        expect(reqText.toLowerCase(), contains('if-range: "local-v1"'));

        final remaining = payloadBytes.sublist(split);
        final headers = 'HTTP/1.1 206 Partial Content\r\n'
            'Content-Length: ${remaining.length}\r\n'
            'Content-Range: bytes $split-${payloadBytes.length - 1}/${payloadBytes.length}\r\n'
            'ETag: "local-v1"\r\n'
            'Connection: close\r\n\r\n';
        socket.add(ascii.encode(headers));
        socket.add(remaining);
        await socket.flush();
        await sub.cancel();
        await socket.close();
      });

      final service = OrviaUpdateService();
      final dest = File(p.join(tempDir.path, 'integration.apk'));

      final out = await service.downloadAndVerifyFile(
        downloadUrl: 'http://127.0.0.1:${server.port}/app-release.apk',
        expectedSha256: payloadSha256,
        expectedFileSize: payloadBytes.length,
        initialBackoff: Duration.zero,
        destinationFile: dest,
      );

      expect(requestNum, 2);
      expect(out.lengthSync(), payloadBytes.length);
      expect(sha256.convert(out.readAsBytesSync()).toString(), payloadSha256);
      expect(listPartFiles(tempDir), isEmpty);
    });
  });
}

