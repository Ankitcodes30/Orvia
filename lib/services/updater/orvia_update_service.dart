import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

import 'package:Orvia/core/constants/setting_keys.dart';
import 'package:Orvia/services/db/dao/settings_dao.dart';
import 'package:Orvia/services/db/db_provider.dart';
import 'package:Orvia/services/updater/app_version.dart';
import 'package:Orvia/services/updater/manifest_signature_verifier.dart';
import 'package:Orvia/services/updater/release_manifest.dart';

/// Distinct update states.
enum UpdateStatus {
  idle,
  checking,
  updateAvailable,
  upToDate,
  checkFailed,
  downloading,
  downloadFailed,
  readyToInstall,
}

/// Structured result of an update check.
class UpdateCheckResult {
  final UpdateStatus status;
  final String? currentVersion;
  final String? currentBuild;
  final String? newVersion;
  final String? newBuild;
  final String? releaseNotes;
  final String? downloadUrl;
  final String? sha256;
  final String? errorMessage;
  final String? channel;
  final String source;
  final ReleaseManifest? manifest;
  final bool isBelowMinSupportedVersion;

  const UpdateCheckResult({
    required this.status,
    this.currentVersion,
    this.currentBuild,
    this.newVersion,
    this.newBuild,
    this.releaseNotes,
    this.downloadUrl,
    this.sha256,
    this.errorMessage,
    this.channel,
    this.source = 'none',
    this.manifest,
    this.isBelowMinSupportedVersion = false,
  });

  bool get isUpdateAvailable => status == UpdateStatus.updateAvailable;
  bool get isUpToDate => status == UpdateStatus.upToDate;
  bool get isCheckFailed => status == UpdateStatus.checkFailed;

  /// Backwards-compatible map representation for legacy callers of [getAppUpdates].
  Map<String, dynamic> toLegacyMap() {
    return {
      'results': isUpdateAvailable,
      'status': status.name,
      'source': source,
      'currVer': currentVersion ?? '',
      'currBuild': currentBuild ?? '',
      'newVer': newVersion ?? '',
      'newBuild': newBuild ?? '',
      'download_url': downloadUrl ?? '',
      'release_notes': releaseNotes,
      'sha256': sha256,
      'error': errorMessage,
      'manifest': manifest?.toJson(),
      'isBelowMinSupportedVersion': isBelowMinSupportedVersion,
    };
  }

  @override
  String toString() {
    return 'UpdateCheckResult(status: $status, curr: $currentVersion+$currentBuild, '
        'new: $newVersion+$newBuild, belowMin: $isBelowMinSupportedVersion, error: $errorMessage)';
  }
}

/// Exception thrown when downloaded file checksum fails.
class IntegrityCheckException implements Exception {
  final String message;
  const IntegrityCheckException(this.message);

  @override
  String toString() => 'IntegrityCheckException: $message';
}

/// Exception thrown when a download is cancelled by the caller or user.
class DownloadCancelledException implements Exception {
  final String message;
  const DownloadCancelledException([this.message = 'Download cancelled by user.']);

  @override
  String toString() => 'DownloadCancelledException: $message';
}

/// Exception thrown when insufficient disk space prevents downloading or writing.
class DownloadStorageException implements Exception {
  final String message;
  const DownloadStorageException([
    this.message = 'Insufficient storage space to download update.',
  ]);

  @override
  String toString() => 'DownloadStorageException: $message';
}

/// Cooperative cancellation token for [OrviaUpdateService.downloadAndVerifyFile].
class DownloadCancellationToken {
  bool _cancelled = false;
  final Completer<void> _completer = Completer<void>();

  bool get isCancelled => _cancelled;
  Future<void> get onCancel => _completer.future;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }
}

/// Core service responsible for querying release manifests, comparing versions,
/// and verifying update downloads.
class OrviaUpdateService {
  final http.Client _client;

  OrviaUpdateService({http.Client? client}) : _client = client ?? http.Client();

  static final OrviaUpdateService instance = OrviaUpdateService();

  static const String defaultManifestUrl =
      'https://ankitcodes30.github.io/Orvia/version.json';
  static const String fallbackManifestUrl =
      'https://raw.githubusercontent.com/Ankitcodes30/Orvia/ghpage/version.json';

  /// Default timeout for manifest requests.
  static const Duration defaultTimeout = Duration(seconds: 8);

  /// Check for updates against a configurable release manifest.
  ///
  /// Strict safety rules:
  /// 1. If no manifest URL is configured, returns [UpdateStatus.checkFailed] with a helpful error.
  /// 2. Requires HTTPS for manifest URL (allowing localhost in development).
  /// 3. If network request fails or returns non-200, returns [UpdateStatus.checkFailed].
  /// 4. If manifest JSON is invalid or missing required fields, returns [UpdateStatus.checkFailed].
  /// 5. Enforces [min_supported_version] when present in the manifest.
  /// 6. Never returns [UpdateStatus.upToDate] on an error or failed check.
  Future<UpdateCheckResult> checkForUpdates({
    String? manifestUrlOverride,
    String? channelOverride,
    String? currentVersionOverride,
    String? currentBuildOverride,
    Duration timeout = defaultTimeout,
    bool enforceSignatures = false,
    List<TrustedPublicKey>? customTrustStore,
  }) async {
    // 1. Resolve local installed version
    String localVersion = currentVersionOverride ?? '';
    String localBuild = currentBuildOverride ?? '';

    if (localVersion.isEmpty || localBuild.isEmpty) {
      try {
        final info = await PackageInfo.fromPlatform();
        if (localVersion.isEmpty) localVersion = info.version;
        if (localBuild.isEmpty) localBuild = info.buildNumber;
      } catch (e) {
        log('Could not read PackageInfo: $e', name: 'OrviaUpdateService');
        if (localVersion.isEmpty) localVersion = '0.0.0';
        if (localBuild.isEmpty) localBuild = '0';
      }
    }

    final currentAppVersion = AppVersion.tryParse(localVersion, localBuild) ??
        const AppVersion(major: 0, minor: 0, patch: 0);

    // 2. Resolve manifest URL
    String? manifestUrl = manifestUrlOverride?.trim();
    if (manifestUrlOverride != null && manifestUrlOverride.trim().isEmpty) {
      return UpdateCheckResult(
        status: UpdateStatus.checkFailed,
        currentVersion: localVersion,
        currentBuild: localBuild,
        errorMessage: 'Update manifest URL is not configured.',
        source: 'unconfigured_manifest_url',
      );
    }

    if (manifestUrl == null || manifestUrl.isEmpty) {
      try {
        if (DBProvider.isInitialized) {
          final savedUrl = await SettingsDAO(DBProvider.db)
              .getSettingStr(SettingKeys.updateManifestUrl);
          if (savedUrl != null && savedUrl.trim().isNotEmpty) {
            manifestUrl = savedUrl.trim();
          }
        }
      } catch (e) {
        log('Could not read updateManifestUrl setting: $e', name: 'OrviaUpdateService');
      }
    }

    manifestUrl ??= defaultManifestUrl;
    final isDefaultManifest = manifestUrl == defaultManifestUrl;

    // Security validation: Require HTTPS for manifest endpoint (allow localhost/127.0.0.1 for testing)
    final manifestUri = Uri.tryParse(manifestUrl);
    final isLocalManifest = manifestUri != null &&
        (manifestUri.host == 'localhost' || manifestUri.host == '127.0.0.1');

    if (manifestUri == null ||
        !manifestUri.hasAuthority ||
        (!manifestUri.isScheme('https') && !(manifestUri.isScheme('http') && isLocalManifest))) {
      return UpdateCheckResult(
        status: UpdateStatus.checkFailed,
        currentVersion: localVersion,
        currentBuild: localBuild,
        errorMessage: 'Manifest URL must be a valid, secure HTTPS endpoint: $manifestUrl',
        source: 'invalid_manifest_url',
      );
    }

    // 3. Resolve requested channel
    String channelName = channelOverride?.trim().toLowerCase() ?? 'stable';
    if (channelOverride == null) {
      try {
        if (DBProvider.isInitialized) {
          final savedChannel = await SettingsDAO(DBProvider.db)
              .getSettingStr(SettingKeys.updateChannel);
          if (savedChannel != null && savedChannel.trim().isNotEmpty) {
            channelName = savedChannel.trim().toLowerCase();
          }
        }
      } catch (_) {}
    }

    // 4. Fetch manifest with a raw GitHub fallback if the deployed site is unavailable.
    http.Response response;
    try {
      response = await _client.get(manifestUri).timeout(timeout);
    } on TimeoutException {
      if (isDefaultManifest) {
        try {
          final fallbackUri = Uri.parse(fallbackManifestUrl);
          response = await _client.get(fallbackUri).timeout(timeout);
        } catch (e) {
          log('Raw GitHub update manifest fallback failed: $e',
              name: 'OrviaUpdateService');
          return UpdateCheckResult(
            status: UpdateStatus.checkFailed,
            currentVersion: localVersion,
            currentBuild: localBuild,
            errorMessage:
                'Connection timed out while checking for updates. Please try again.',
            source: 'network_timeout',
          );
        }
      } else {
        return UpdateCheckResult(
          status: UpdateStatus.checkFailed,
          currentVersion: localVersion,
          currentBuild: localBuild,
          errorMessage:
              'Connection timed out while checking for updates. Please try again.',
          source: 'network_timeout',
        );
      }
    } on SocketException catch (e) {
      if (isDefaultManifest) {
        try {
          final fallbackUri = Uri.parse(fallbackManifestUrl);
          response = await _client.get(fallbackUri).timeout(timeout);
        } catch (fallbackError) {
          log('Raw GitHub update manifest fallback failed: $fallbackError',
              name: 'OrviaUpdateService');
          return UpdateCheckResult(
            status: UpdateStatus.checkFailed,
            currentVersion: localVersion,
            currentBuild: localBuild,
            errorMessage:
                'Unable to reach the update server (${e.message}). Please check your connection.',
            source: 'network_socket_error',
          );
        }
      } else {
        return UpdateCheckResult(
          status: UpdateStatus.checkFailed,
          currentVersion: localVersion,
          currentBuild: localBuild,
          errorMessage:
              'Unable to reach the update server (${e.message}). Please check your connection.',
          source: 'network_socket_error',
        );
      }
    } catch (e) {
      return UpdateCheckResult(
        status: UpdateStatus.checkFailed,
        currentVersion: localVersion,
        currentBuild: localBuild,
        errorMessage: 'Network error checking for updates: $e',
        source: 'network_error',
      );
    }

    if (response.statusCode != 200 && isDefaultManifest) {
      try {
        response = await _client
            .get(Uri.parse(fallbackManifestUrl))
            .timeout(timeout);
      } catch (e) {
        log('Raw GitHub update manifest fallback failed: $e',
            name: 'OrviaUpdateService');
      }
    }

    if (response.statusCode != 200) {
      return UpdateCheckResult(
        status: UpdateStatus.checkFailed,
        currentVersion: localVersion,
        currentBuild: localBuild,
        errorMessage: 'Update server returned HTTP status ${response.statusCode}.',
        source: 'http_${response.statusCode}',
      );
    }

    // 5. Parse manifest
    ReleaseManifest manifest;
    try {
      manifest = ReleaseManifest.parse(response.body);
    } on FormatException catch (e) {
      return UpdateCheckResult(
        status: UpdateStatus.checkFailed,
        currentVersion: localVersion,
        currentBuild: localBuild,
        errorMessage: 'Invalid release manifest: ${e.message}',
        source: 'invalid_manifest',
      );
    } catch (e) {
      return UpdateCheckResult(
        status: UpdateStatus.checkFailed,
        currentVersion: localVersion,
        currentBuild: localBuild,
        errorMessage: 'Failed to parse release manifest: $e',
        source: 'manifest_parse_error',
      );
    }

    // 6. Enforce min_supported_version
    bool isBelowMin = false;
    if (manifest.minSupportedVersion != null && manifest.minSupportedVersion!.isNotEmpty) {
      final minVersion = AppVersion.tryParse(manifest.minSupportedVersion!);
      if (minVersion != null) {
        isBelowMin = currentAppVersion < minVersion;
      }
    }

    // 7. Select channel
    final channel = manifest.getChannel(channelName);
    if (channel == null) {
      return UpdateCheckResult(
        status: UpdateStatus.checkFailed,
        currentVersion: localVersion,
        currentBuild: localBuild,
        errorMessage: 'Release channel "$channelName" was not found in the manifest.',
        source: 'missing_channel',
        manifest: manifest,
        isBelowMinSupportedVersion: isBelowMin,
      );
    }

    // 8. Parse remote version
    final remoteAppVersion =
        AppVersion.tryParse(channel.version, channel.buildNumber.toString());
    if (remoteAppVersion == null) {
      return UpdateCheckResult(
        status: UpdateStatus.checkFailed,
        currentVersion: localVersion,
        currentBuild: localBuild,
        errorMessage: 'Invalid version string in release channel: "${channel.version}".',
        source: 'invalid_remote_version',
        manifest: manifest,
        isBelowMinSupportedVersion: isBelowMin,
      );
    }

    // 9. Find platform download
    final platformRelease = channel.currentPlatformRelease;
    final downloadUrl = platformRelease?.downloadUrl;
    final sha256 = platformRelease?.sha256;

    // Cryptographic signature check for platform release
    if (platformRelease != null) {
      final sigResult = ManifestSignatureVerifier.verifyPlatformSignature(
        appName: manifest.appName,
        channel: channel.name,
        version: channel.version,
        buildNumber: channel.buildNumber,
        platformKey: ReleaseChannel.currentPlatformKey,
        platform: platformRelease,
        publishedAt: channel.publishedAt,
        enforceSignatures: enforceSignatures,
        customTrustStore: customTrustStore,
      );
      if (!sigResult.isApproved) {
        return UpdateCheckResult(
          status: UpdateStatus.checkFailed,
          currentVersion: localVersion,
          currentBuild: localBuild,
          errorMessage: sigResult.message,
          source: 'signature_verification_failed',
          manifest: manifest,
        );
      }
    }

    // 10. Application update comparison
    // Uses compareAppRelease to evaluate SemVer precedence while honoring Android build numbers
    final isNewer = remoteAppVersion.isAppUpdateOver(currentAppVersion, checkBuildNumber: true);

    if (isNewer || isBelowMin) {
      return UpdateCheckResult(
        status: UpdateStatus.updateAvailable,
        currentVersion: localVersion,
        currentBuild: localBuild,
        newVersion: channel.version,
        newBuild: channel.buildNumber.toString(),
        releaseNotes: channel.releaseNotes,
        downloadUrl: downloadUrl,
        sha256: sha256,
        channel: channel.name,
        source: 'manifest',
        manifest: manifest,
        isBelowMinSupportedVersion: isBelowMin,
      );
    } else {
      return UpdateCheckResult(
        status: UpdateStatus.upToDate,
        currentVersion: localVersion,
        currentBuild: localBuild,
        newVersion: channel.version,
        newBuild: channel.buildNumber.toString(),
        releaseNotes: channel.releaseNotes,
        downloadUrl: downloadUrl,
        sha256: sha256,
        channel: channel.name,
        source: 'manifest',
        manifest: manifest,
        isBelowMinSupportedVersion: isBelowMin,
      );
    }
  }

  /// Verify that the given bytes match the expected SHA-256 hexadecimal checksum.
  bool verifyBytesSha256(List<int> bytes, String expectedSha256) {
    if (expectedSha256.trim().isEmpty) return false;
    final digest = sha256.convert(bytes);
    return digest.toString().toLowerCase() == expectedSha256.trim().toLowerCase();
  }

  static final Map<String, Future<void>> _destinationLocks = <String, Future<void>>{};
  static int _partSequence = 0;

  /// Download an APK/archive file from [downloadUrl] with bounded retries,
  /// HTTP Range resume, ETag/If-Range validation, per-chunk stall timeouts,
  /// concurrency locking, and streaming SHA-256 verification against [expectedSha256].
  ///
  /// Throws [IntegrityCheckException] if the final checksum does not match.
  /// Throws [DownloadCancelledException] if [cancellationToken] is cancelled.
  /// Throws [DownloadStorageException] if disk space is exhausted.
  /// Rejects cleartext HTTP downgrades upon redirect and never promotes
  /// an incomplete or unverified file to [destinationFile].
  Future<File> downloadAndVerifyFile({
    required String downloadUrl,
    required String expectedSha256,
    required File destinationFile,
    Duration timeout = const Duration(minutes: 5),
    Duration chunkTimeout = const Duration(seconds: 30),
    int maxRetries = 4,
    Duration initialBackoff = const Duration(milliseconds: 500),
    int? expectedFileSize,
    DownloadCancellationToken? cancellationToken,
    Future<int?> Function(Directory dir)? freeSpaceBytesProvider,
    void Function(int received, int total)? onProgress,
  }) async {
    final uri = Uri.tryParse(downloadUrl);
    final isLocal =
        uri != null && (uri.host == 'localhost' || uri.host == '127.0.0.1');

    if (uri == null ||
        !uri.hasAuthority ||
        (!uri.isScheme('https') && !(uri.isScheme('http') && isLocal))) {
      throw ArgumentError('Download URL must use secure HTTPS: $downloadUrl');
    }

    final cleanedExpectedSha = expectedSha256.trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(cleanedExpectedSha)) {
      throw ArgumentError('Invalid expected SHA-256 checksum: $expectedSha256');
    }

    if (expectedFileSize != null && expectedFileSize <= 0) {
      throw ArgumentError('Invalid expectedFileSize: $expectedFileSize');
    }

    if (cancellationToken?.isCancelled == true) {
      throw const DownloadCancelledException();
    }

    destinationFile.parent.createSync(recursive: true);

    if (freeSpaceBytesProvider != null && expectedFileSize != null) {
      final freeBytes = await freeSpaceBytesProvider(destinationFile.parent);
      if (freeBytes != null && freeBytes < expectedFileSize) {
        throw DownloadStorageException(
          'Insufficient storage space: need $expectedFileSize bytes, only $freeBytes bytes available.',
        );
      }
    }

    final lockKey = p.canonicalize(destinationFile.path);
    return _withDestinationLock(lockKey, () async {
      final partSeq = ++_partSequence;
      final tempPartFile = File(
        '${destinationFile.path}.part_${DateTime.now().microsecondsSinceEpoch}_$partSeq',
      );
      if (tempPartFile.existsSync()) {
        tempPartFile.deleteSync();
      }

      String? expectedETag;
      String? expectedLastModified;
      int? expectedTotalBytes = expectedFileSize;
      Object? lastError;

      try {
        for (int attempt = 0; attempt <= maxRetries; attempt++) {
          if (cancellationToken?.isCancelled == true) {
            throw const DownloadCancelledException();
          }

          int existingBytes =
              tempPartFile.existsSync() ? tempPartFile.lengthSync() : 0;

          if (expectedTotalBytes != null && existingBytes == expectedTotalBytes) {
            break;
          }
          if (expectedTotalBytes != null && existingBytes > expectedTotalBytes) {
            tempPartFile.deleteSync();
            existingBytes = 0;
          }

          if (attempt > 0 && initialBackoff > Duration.zero) {
            final delayMs =
                (initialBackoff.inMilliseconds * (1 << (attempt - 1)))
                    .clamp(0, 4000);
            await _delayWithCancellation(
              Duration(milliseconds: delayMs),
              cancellationToken,
            );
          }

          try {
            final request = http.Request('GET', uri);
            if (existingBytes > 0) {
              request.headers['range'] = 'bytes=$existingBytes-';
              if (expectedETag != null && expectedETag.isNotEmpty) {
                request.headers['if-range'] = expectedETag;
              } else if (expectedLastModified != null &&
                  expectedLastModified.isNotEmpty) {
                request.headers['if-range'] = expectedLastModified;
              }
            }

            final response = await _sendWithCancellation(
              request,
              timeout,
              cancellationToken,
            );

            // Safeguard against cleartext downgrade redirects
            final finalUrl = response.request?.url;
            if (finalUrl != null && !finalUrl.isScheme('https')) {
              final isFinalLocal =
                  finalUrl.host == 'localhost' || finalUrl.host == '127.0.0.1';
              if (!isFinalLocal) {
                await _drainQuietly(response.stream);
                throw HttpException(
                  'Insecure redirect to cleartext HTTP rejected: $finalUrl',
                  uri: uri,
                );
              }
            }

            if (response.statusCode == 416 && existingBytes > 0) {
              await _drainQuietly(response.stream);
              if (tempPartFile.existsSync()) tempPartFile.deleteSync();
              expectedETag = null;
              expectedLastModified = null;
              lastError = HttpException(
                'HTTP 416 Range Not Satisfiable at offset $existingBytes',
                uri: uri,
              );
              continue;
            }

            if (response.statusCode == 500 ||
                response.statusCode == 502 ||
                response.statusCode == 503 ||
                response.statusCode == 504 ||
                response.statusCode == 429) {
              await _drainQuietly(response.stream);
              lastError = HttpException(
                'Transient server error: HTTP ${response.statusCode}',
                uri: uri,
              );
              continue;
            }

            if (response.statusCode != 200 && response.statusCode != 206) {
              await _drainQuietly(response.stream);
              throw HttpException(
                'Failed to download file: HTTP ${response.statusCode}',
                uri: uri,
              );
            }

            final responseETag = _headerIgnoreCase(response.headers, 'etag');
            final responseLastMod =
                _headerIgnoreCase(response.headers, 'last-modified');

            FileMode writeMode;
            int startOffset;

            if (response.statusCode == 200) {
              if (existingBytes > 0 && tempPartFile.existsSync()) {
                tempPartFile.deleteSync();
              }
              existingBytes = 0;
              startOffset = 0;
              writeMode = FileMode.write;
              expectedETag = responseETag;
              expectedLastModified = responseLastMod;

              final contentLength = response.contentLength;
              if (contentLength != null && contentLength > 0) {
                if (expectedFileSize != null &&
                    contentLength != expectedFileSize) {
                  await _drainQuietly(response.stream);
                  throw HttpException(
                    'Content-Length ($contentLength) does not match expected file size ($expectedFileSize)',
                    uri: uri,
                  );
                }
                expectedTotalBytes = contentLength;
              }
            } else {
              // HTTP 206 Partial Content
              if (existingBytes <= 0) {
                await _drainQuietly(response.stream);
                throw HttpException(
                  'Unexpected HTTP 206 Partial Content for full request',
                  uri: uri,
                );
              }

              // Reject resume if server ETag changed despite If-Range
              if (expectedETag != null &&
                  responseETag != null &&
                  expectedETag != responseETag) {
                await _drainQuietly(response.stream);
                if (tempPartFile.existsSync()) tempPartFile.deleteSync();
                expectedETag = null;
                expectedLastModified = null;
                lastError = HttpException(
                  'Resource ETag changed during resume ($expectedETag -> $responseETag)',
                  uri: uri,
                );
                continue;
              }

              final contentRangeHeader =
                  _headerIgnoreCase(response.headers, 'content-range');
              final parsedRange = _parseContentRange(contentRangeHeader);
              if (parsedRange == null || parsedRange.start != existingBytes) {
                await _drainQuietly(response.stream);
                throw HttpException(
                  'Invalid Content-Range header "$contentRangeHeader" for offset $existingBytes',
                  uri: uri,
                );
              }

              if (parsedRange.total != null) {
                if (expectedTotalBytes != null &&
                    parsedRange.total != expectedTotalBytes) {
                  await _drainQuietly(response.stream);
                  throw HttpException(
                    'Content-Range total (${parsedRange.total}) mismatches expected size ($expectedTotalBytes)',
                    uri: uri,
                  );
                }
                expectedTotalBytes = parsedRange.total;
              }

              final rangeLength = parsedRange.end - parsedRange.start + 1;
              if (response.contentLength != null &&
                  response.contentLength! > 0 &&
                  response.contentLength != rangeLength) {
                await _drainQuietly(response.stream);
                throw HttpException(
                  'Content-Length (${response.contentLength}) mismatches Content-Range length ($rangeLength)',
                  uri: uri,
                );
              }

              if (expectedETag == null && responseETag != null) {
                expectedETag = responseETag;
              }
              if (expectedLastModified == null && responseLastMod != null) {
                expectedLastModified = responseLastMod;
              }

              startOffset = existingBytes;
              writeMode = FileMode.append;
            }

            if (freeSpaceBytesProvider != null && expectedTotalBytes != null) {
              final remaining = expectedTotalBytes - startOffset;
              if (remaining > 0) {
                final freeBytes =
                    await freeSpaceBytesProvider(destinationFile.parent);
                if (freeBytes != null && freeBytes < remaining) {
                  await _drainQuietly(response.stream);
                  throw DownloadStorageException(
                    'Insufficient storage space: need $remaining additional bytes, only $freeBytes bytes available.',
                  );
                }
              }
            }

            await _streamAttemptToFile(
              stream: response.stream,
              partFile: tempPartFile,
              mode: writeMode,
              initialReceived: startOffset,
              expectedTotalBytes: expectedTotalBytes ?? -1,
              chunkTimeout: chunkTimeout,
              cancellationToken: cancellationToken,
              onProgress: onProgress,
            );

            final actualAfterAttempt =
                tempPartFile.existsSync() ? tempPartFile.lengthSync() : 0;
            if (expectedTotalBytes != null &&
                actualAfterAttempt < expectedTotalBytes) {
              lastError = HttpException(
                'Download stream ended early: received $actualAfterAttempt of $expectedTotalBytes bytes',
                uri: uri,
              );
              continue;
            }
            if (expectedTotalBytes != null &&
                actualAfterAttempt > expectedTotalBytes) {
              throw HttpException(
                'Downloaded size ($actualAfterAttempt) exceeded expected size ($expectedTotalBytes)',
                uri: uri,
              );
            }

            lastError = null;
            break;
          } catch (e) {
            if (e is DownloadCancelledException ||
                e is DownloadStorageException ||
                e is IntegrityCheckException) {
              rethrow;
            }
            if (_isStorageError(e)) {
              throw DownloadStorageException(
                'Insufficient storage space while writing update: $e',
              );
            }
            if (_isTransientDownloadError(e) && attempt < maxRetries) {
              lastError = e;
              continue;
            }
            rethrow;
          }
        }

        if (lastError != null) {
          throw lastError;
        }

        if (!tempPartFile.existsSync()) {
          throw HttpException('Downloaded file is missing', uri: uri);
        }

        final finalSize = tempPartFile.lengthSync();
        if (expectedTotalBytes != null && finalSize != expectedTotalBytes) {
          throw HttpException(
            'Truncated download: received $finalSize of $expectedTotalBytes bytes',
            uri: uri,
          );
        }

        final actualDigest = await _verifyPartFileSha256(tempPartFile);
        if (actualDigest != cleanedExpectedSha) {
          throw IntegrityCheckException(
            'Downloaded file SHA-256 mismatch!\n'
            'Expected: $cleanedExpectedSha\n'
            'Actual:   $actualDigest',
          );
        }

        if (destinationFile.existsSync()) {
          destinationFile.deleteSync();
        }
        tempPartFile.renameSync(destinationFile.path);
        return destinationFile;
      } catch (_) {
        if (tempPartFile.existsSync()) {
          try {
            tempPartFile.deleteSync();
          } catch (_) {}
        }
        rethrow;
      }
    });
  }

  static Future<T> _withDestinationLock<T>(
    String key,
    Future<T> Function() action,
  ) async {
    final previous = _destinationLocks[key];
    final gate = Completer<void>();
    _destinationLocks[key] = gate.future;
    if (previous != null) {
      try {
        await previous;
      } catch (_) {}
    }
    try {
      return await action();
    } finally {
      if (!gate.isCompleted) {
        gate.complete();
      }
      if (identical(_destinationLocks[key], gate.future)) {
        _destinationLocks.remove(key);
      }
    }
  }

  Future<http.StreamedResponse> _sendWithCancellation(
    http.BaseRequest request,
    Duration timeout,
    DownloadCancellationToken? token,
  ) async {
    final sendFuture = _client.send(request).timeout(timeout);
    if (token == null) {
      return await sendFuture;
    }
    if (token.isCancelled) {
      throw const DownloadCancelledException();
    }
    return await Future.any<http.StreamedResponse>([
      sendFuture,
      token.onCancel.then<http.StreamedResponse>(
        (_) => throw const DownloadCancelledException(),
      ),
    ]);
  }

  static Future<void> _delayWithCancellation(
    Duration delay,
    DownloadCancellationToken? token,
  ) async {
    if (delay <= Duration.zero) return;
    if (token == null) {
      await Future<void>.delayed(delay);
      return;
    }
    if (token.isCancelled) {
      throw const DownloadCancelledException();
    }
    await Future.any<void>([
      Future<void>.delayed(delay),
      token.onCancel.then<void>((_) => throw const DownloadCancelledException()),
    ]);
  }

  static Future<void> _drainQuietly(Stream<List<int>> stream) async {
    try {
      await stream.drain<void>();
    } catch (_) {}
  }

  static String? _headerIgnoreCase(Map<String, String> headers, String name) {
    final lower = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lower) {
        final v = entry.value.trim();
        return v.isEmpty ? null : v;
      }
    }
    return null;
  }

  static _ParsedContentRange? _parseContentRange(String? header) {
    if (header == null || header.trim().isEmpty) return null;
    final match = RegExp(
      r'^bytes\s+(\d+)-(\d+)/(\d+|\*)$',
      caseSensitive: false,
    ).firstMatch(header.trim());
    if (match == null) return null;

    final start = int.tryParse(match.group(1)!);
    final end = int.tryParse(match.group(2)!);
    final totalRaw = match.group(3)!;
    final total = totalRaw == '*' ? null : int.tryParse(totalRaw);
    if (start == null || end == null || end < start) return null;
    if (total != null && total <= end) return null;

    return _ParsedContentRange(start: start, end: end, total: total);
  }

  static Future<void> _streamAttemptToFile({
    required Stream<List<int>> stream,
    required File partFile,
    required FileMode mode,
    required int initialReceived,
    required int expectedTotalBytes,
    required Duration chunkTimeout,
    required DownloadCancellationToken? cancellationToken,
    void Function(int received, int total)? onProgress,
  }) async {
    final sink = partFile.openWrite(mode: mode);
    int receivedBytes = initialReceived;
    StreamSubscription<List<int>>? sub;
    Timer? stallTimer;
    final done = Completer<void>();

    void failWith(Object error, [StackTrace? st]) {
      stallTimer?.cancel();
      if (!done.isCompleted) {
        done.completeError(error, st ?? StackTrace.current);
      }
    }

    void resetStallTimer() {
      stallTimer?.cancel();
      stallTimer = Timer(chunkTimeout, () {
        failWith(TimeoutException('Download stalled for $chunkTimeout'));
      });
    }

    if (cancellationToken != null) {
      unawaited(
        cancellationToken.onCancel.then((_) {
          failWith(const DownloadCancelledException());
        }),
      );
    }

    resetStallTimer();
    sub = stream.listen(
      (chunk) {
        if (done.isCompleted) return;
        if (cancellationToken?.isCancelled == true) {
          failWith(const DownloadCancelledException());
          return;
        }
        resetStallTimer();
        try {
          sink.add(chunk);
          receivedBytes += chunk.length;
          onProgress?.call(receivedBytes, expectedTotalBytes);
        } catch (e, st) {
          failWith(e, st);
        }
      },
      onError: (Object e, StackTrace st) => failWith(e, st),
      onDone: () {
        stallTimer?.cancel();
        if (!done.isCompleted) {
          done.complete();
        }
      },
      cancelOnError: true,
    );

    try {
      await done.future;
      await sink.flush();
    } finally {
      stallTimer?.cancel();
      await sub.cancel();
      await sink.close();
    }
  }

  static Future<String> _verifyPartFileSha256(File file) async {
    final digestSink = AccumulatorSink<Digest>();
    final hashInput = sha256.startChunkedConversion(digestSink);
    await for (final chunk in file.openRead()) {
      hashInput.add(chunk);
    }
    hashInput.close();
    return digestSink.events.single.toString().toLowerCase();
  }

  static bool _isStorageError(Object error) {
    if (error is DownloadStorageException) return true;
    if (error is FileSystemException) {
      final msg = '${error.message} ${error.osError?.message ?? ''}'.toLowerCase();
      final code = error.osError?.errorCode;
      // Linux/Android ENOSPC = 28, EDQUOT = 122; Windows ERROR_DISK_FULL = 112, ERROR_HANDLE_DISK_FULL = 39
      if (code == 28 || code == 122 || code == 112 || code == 39) return true;
      if (msg.contains('no space') ||
          msg.contains('disk full') ||
          msg.contains('enospc') ||
          msg.contains('not enough space')) {
        return true;
      }
    }
    return false;
  }

  static bool _isTransientDownloadError(Object error) {
    return error is http.ClientException ||
        error is SocketException ||
        error is HttpException ||
        error is TimeoutException ||
        error is HandshakeException;
  }
}

class _ParsedContentRange {
  final int start;
  final int end;
  final int? total;

  const _ParsedContentRange({
    required this.start,
    required this.end,
    required this.total,
  });
}
