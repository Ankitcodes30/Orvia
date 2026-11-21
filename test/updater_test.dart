import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import 'package:Orvia/services/orvia_updater_tools.dart';
import 'package:Orvia/services/updater/app_version.dart';
import 'package:Orvia/services/updater/in_app_update_manager.dart';
import 'package:Orvia/services/updater/orvia_update_service.dart';
import 'package:Orvia/services/updater/release_manifest.dart';

Future<File> _createUpdaterArchive({
  required Directory directory,
  required File executable,
  required String runtimeContents,
  File? runtimeFile,
  required String dataFileName,
  required String dataContents,
}) async {
  final archive = Archive();
  final executableBytes = await executable.readAsBytes();
  archive.addFile(
      ArchiveFile('orvia.exe', executableBytes.length, executableBytes));
  final runtimeBytes = runtimeFile == null
      ? utf8.encode(runtimeContents)
      : await runtimeFile.readAsBytes();
  archive.addFile(
      ArchiveFile('flutter_windows.dll', runtimeBytes.length, runtimeBytes));
  final dataBytes = utf8.encode(dataContents);
  archive
      .addFile(ArchiveFile('data/$dataFileName', dataBytes.length, dataBytes));
  final zipFile = File(p.join(directory.path, 'update.zip'));
  await zipFile.writeAsBytes(ZipEncoder().encode(archive));
  return zipFile;
}

Future<File> _compileWindowsUpdaterFixture({
  required Directory directory,
  required String version,
  required String launchMarker,
}) async {
  final assemblyVersion = version.replaceFirst('+', '.');
  final source = '''
using System;
using System.IO;
using System.Reflection;
[assembly: AssemblyVersion("$assemblyVersion")]
[assembly: AssemblyFileVersion("$assemblyVersion")]
[assembly: AssemblyInformationalVersion("$version")]
public static class OrviaUpdaterFixture {
    public static int Main() {
        var marker = Environment.GetEnvironmentVariable("ORVIA_TEST_LAUNCH_MARKER");
        if (!String.IsNullOrEmpty(marker)) File.WriteAllText(marker, "$launchMarker");
        return 0;
    }
}
''';
  final executable = File(p.join(
    directory.path,
    'fixture-${launchMarker.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.exe',
  ));
  final result = await Process.run(
    'powershell.exe',
    [
      '-NoProfile',
      '-Command',
      r'$source = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($env:ORVIA_FIXTURE_SOURCE)); Add-Type -TypeDefinition $source -Language CSharp -OutputAssembly $env:ORVIA_FIXTURE_OUTPUT -OutputType ConsoleApplication',
    ],
    environment: {
      ...Platform.environment,
      'ORVIA_FIXTURE_SOURCE': base64Encode(utf8.encode(source)),
      'ORVIA_FIXTURE_OUTPUT': executable.path,
    },
  );
  if (result.exitCode != 0 || !executable.existsSync()) {
    throw StateError(
      'Could not compile disposable updater fixture: ${result.stderr}',
    );
  }
  return executable;
}

Future<File> _compileWindowsRuntimeFixture(Directory directory) async {
  const source = '''
public static class OrviaRuntimeFixture {
    public static string GetVersion() { return "test-runtime"; }
}
''';
  final library = File(p.join(directory.path, 'runtime-fixture.dll'));
  final result = await Process.run(
    'powershell.exe',
    [
      '-NoProfile',
      '-Command',
      r'$source = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($env:ORVIA_FIXTURE_SOURCE)); Add-Type -TypeDefinition $source -Language CSharp -OutputAssembly $env:ORVIA_FIXTURE_OUTPUT -OutputType Library',
    ],
    environment: {
      ...Platform.environment,
      'ORVIA_FIXTURE_SOURCE': base64Encode(utf8.encode(source)),
      'ORVIA_FIXTURE_OUTPUT': library.path,
    },
  );
  if (result.exitCode != 0 || !library.existsSync()) {
    throw StateError(
      'Could not compile disposable runtime fixture: ${result.stderr}',
    );
  }
  return library;
}

Future<ProcessResult> _runUpdaterBatch(
  File script, {
  Map<String, String> environment = const {},
}) async {
  final process = await Process.start(
    'powershell.exe',
    [
      '-NoProfile',
      '-Command',
      r'& $env:ORVIA_TEST_SCRIPT; exit $LASTEXITCODE',
    ],
    environment: {
      ...Platform.environment,
      'ORVIA_TEST_SCRIPT': script.path,
      ...environment,
    },
  );
  final stdout = process.stdout.transform(utf8.decoder).join();
  final stderr = process.stderr.transform(utf8.decoder).join();
  final exitCode = await process.exitCode.timeout(
    const Duration(seconds: 60),
    onTimeout: () {
      process.kill();
      throw TimeoutException('Disposable updater script exceeded 60 seconds.');
    },
  );
  return ProcessResult(process.pid, exitCode, await stdout, await stderr);
}

Future<void> _deleteTestDirectory(Directory directory) async {
  for (var attempt = 0; attempt < 5; attempt++) {
    try {
      await directory.delete(recursive: true);
      return;
    } on FileSystemException {
      if (attempt == 4) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('AppVersion Parsing and Semantic Comparisons', () {
    test('parses simple, prefixed, and build-suffixed versions', () {
      final v1 = AppVersion.tryParse('3.0.4');
      expect(v1, isNotNull);
      expect(v1!.major, 3);
      expect(v1.minor, 0);
      expect(v1.patch, 4);
      expect(v1.buildNumber, 0);

      final v2 = AppVersion.tryParse('v3.0.4+1');
      expect(v2, isNotNull);
      expect(v2!.major, 3);
      expect(v2.buildNumber, 1);

      final v3 = AppVersion.tryParse('2.11.6', '171');
      expect(v3, isNotNull);
      expect(v3!.major, 2);
      expect(v3.minor, 11);
      expect(v3.patch, 6);
      expect(v3.buildNumber, 171);
    });

    test('safely rejects malformed version strings', () {
      expect(AppVersion.tryParse(''), isNull);
      expect(AppVersion.tryParse('   '), isNull);
      expect(AppVersion.tryParse('v'), isNull);
      expect(AppVersion.tryParse('V'), isNull);
      expect(AppVersion.tryParse('invalid'), isNull);
      expect(AppVersion.tryParse('3.invalid.4'), isNull);
      expect(AppVersion.tryParse('3.0.foo'), isNull);
      expect(AppVersion.tryParse('3.0.4.5'), isNull); // More than 3 segments
      expect(AppVersion.tryParse('3..4'), isNull); // Empty segment
      expect(AppVersion.tryParse('-1.0.0'), isNull); // Negative segment
      expect(AppVersion.tryParse('3.0.0-alpha..1'),
          isNull); // Empty pre-release field
    });

    test('avoids lexicographic string comparison pitfalls (10.0.0 > 2.0.0)',
        () {
      final v10 = AppVersion.tryParse('10.0.0+0')!;
      final v2 = AppVersion.tryParse('2.0.0+5')!;
      expect(v10 > v2, isTrue);
      expect(v2 < v10, isTrue);
    });

    test('compares major, minor, and patch numbers component-wise', () {
      final v304 = AppVersion.tryParse('3.0.4+0')!;
      final v305 = AppVersion.tryParse('3.0.5+0')!;
      final v310 = AppVersion.tryParse('3.1.0+0')!;
      final v400 = AppVersion.tryParse('4.0.0+0')!;

      expect(v305 > v304, isTrue);
      expect(v310 > v305, isTrue);
      expect(v400 > v310, isTrue);
    });

    test('strictly ignores build metadata in pure SemVer 2.0.0 precedence', () {
      final v304b0 = AppVersion.tryParse('3.0.4+0')!;
      final v304b1 = AppVersion.tryParse('3.0.4+1')!;

      // SemVer 2.0.0 rule 10: Build metadata MUST be ignored when determining version precedence
      expect(v304b0.compareTo(v304b1), 0);
      expect(v304b0 == v304b1, isTrue);
      expect(v304b1 > v304b0, isFalse);
    });

    test('evaluates Android build numbers via explicit compareAppRelease rule',
        () {
      final v304b0 = AppVersion.tryParse('3.0.4+0')!;
      final v304b1 = AppVersion.tryParse('3.0.4+1')!;

      // Explicit application update rule considers versionCode / build numbers
      expect(v304b1.isAppUpdateOver(v304b0, checkBuildNumber: true), isTrue);
      expect(v304b0.isAppUpdateOver(v304b1, checkBuildNumber: true), isFalse);

      // When checkBuildNumber is disabled, build differences do not trigger an update
      expect(v304b1.isAppUpdateOver(v304b0, checkBuildNumber: false), isFalse);
    });

    test('respects SemVer 2.0.0 pre-release precedence and ordering rules', () {
      final stable = AppVersion.tryParse('1.0.0')!;
      final alpha = AppVersion.tryParse('1.0.0-alpha')!;
      final alpha1 = AppVersion.tryParse('1.0.0-alpha.1')!;
      final alphaBeta = AppVersion.tryParse('1.0.0-alpha.beta')!;
      final beta = AppVersion.tryParse('1.0.0-beta')!;
      final beta2 = AppVersion.tryParse('1.0.0-beta.2')!;
      final beta11 = AppVersion.tryParse('1.0.0-beta.11')!;
      final rc1 = AppVersion.tryParse('1.0.0-rc.1')!;

      // Rule: Normal version is greater than pre-release
      expect(stable > rc1, isTrue);

      // Rule: alpha < alpha.1 < alpha.beta < beta < beta.2 < beta.11 < rc.1
      expect(alpha < alpha1, isTrue);
      expect(alpha1 < alphaBeta, isTrue);
      expect(alphaBeta < beta, isTrue);
      expect(beta < beta2, isTrue);
      expect(beta2 < beta11, isTrue);
      expect(beta11 < rc1, isTrue);
      expect(rc1 < stable, isTrue);
    });
  });

  group('ReleaseManifest & ReleasePlatform Model', () {
    const validJson = '''
{
  "schema_version": 1,
  "app_name": "Orvia",
  "min_supported_version": "3.0.0",
  "channels": {
    "stable": {
      "version": "3.1.0",
      "build_number": 1,
      "release_notes": "Highlights of this release",
      "platforms": {
        "android": {
          "download_url": "https://example.com/downloads/orvia-v3.1.0.apk",
          "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
          "file_size": 25000000
        },
        "windows": {
          "download_url": "https://example.com/downloads/orvia-v3.1.0.zip",
          "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        }
      }
    },
    "preview": {
      "version": "3.2.0-preview.1",
      "build_number": 2,
      "release_notes": "Preview notes",
      "platforms": {
        "android": {
          "download_url": "https://example.com/downloads/orvia-preview.apk",
          "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        }
      }
    }
  }
}
''';

    test('parses multi-channel manifest successfully', () {
      final manifest = ReleaseManifest.parse(validJson);
      expect(manifest.appName, 'Orvia');
      expect(manifest.minSupportedVersion, '3.0.0');
      expect(manifest.stable, isNotNull);
      expect(manifest.stable!.version, '3.1.0');
      expect(manifest.stable!.buildNumber, 1);
      expect(manifest.stable!.releaseNotes, 'Highlights of this release');
      expect(manifest.preview, isNotNull);
      expect(manifest.preview!.version, '3.2.0-preview.1');
    });

    test('parses backward-compatible flat manifest', () {
      const flatJson = '''
{
  "version": "3.1.0",
  "build_number": 1,
  "release_notes": "Bug fixes",
  "download_url": "https://example.com/orvia.apk",
  "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
}
''';
      final manifest = ReleaseManifest.parse(flatJson);
      expect(manifest.stable, isNotNull);
      expect(manifest.stable!.version, '3.1.0');
      expect(manifest.stable!.platforms['android'], isNotNull);
      expect(manifest.stable!.platforms['android']!.downloadUrl,
          'https://example.com/orvia.apk');
    });

    test('rejects cleartext HTTP and malformed download URLs', () {
      const badHttpJson = '''
{
  "version": "3.1.0",
  "download_url": "http://remote-server.com/orvia.apk",
  "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
}
''';
      expect(() => ReleaseManifest.parse(badHttpJson), throwsFormatException);

      const badSchemeJson = '''
{
  "version": "3.1.0",
  "download_url": "ftp://example.com/orvia.apk",
  "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
}
''';
      expect(() => ReleaseManifest.parse(badSchemeJson), throwsFormatException);
    });

    test('rejects malformed SHA-256 checksums', () {
      const badShaJson = '''
{
  "version": "3.1.0",
  "download_url": "https://example.com/orvia.apk",
  "sha256": "not-a-valid-sha256-hex-digest"
}
''';
      expect(() => ReleaseManifest.parse(badShaJson), throwsFormatException);
    });

    test(
        'rejects non-object manifest, empty channels, or malformed min_supported_version',
        () {
      expect(() => ReleaseManifest.parse('[]'), throwsFormatException);
      expect(() => ReleaseManifest.parse('{"channels": {}}'),
          throwsFormatException);
      expect(
        () => ReleaseManifest.parse(
            '{"version": "3.0.0", "min_supported_version": "invalid_ver"}'),
        throwsFormatException,
      );
    });
  });

  group('OrviaUpdateService Update Checking & Security Enforcement', () {
    const manifestJson = '''
{
  "schema_version": 1,
  "min_supported_version": "3.0.0",
  "channels": {
    "stable": {
      "version": "3.1.0",
      "build_number": 1,
      "release_notes": "New features included",
      "platforms": {
        "android": {
          "download_url": "https://example.com/downloads/orvia.apk",
          "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        },
        "windows": {
          "download_url": "https://example.com/downloads/orvia.zip",
          "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        }
      }
    },
    "preview": {
      "version": "3.2.0-preview.1",
      "build_number": 2,
      "release_notes": "Preview notes",
      "platforms": {
        "android": {
          "download_url": "https://example.com/downloads/preview.apk",
          "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        }
      }
    }
  }
}
''';

    test('unconfigured manifest URL reports checkFailed (never up-to-date)',
        () async {
      final service = OrviaUpdateService(
          client: MockClient((_) async => http.Response('', 200)));
      final result = await service.checkForUpdates(
        manifestUrlOverride: '',
        currentVersionOverride: '3.0.4',
        currentBuildOverride: '0',
      );

      expect(result.status, UpdateStatus.checkFailed);
      expect(result.isCheckFailed, isTrue);
      expect(result.isUpToDate, isFalse);
      expect(result.isUpdateAvailable, isFalse);
      expect(result.errorMessage, contains('not configured'));
    });

    test(
        'uses the GitHub Pages default and raw ghpage fallback on HTTP failure',
        () async {
      final requestedUrls = <Uri>[];
      final mockClient = MockClient((request) async {
        requestedUrls.add(request.url);
        if (request.url.toString() == OrviaUpdateService.defaultManifestUrl) {
          return http.Response('Unavailable', 503);
        }
        if (request.url.toString() == OrviaUpdateService.fallbackManifestUrl) {
          return http.Response(manifestJson, 200);
        }
        return http.Response('Unexpected URL', 404);
      });

      final service = OrviaUpdateService(client: mockClient);
      final result = await service.checkForUpdates(
        currentVersionOverride: '3.0.4',
        currentBuildOverride: '0',
      );

      expect(requestedUrls, [
        Uri.parse(OrviaUpdateService.defaultManifestUrl),
        Uri.parse(OrviaUpdateService.fallbackManifestUrl),
      ]);
      expect(result.status, UpdateStatus.updateAvailable);
    });

    test('falls back to raw ghpage when the default manifest times out',
        () async {
      final requestedUrls = <Uri>[];
      final mockClient = MockClient((request) async {
        requestedUrls.add(request.url);
        if (request.url.toString() == OrviaUpdateService.defaultManifestUrl) {
          throw TimeoutException('GitHub Pages timed out');
        }
        return http.Response(manifestJson, 200);
      });

      final service = OrviaUpdateService(client: mockClient);
      final result = await service.checkForUpdates(
        currentVersionOverride: '3.0.4',
        currentBuildOverride: '0',
      );

      expect(requestedUrls, [
        Uri.parse(OrviaUpdateService.defaultManifestUrl),
        Uri.parse(OrviaUpdateService.fallbackManifestUrl),
      ]);
      expect(result.status, UpdateStatus.updateAvailable);
    });

    test('rejects cleartext HTTP manifest URL (unless localhost)', () async {
      final service = OrviaUpdateService();
      final result = await service.checkForUpdates(
        manifestUrlOverride: 'http://untrusted-site.com/manifest.json',
        currentVersionOverride: '3.0.4',
        currentBuildOverride: '0',
      );

      expect(result.status, UpdateStatus.checkFailed);
      expect(result.errorMessage, contains('secure HTTPS'));
    });

    test('valid manifest with newer version reports updateAvailable', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('release_manifest.json')) {
          return http.Response(manifestJson, 200);
        }
        return http.Response('Not Found', 404);
      });

      final service = OrviaUpdateService(client: mockClient);
      final result = await service.checkForUpdates(
        manifestUrlOverride: 'https://example.com/release_manifest.json',
        currentVersionOverride: '3.0.4',
        currentBuildOverride: '0',
      );

      expect(result.status, UpdateStatus.updateAvailable);
      expect(result.isUpdateAvailable, isTrue);
      expect(result.newVersion, '3.1.0');
      expect(result.newBuild, '1');
      expect(result.releaseNotes, 'New features included');
      expect(result.downloadUrl, isNotNull);
      expect(result.sha256, isNotNull);
      expect(result.isBelowMinSupportedVersion, isFalse);
    });

    test('enforces min_supported_version when current version is below minimum',
        () async {
      final mockClient =
          MockClient((_) async => http.Response(manifestJson, 200));

      final service = OrviaUpdateService(client: mockClient);
      // Installed version 2.11.0 is below min_supported_version 3.0.0
      final result = await service.checkForUpdates(
        manifestUrlOverride: 'https://example.com/release_manifest.json',
        currentVersionOverride: '2.11.0',
        currentBuildOverride: '0',
      );

      expect(result.isBelowMinSupportedVersion, isTrue);
      expect(result.status, UpdateStatus.updateAvailable);
    });

    test('valid manifest with same version reports upToDate', () async {
      final mockClient =
          MockClient((_) async => http.Response(manifestJson, 200));

      final service = OrviaUpdateService(client: mockClient);
      final result = await service.checkForUpdates(
        manifestUrlOverride: 'https://example.com/release_manifest.json',
        currentVersionOverride: '3.1.0',
        currentBuildOverride: '1',
      );

      expect(result.status, UpdateStatus.upToDate);
      expect(result.isUpToDate, isTrue);
      expect(result.isUpdateAvailable, isFalse);
      expect(result.isCheckFailed, isFalse);
    });

    test('HTTP 404 response reports checkFailed and NEVER up-to-date',
        () async {
      final mockClient = MockClient(
          (_) async => http.Response('{"message": "Not Found"}', 404));

      final service = OrviaUpdateService(client: mockClient);
      final result = await service.checkForUpdates(
        manifestUrlOverride:
            'https://api.github.com/repos/HemantKArya/Orvia/releases/latest',
        currentVersionOverride: '3.0.4',
        currentBuildOverride: '0',
      );

      expect(result.status, UpdateStatus.checkFailed);
      expect(result.isCheckFailed, isTrue);
      expect(result.isUpToDate, isFalse);
      expect(result.isUpdateAvailable, isFalse);
      expect(result.errorMessage, contains('404'));
    });

    test('HTTP 500 server error reports checkFailed', () async {
      final mockClient =
          MockClient((_) async => http.Response('Internal Server Error', 500));

      final service = OrviaUpdateService(client: mockClient);
      final result = await service.checkForUpdates(
        manifestUrlOverride: 'https://example.com/release_manifest.json',
        currentVersionOverride: '3.0.4',
        currentBuildOverride: '0',
      );

      expect(result.status, UpdateStatus.checkFailed);
      expect(result.errorMessage, contains('500'));
    });

    test('network timeout reports checkFailed', () async {
      final mockClient = MockClient((_) async {
        throw TimeoutException('Timed out');
      });

      final service = OrviaUpdateService(client: mockClient);
      final result = await service.checkForUpdates(
        manifestUrlOverride: 'https://example.com/release_manifest.json',
        currentVersionOverride: '3.0.4',
        currentBuildOverride: '0',
      );

      expect(result.status, UpdateStatus.checkFailed);
      expect(result.errorMessage, contains('timed out'));
    });

    test('network socket error reports checkFailed', () async {
      final mockClient = MockClient((_) async {
        throw const SocketException('Host lookup failed');
      });

      final service = OrviaUpdateService(client: mockClient);
      final result = await service.checkForUpdates(
        manifestUrlOverride: 'https://example.com/release_manifest.json',
        currentVersionOverride: '3.0.4',
        currentBuildOverride: '0',
      );

      expect(result.status, UpdateStatus.checkFailed);
      expect(result.errorMessage, contains('Unable to reach'));
    });

    test('malformed JSON response reports checkFailed', () async {
      final mockClient = MockClient(
          (_) async => http.Response('<html>404 Not Found</html>', 200));

      final service = OrviaUpdateService(client: mockClient);
      final result = await service.checkForUpdates(
        manifestUrlOverride: 'https://example.com/release_manifest.json',
        currentVersionOverride: '3.0.4',
        currentBuildOverride: '0',
      );

      expect(result.status, UpdateStatus.checkFailed);
      expect(result.errorMessage, contains('Invalid release manifest'));
    });

    test('channel selection (preview channel) selects pre-release correctly',
        () async {
      final mockClient =
          MockClient((_) async => http.Response(manifestJson, 200));

      final service = OrviaUpdateService(client: mockClient);
      final result = await service.checkForUpdates(
        manifestUrlOverride: 'https://example.com/release_manifest.json',
        channelOverride: 'preview',
        currentVersionOverride: '3.1.0',
        currentBuildOverride: '1',
      );

      expect(result.status, UpdateStatus.updateAvailable);
      expect(result.newVersion, '3.2.0-preview.1');
      expect(result.newBuild, '2');
      expect(result.channel, 'preview');
    });
  });

  group('Download & SHA-256 Integrity Verification', () {
    test('verifyBytesSha256 verifies exact match and rejects mismatch', () {
      final service = OrviaUpdateService();
      final bytes = utf8.encode('Hello Orvia Update System');
      final expectedSha = sha256.convert(bytes).toString();

      expect(service.verifyBytesSha256(bytes, expectedSha), isTrue);
      expect(
          service.verifyBytesSha256(bytes, expectedSha.toUpperCase()), isTrue);
      expect(
          service.verifyBytesSha256(bytes,
              '0000000000000000000000000000000000000000000000000000000000000000'),
          isFalse);
    });

    test(
        'downloadAndVerifyFile downloads verified bytes and rejects corrupted file',
        () async {
      final content = utf8.encode('Genuine signed Orvia APK content');
      final validSha = sha256.convert(content).toString();

      final mockClient = MockClient((request) async {
        return http.Response.bytes(content, 200);
      });

      final service = OrviaUpdateService(client: mockClient);
      final tempDir = Directory.systemTemp.createTempSync('orvia_dl_test_');
      final targetFile = File('${tempDir.path}/app-update.apk');

      try {
        // Success case
        final file = await service.downloadAndVerifyFile(
          downloadUrl: 'https://example.com/app-update.apk',
          expectedSha256: validSha,
          destinationFile: targetFile,
        );
        expect(file.existsSync(), isTrue);
        expect(file.readAsBytesSync(), content);

        // Mismatched checksum case
        final corruptedTarget = File('${tempDir.path}/app-corrupted.apk');
        await expectLater(
          service.downloadAndVerifyFile(
            downloadUrl: 'https://example.com/app-update.apk',
            expectedSha256:
                '1111111111111111111111111111111111111111111111111111111111111111',
            destinationFile: corruptedTarget,
          ),
          throwsA(isA<IntegrityCheckException>()),
        );
        expect(
            corruptedTarget.existsSync(), isFalse); // Corrupted file cleaned up
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('downloadAndVerifyFile rejects cleartext HTTP URL scheme', () async {
      final service = OrviaUpdateService();
      final tempDir = Directory.systemTemp.createTempSync('orvia_dl_test_');
      final targetFile = File('${tempDir.path}/insecure.apk');

      try {
        expect(
          () => service.downloadAndVerifyFile(
            downloadUrl: 'http://untrusted-domain.com/insecure.apk',
            expectedSha256:
                '0000000000000000000000000000000000000000000000000000000000000000',
            destinationFile: targetFile,
          ),
          throwsArgumentError,
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });

  group('Backwards Compatibility with isUpdateAvailable helper', () {
    test('reports true when new version is higher', () {
      expect(isUpdateAvailable('3.0.4', '0', '3.1.0', '0'), isTrue);
      expect(isUpdateAvailable('3.0.4', '0', '3.0.4', '1'), isTrue);
      expect(isUpdateAvailable('2.11.6', '171', '3.0.0', '1'), isTrue);
    });

    test('reports false when versions are equal or target is older', () {
      expect(isUpdateAvailable('3.0.4', '0', '3.0.4', '0'), isFalse);
      expect(isUpdateAvailable('3.1.0', '0', '3.0.4', '0'), isFalse);
      expect(isUpdateAvailable('3.0.4', '1', '3.0.4', '0'), isFalse);
    });
  });

  group('v3.0.5 Release Manifest & In-App Update Flow Validation', () {
    test(
        'local version.json has valid schema, platforms, and 64-char SHA256 checksums',
        () {
      final file = File('version.json');
      expect(file.existsSync(), isTrue);
      final jsonMap =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(jsonMap['schema_version'], 1);
      expect(jsonMap['app_name'], 'Orvia');

      final stable = jsonMap['channels']['stable'] as Map<String, dynamic>;
      expect(stable['version'], '3.0.7');
      expect(stable['build_number'], 6);

      final android = stable['platforms']['android'] as Map<String, dynamic>;
      expect(
          android['download_url'],
          startsWith(
              'https://ankitcodes30.github.io/Orvia/downloads/app-release.apk'));
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(android['sha256']), isTrue);
      expect(android['file_size'], greaterThan(40000000));

      final windows = stable['platforms']['windows'] as Map<String, dynamic>;
      expect(
          windows['download_url'],
          startsWith(
              'https://ankitcodes30.github.io/Orvia/downloads/Orvia-Windows.zip'));
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(windows['sha256']), isTrue);
      expect(windows['file_size'], greaterThan(30000000));
    });

    test(
        'update checker correctly detects v3.0.5 update for installed v3.0.4 app',
        () async {
      final mockManifest = jsonEncode({
        "schema_version": 1,
        "app_name": "Orvia",
        "channels": {
          "stable": {
            "version": "3.0.5",
            "build_number": 2,
            "release_notes": "Test release notes",
            "platforms": {
              "android": {
                "download_url":
                    "https://ankitcodes30.github.io/Orvia/downloads/app-release.apk",
                "sha256":
                    "7b4b393eacc73ce7489dc6e703e7679b776d769e7f35bf3432bd483bd6cd9985",
                "file_size": 61496384
              },
              "windows": {
                "download_url":
                    "https://ankitcodes30.github.io/Orvia/downloads/Orvia-Windows.zip",
                "sha256":
                    "5c5d1572792c656145942d73b6ca99851b96dc85338279d891fbead4ff1f63e8",
                "file_size": 35235447
              }
            }
          }
        }
      });

      final client = MockClient((request) async {
        return http.Response(mockManifest, 200);
      });

      final service = OrviaUpdateService(client: client);
      final result = await service.checkForUpdates(
        manifestUrlOverride: 'https://localhost/test_version.json',
        currentVersionOverride: '3.0.4',
        currentBuildOverride: '1',
      );

      expect(result.status, UpdateStatus.updateAvailable);
      expect(result.isUpdateAvailable, isTrue);
      expect(result.newVersion, '3.0.5');
      expect(result.newBuild, '2');
      expect(result.downloadUrl, isNotNull);
    });

    test(
        'update checker suppresses dialog when installed version is already v3.0.5',
        () async {
      final mockManifest = jsonEncode({
        "schema_version": 1,
        "app_name": "Orvia",
        "channels": {
          "stable": {
            "version": "3.0.5",
            "build_number": 2,
            "platforms": {
              "android": {
                "download_url":
                    "https://ankitcodes30.github.io/Orvia/downloads/app-release.apk",
                "sha256":
                    "7b4b393eacc73ce7489dc6e703e7679b776d769e7f35bf3432bd483bd6cd9985",
                "file_size": 61496384
              }
            }
          }
        }
      });

      final client = MockClient((request) async {
        return http.Response(mockManifest, 200);
      });

      final service = OrviaUpdateService(client: client);
      final result = await service.checkForUpdates(
        manifestUrlOverride: 'https://localhost/test_version.json',
        currentVersionOverride: '3.0.5',
        currentBuildOverride: '2',
      );

      expect(result.status, UpdateStatus.upToDate);
      expect(result.isUpdateAvailable, isFalse);
    });

    test('Windows updater rejects invalid ZIP missing orvia.exe', () async {
      final tempDir =
          Directory.systemTemp.createTempSync('orvia_invalid_zip_test_');
      try {
        final dummyZip = File('${tempDir.path}/invalid.zip');
        final archive = Archive();
        archive.addFile(
            ArchiveFile('random_file.txt', 12, utf8.encode('hello world')));
        final zipBytes = ZipEncoder().encode(archive);
        dummyZip.writeAsBytesSync(zipBytes);

        await expectLater(
          () => InAppUpdateManager.installWindowsZip(
            zipFile: dummyZip,
            expectedVersion: '1.0.0+1',
            customTempDir: tempDir,
          ),
          throwsA(predicate(
              (e) => e.toString().contains('orvia.exe was not found'))),
        );
      } finally {
        try {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        } catch (_) {}
      }
    });

    test(
        'Windows updater rejects incomplete ZIP missing flutter_windows.dll or data directory',
        () async {
      final tempDir =
          Directory.systemTemp.createTempSync('orvia_incomplete_zip_test_');
      try {
        final dummyZip = File('${tempDir.path}/incomplete.zip');
        final archive = Archive();
        archive.addFile(ArchiveFile('orvia.exe', 8, utf8.encode('MOCK_EXE')));
        // Missing flutter_windows.dll and data/
        final zipBytes = ZipEncoder().encode(archive);
        dummyZip.writeAsBytesSync(zipBytes);

        await expectLater(
          () => InAppUpdateManager.installWindowsZip(
            zipFile: dummyZip,
            expectedVersion: '1.0.0+1',
            customTempDir: tempDir,
            autoExitOnSuccess: false,
          ),
          throwsA(predicate(
              (e) => e.toString().contains('missing required runtime files'))),
        );
      } finally {
        try {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        } catch (_) {}
      }
    });

    test(
        'Windows updater validates ZIP, respects targetAppDir and targetExecutablePath, and generates robust script with version check',
        () async {
      final tempDir =
          Directory.systemTemp.createTempSync('orvia_valid_zip_test_');
      final targetDir =
          Directory.systemTemp.createTempSync('orvia_target_app_test_');
      try {
        final validZip = File('${tempDir.path}/valid.zip');
        final archive = Archive();
        archive.addFile(ArchiveFile('orvia.exe', 8, utf8.encode('MOCK_EXE')));
        archive.addFile(
            ArchiveFile('flutter_windows.dll', 8, utf8.encode('MOCK_DLL')));
        archive.addFile(ArchiveFile('data/app.so', 8, utf8.encode('MOCK_SO')));
        final zipBytes = ZipEncoder().encode(archive);
        validZip.writeAsBytesSync(zipBytes);

        // Verify archive contains orvia.exe
        final decoded = ZipDecoder().decodeBytes(validZip.readAsBytesSync());
        final hasExe = decoded.any((f) => f.name.toLowerCase() == 'orvia.exe');
        expect(hasExe, isTrue);

        final targetExe = File(p.join(targetDir.path, 'orvia.exe'));
        targetExe.writeAsStringSync('TARGET_OLD_EXE');

        // Generate the updater script without launching it for focused assertions.
        await InAppUpdateManager.installWindowsZip(
          zipFile: validZip,
          expectedVersion: '3.0.7+4',
          targetAppDir: targetDir.path,
          targetExecutablePath: targetExe.path,
          autoExitOnSuccess: false,
          launchAfterUpdate: false,
          customTempDir: tempDir,
        );

        final scriptFile = tempDir
            .listSync(recursive: true)
            .whereType<File>()
            .firstWhere((file) => p.basename(file.path) == 'apply_update.bat');
        expect(scriptFile.existsSync(), isTrue);
        final scriptContent = scriptFile.readAsStringSync();

        // Verify script contains target app path and expected version
        expect(scriptContent.contains('set "EXPECTED_VER=3.0.7+4"'), isTrue);
        expect(scriptContent.contains(targetDir.path), isTrue);
        expect(
            scriptContent.contains(
                'robocopy "!SRC_DIR!" "!APP_DIR!" /E /IS /IT /R:5 /W:1 /NP'),
            isTrue);
        expect(scriptContent.contains('VersionInfo.ProductVersion'), isTrue);
        expect(
            scriptContent.contains('if not "!ACTUAL_VER!"=="!EXPECTED_VER!"'),
            isTrue);
        expect(scriptContent.contains('Rollback verified:'), isTrue);
        expect(scriptContent.contains('UPDATE_FAILED'), isTrue);
      } finally {
        try {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
          if (targetDir.existsSync()) {
            targetDir.deleteSync(recursive: true);
          }
        } catch (_) {}
      }
    });

    group('Windows updater disposable transaction tests',
        skip: !Platform.isWindows, () {
      const releaseVersion = '3.0.7+4';

      Future<
          ({
            Directory tempDir,
            Directory targetDir,
            File script,
            File runtimeFixture,
          })> prepareCase({
        required String initialRuntime,
        required String newRuntime,
        required bool simulateCopyFailure,
        bool simulateRollbackFailure = false,
        bool launchAfterUpdate = false,
        String expectedVersion = releaseVersion,
        String stagedVersion = releaseVersion,
      }) async {
        final tempDir =
            Directory.systemTemp.createTempSync('orvia updater e2e temp ');
        final targetDir =
            Directory(p.join(tempDir.path, 'disposable install with spaces'))
              ..createSync();
        final oldExecutable = await _compileWindowsUpdaterFixture(
          directory: tempDir,
          version: '3.0.7+3',
          launchMarker: 'old',
        );
        final newExecutable = await _compileWindowsUpdaterFixture(
          directory: tempDir,
          version: stagedVersion,
          launchMarker: 'updated',
        );
        final runtimeFixture = await _compileWindowsRuntimeFixture(tempDir);
        final targetExe = File(p.join(targetDir.path, 'orvia.exe'));
        await targetExe.writeAsBytes(await oldExecutable.readAsBytes());
        await File(p.join(targetDir.path, 'flutter_windows.dll'))
            .writeAsString(initialRuntime);
        final oldData = Directory(p.join(targetDir.path, 'data'))..createSync();
        await File(p.join(oldData.path, 'old.txt')).writeAsString('old data');

        final zipFile = await _createUpdaterArchive(
          directory: tempDir,
          executable: newExecutable,
          runtimeContents: newRuntime,
          runtimeFile: runtimeFixture,
          dataFileName: 'new.txt',
          dataContents: 'new data',
        );
        await InAppUpdateManager.installWindowsZip(
          zipFile: zipFile,
          expectedVersion: expectedVersion,
          targetAppDir: '${targetDir.path}\\',
          targetExecutablePath: targetExe.path,
          autoExitOnSuccess: false,
          launchAfterUpdate: launchAfterUpdate,
          simulateCopyFailureForTesting: simulateCopyFailure,
          simulateRollbackFailureForTesting: simulateRollbackFailure,
          customTempDir: tempDir,
        );
        final script = tempDir
            .listSync(recursive: true)
            .whereType<File>()
            .firstWhere((file) => p.basename(file.path) == 'apply_update.bat');
        return (
          tempDir: tempDir,
          targetDir: targetDir,
          script: script,
          runtimeFixture: runtimeFixture,
        );
      }

      test(
          'updates and launches a disposable executable from paths with spaces',
          () async {
        final testCase = await prepareCase(
          initialRuntime: 'old runtime',
          newRuntime: 'updated runtime',
          simulateCopyFailure: false,
          launchAfterUpdate: true,
        );
        try {
          final launchMarker =
              File(p.join(testCase.tempDir.path, 'updated launch marker.txt'));
          final result = await _runUpdaterBatch(
            testCase.script,
            environment: {'ORVIA_TEST_LAUNCH_MARKER': launchMarker.path},
          );
          final deadline = DateTime.now().add(const Duration(seconds: 5));
          while (
              !launchMarker.existsSync() && DateTime.now().isBefore(deadline)) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
          final actualRuntime =
              File(p.join(testCase.targetDir.path, 'flutter_windows.dll'));
          final actualRuntimeBytes = actualRuntime.readAsBytesSync();
          expect(result.exitCode, 0,
              reason: '${result.stdout}\n${result.stderr}');
          expect(actualRuntimeBytes.take(2), [0x4d, 0x5a]);
          expect(actualRuntimeBytes, testCase.runtimeFixture.readAsBytesSync());
          expect(
            File(p.join(testCase.targetDir.path, 'data', 'new.txt'))
                .readAsStringSync(),
            'new data',
          );
          expect(
            File(p.join(testCase.targetDir.path, 'data', 'old.txt'))
                .readAsStringSync(),
            'old data',
          );
          expect(launchMarker.existsSync(), isTrue,
              reason: 'The updated test executable must actually run.');
          expect(launchMarker.readAsStringSync(), 'updated');
        } finally {
          await _deleteTestDirectory(testCase.tempDir);
        }
      });

      test('restores and verifies files after an injected partial copy',
          () async {
        final testCase = await prepareCase(
          initialRuntime: 'known-good runtime',
          newRuntime: 'updated runtime',
          simulateCopyFailure: true,
        );
        try {
          final result = await _runUpdaterBatch(testCase.script);
          expect(result.exitCode, isNot(0));
          expect(
            File(p.join(testCase.targetDir.path, 'flutter_windows.dll'))
                .readAsStringSync(),
            'known-good runtime',
          );
          expect(
            File(p.join(testCase.targetDir.path, 'data', 'old.txt'))
                .readAsStringSync(),
            'old data',
          );
          expect(
            File(p.join(testCase.targetDir.path, 'data', 'new.txt'))
                .existsSync(),
            isFalse,
          );
          expect(
            Directory(p.join(p.dirname(testCase.script.path), 'backup'))
                .existsSync(),
            isFalse,
            reason: 'A verified rollback removes its disposable backup.',
          );
        } finally {
          await _deleteTestDirectory(testCase.tempDir);
        }
      });

      test('rejects an exact staged-version mismatch before replacement',
          () async {
        final testCase = await prepareCase(
          initialRuntime: 'known-good runtime',
          newRuntime: 'updated runtime',
          simulateCopyFailure: false,
          stagedVersion: '3.0.7+40',
        );
        try {
          final result = await _runUpdaterBatch(testCase.script);
          expect(result.exitCode, isNot(0));
          expect(
            File(p.join(testCase.targetDir.path, 'flutter_windows.dll'))
                .readAsStringSync(),
            'known-good runtime',
          );
          expect(
            File(p.join(testCase.targetDir.path, 'data', 'old.txt'))
                .existsSync(),
            isTrue,
          );
        } finally {
          await _deleteTestDirectory(testCase.tempDir);
        }
      });

      test('retains the backup when rollback cannot be verified', () async {
        final testCase = await prepareCase(
          initialRuntime: 'known-good runtime',
          newRuntime: 'updated runtime',
          simulateCopyFailure: true,
          simulateRollbackFailure: true,
        );
        try {
          final result = await _runUpdaterBatch(testCase.script);
          final updateDir = Directory(p.dirname(testCase.script.path));
          final backupDir = Directory(p.join(updateDir.path, 'backup'));
          final log =
              File(p.join(updateDir.path, 'update.log')).readAsStringSync();
          expect(result.exitCode, isNot(0));
          expect(backupDir.existsSync(), isTrue);
          expect(
              File(p.join(backupDir.path, 'orvia.exe')).existsSync(), isTrue);
          expect(
            File(p.join(backupDir.path, 'flutter_windows.dll')).existsSync(),
            isTrue,
          );
          expect(log, contains('CRITICAL: rollback could not be verified.'));
          expect(log, isNot(contains('Rollback verified:')));
        } finally {
          await _deleteTestDirectory(testCase.tempDir);
        }
      });

      test('normalizes trailing separators but preserves a drive root', () {
        expect(
          InAppUpdateManager.normalizeWindowsPath(r'C:\'),
          r'C:\',
        );
        expect(
          InAppUpdateManager.normalizeWindowsPath(r'C:\Program Files\Orvia\\'),
          r'C:\Program Files\Orvia',
        );
      });
    });
  });
}
