import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'package:Orvia/core/constants/setting_keys.dart';
import 'package:Orvia/services/db/dao/settings_dao.dart';
import 'package:Orvia/services/db/db_provider.dart';
import 'package:Orvia/services/updater/app_version.dart';
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

  /// Download an APK file from [downloadUrl] and verify its integrity against [expectedSha256].
  ///
  /// Throws [IntegrityCheckException] if the checksum does not match.
  /// Rejects cleartext HTTP downgrades upon redirect.
  /// Cleans up any partially downloaded or invalid files on error.
  Future<File> downloadAndVerifyFile({
    required String downloadUrl,
    required String expectedSha256,
    required File destinationFile,
    Duration timeout = const Duration(minutes: 5),
    void Function(int received, int total)? onProgress,
  }) async {
    final uri = Uri.tryParse(downloadUrl);
    final isLocal = uri != null && (uri.host == 'localhost' || uri.host == '127.0.0.1');

    if (uri == null || !uri.hasAuthority ||
        (!uri.isScheme('https') && !(uri.isScheme('http') && isLocal))) {
      throw ArgumentError('Download URL must use secure HTTPS: $downloadUrl');
    }

    final cleanedExpectedSha = expectedSha256.trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(cleanedExpectedSha)) {
      throw ArgumentError('Invalid expected SHA-256 checksum: $expectedSha256');
    }

    if (destinationFile.existsSync()) {
      destinationFile.deleteSync();
    }
    destinationFile.parent.createSync(recursive: true);

    final request = http.Request('GET', uri);
    final response = await _client.send(request).timeout(timeout);

    // Safeguard against cleartext downgrade redirects
    final finalUrl = response.request?.url;
    if (finalUrl != null && !finalUrl.isScheme('https')) {
      final isFinalLocal = finalUrl.host == 'localhost' || finalUrl.host == '127.0.0.1';
      if (!isFinalLocal) {
        throw HttpException('Insecure redirect to cleartext HTTP rejected: $finalUrl', uri: uri);
      }
    }

    if (response.statusCode != 200) {
      if (destinationFile.existsSync()) destinationFile.deleteSync();
      throw HttpException('Failed to download file: HTTP ${response.statusCode}', uri: uri);
    }

    final totalBytes = response.contentLength ?? -1;
    int receivedBytes = 0;
    final sink = destinationFile.openWrite();
    final byteChunks = <int>[];

    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        byteChunks.addAll(chunk);
        receivedBytes += chunk.length;
        if (onProgress != null) {
          onProgress(receivedBytes, totalBytes);
        }
      }
      await sink.flush();
      await sink.close();
    } catch (e) {
      await sink.close();
      if (destinationFile.existsSync()) destinationFile.deleteSync();
      rethrow;
    }

    // Verify SHA-256
    final actualDigest = sha256.convert(byteChunks).toString().toLowerCase();
    if (actualDigest != cleanedExpectedSha) {
      if (destinationFile.existsSync()) destinationFile.deleteSync();
      throw IntegrityCheckException(
        'Downloaded file SHA-256 mismatch!\n'
        'Expected: $cleanedExpectedSha\n'
        'Actual:   $actualDigest',
      );
    }

    return destinationFile;
  }
}
