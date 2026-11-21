import 'dart:convert';
import 'dart:io';

import 'package:Orvia/services/updater/app_version.dart';

/// Platform-specific release asset info.
class ReleasePlatform {
  final String downloadUrl;
  final String sha256;
  final int? fileSize;

  const ReleasePlatform({
    required this.downloadUrl,
    required this.sha256,
    this.fileSize,
  });

  factory ReleasePlatform.fromJson(Map<String, dynamic> json) {
    final rawUrl = json['download_url'] ?? json['url'];
    if (rawUrl == null || rawUrl is! String || rawUrl.trim().isEmpty) {
      throw const FormatException('Missing or invalid "download_url" in platform release');
    }

    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !uri.hasAuthority) {
      throw FormatException('Invalid download URL: $rawUrl');
    }

    final isLocal = uri.host == 'localhost' || uri.host == '127.0.0.1';
    if (!uri.isScheme('https') && !(uri.isScheme('http') && isLocal)) {
      throw FormatException('Download URL must use secure HTTPS: $rawUrl');
    }

    final rawSha = json['sha256'] ?? json['sha_256'] ?? json['checksum'];
    if (rawSha == null || rawSha is! String || rawSha.trim().isEmpty) {
      throw const FormatException('Missing or invalid "sha256" checksum in platform release');
    }

    final cleanedSha = rawSha.trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(cleanedSha)) {
      throw FormatException('Malformed SHA-256 checksum (must be 64 hex characters): $rawSha');
    }

    int? size;
    if (json['file_size'] != null) {
      size = int.tryParse(json['file_size'].toString());
    }

    return ReleasePlatform(
      downloadUrl: rawUrl.trim(),
      sha256: cleanedSha,
      fileSize: size,
    );
  }

  Map<String, dynamic> toJson() => {
        'download_url': downloadUrl,
        'sha256': sha256,
        if (fileSize != null) 'file_size': fileSize,
      };
}

/// Release info for a specific distribution channel (e.g. 'stable' or 'preview').
class ReleaseChannel {
  final String name;
  final String version;
  final int buildNumber;
  final String releaseNotes;
  final String? publishedAt;
  final Map<String, ReleasePlatform> platforms;

  const ReleaseChannel({
    required this.name,
    required this.version,
    required this.buildNumber,
    required this.releaseNotes,
    this.publishedAt,
    required this.platforms,
  });

  /// Retrieve the release asset corresponding to the current host operating system.
  ReleasePlatform? get currentPlatformRelease {
    String platformKey = 'windows';
    if (Platform.isAndroid) {
      platformKey = 'android';
    } else if (Platform.isLinux) {
      platformKey = 'linux';
    } else if (Platform.isMacOS) {
      platformKey = 'macos';
    } else if (Platform.isWindows) {
      platformKey = 'windows';
    }
    return platforms[platformKey] ?? platforms['all'] ?? platforms['default'];
  }

  factory ReleaseChannel.fromJson(String channelName, Map<String, dynamic> json) {
    final ver = json['version'];
    if (ver == null || ver is! String || ver.trim().isEmpty) {
      throw FormatException('Channel "$channelName" is missing required "version"');
    }

    if (AppVersion.tryParse(ver.trim()) == null) {
      throw FormatException('Malformed version string in channel "$channelName": "$ver"');
    }

    final build = int.tryParse(json['build_number']?.toString() ?? json['build']?.toString() ?? '0') ?? 0;
    final notes = (json['release_notes'] ?? json['notes'] ?? json['changelog'] ?? '').toString();
    final published = json['published_at']?.toString();

    final platformsMap = <String, ReleasePlatform>{};
    if (json['platforms'] is Map) {
      final pMap = json['platforms'] as Map;
      for (final entry in pMap.entries) {
        if (entry.value is Map) {
          try {
            platformsMap[entry.key.toString().toLowerCase()] =
                ReleasePlatform.fromJson(Map<String, dynamic>.from(entry.value as Map));
          } catch (_) {
            rethrow;
          }
        }
      }
    } else if (json['download_url'] != null && json['sha256'] != null) {
      // Direct platform fallback inside channel
      platformsMap['android'] = ReleasePlatform.fromJson(json);
      platformsMap['default'] = platformsMap['android']!;
    }

    return ReleaseChannel(
      name: channelName,
      version: ver.trim(),
      buildNumber: build,
      releaseNotes: notes,
      publishedAt: published,
      platforms: platformsMap,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'build_number': buildNumber,
        'release_notes': releaseNotes,
        if (publishedAt != null) 'published_at': publishedAt,
        'platforms': platforms.map((k, v) => MapEntry(k, v.toJson())),
      };
}

/// Official Orvia Release Manifest structure.
class ReleaseManifest {
  final int schemaVersion;
  final String appName;
  final String? minSupportedVersion;
  final Map<String, ReleaseChannel> channels;

  const ReleaseManifest({
    this.schemaVersion = 1,
    this.appName = 'Orvia',
    this.minSupportedVersion,
    required this.channels,
  });

  ReleaseChannel? get stable => channels['stable'];
  ReleaseChannel? get preview => channels['preview'] ?? channels['prerelease'] ?? channels['beta'];

  /// Retrieve the requested channel, defaulting to 'stable'.
  ReleaseChannel? getChannel([String channelName = 'stable']) {
    return channels[channelName.toLowerCase()] ?? channels['stable'];
  }

  /// Parse and strictly validate a release manifest from a JSON string or decoded Map.
  factory ReleaseManifest.parse(dynamic rawJson) {
    Map<String, dynamic> json;
    if (rawJson is String) {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map) {
        throw const FormatException('Manifest root must be a JSON object');
      }
      json = Map<String, dynamic>.from(decoded);
    } else if (rawJson is Map) {
      json = Map<String, dynamic>.from(rawJson);
    } else {
      throw const FormatException('Manifest content must be a JSON object or string');
    }

    final schemaVer = int.tryParse(json['schema_version']?.toString() ?? '1') ?? 1;
    final app = (json['app_name'] ?? 'Orvia').toString();
    final minVer = json['min_supported_version']?.toString().trim();

    if (minVer != null && minVer.isNotEmpty) {
      if (AppVersion.tryParse(minVer) == null) {
        throw FormatException('Malformed min_supported_version in manifest: "$minVer"');
      }
    }

    final channelsMap = <String, ReleaseChannel>{};

    if (json['channels'] is Map) {
      final cMap = json['channels'] as Map;
      for (final entry in cMap.entries) {
        if (entry.value is Map) {
          final cName = entry.key.toString().toLowerCase();
          channelsMap[cName] =
              ReleaseChannel.fromJson(cName, Map<String, dynamic>.from(entry.value as Map));
        }
      }
    } else if (json['version'] != null) {
      // Backward compatibility: flat single-release structure
      channelsMap['stable'] = ReleaseChannel.fromJson('stable', json);
    }

    if (channelsMap.isEmpty) {
      throw const FormatException('Release manifest does not contain any valid release channels');
    }

    return ReleaseManifest(
      schemaVersion: schemaVer,
      appName: app,
      minSupportedVersion: minVer,
      channels: channelsMap,
    );
  }

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'app_name': appName,
        if (minSupportedVersion != null) 'min_supported_version': minSupportedVersion,
        'channels': channels.map((k, v) => MapEntry(k, v.toJson())),
      };
}
