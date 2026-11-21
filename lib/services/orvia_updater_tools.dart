import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:Orvia/core/constants/setting_keys.dart';
import 'package:Orvia/services/db/db_provider.dart';
import 'package:Orvia/services/db/dao/settings_dao.dart';
import 'package:Orvia/services/updater/app_version.dart';
import 'package:Orvia/services/updater/orvia_update_service.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Accurate semantic version and build comparison.
/// Returns true if and only if [newVer]+[newBuild] is newer than [currentVer]+[currentBuild].
bool isUpdateAvailable(
    String currentVer, String currentBuild, String newVer, String newBuild,
    {bool checkBuild = true}) {
  final cur = AppVersion.tryParse(currentVer, checkBuild ? currentBuild : null);
  final neu = AppVersion.tryParse(newVer, checkBuild ? newBuild : null);
  if (cur == null || neu == null) return false;
  return neu.isAppUpdateOver(cur, checkBuildNumber: checkBuild);
}

/// Legacy SourceForge update checker (kept for compatibility, returns structured result).
Future<Map<String, dynamic>> sourceforgeUpdate(
    {Duration timeout = const Duration(seconds: 6)}) async {
  String platform = Platform.operatingSystem;
  if (platform != 'linux' && platform != 'android' && platform != 'win') {
    platform = 'win';
  }
  const url = 'https://sourceforge.net/projects/orvia/best_release.json';
  final userAgent = {
    'win':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36',
    'linux':
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3868.146 Safari/537.36 OPR/54.0.4087.46',
    'android':
        'Mozilla/5.0 (Linux; Android 13;) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36',
  };

  final headers = {
    'user-agent': userAgent['win']!,
    'accept': 'application/json, text/javascript, */*; q=0.01',
    'referer': 'https://sourceforge.net',
  };
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  try {
    final response =
        await http.get(Uri.parse(url), headers: headers).timeout(timeout);
    log("SourceForge response status code: ${response.statusCode}",
        name: 'UpdaterTools');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      String platformKey = 'windows';
      if (Platform.isLinux) {
        platformKey = 'linux';
      } else if (Platform.isMacOS) {
        platformKey = 'mac';
      } else if (Platform.isAndroid) {
        platformKey = 'android';
      }

      Map? entry = (data['platform_releases'] is Map)
          ? (data['platform_releases'] as Map)[platformKey]
          : null;
      entry ??= data['release'];

      final releaseUrl = (entry != null && entry['url'] != null)
          ? entry['url'] as String
          : (data['release']?['url'] ?? '');
      String filename = (entry != null && entry['filename'] != null)
          ? entry['filename'] as String
          : (data['release']?['filename'] ?? '');

      try {
        filename = Uri.decodeFull(filename);
      } catch (_) {}
      String decodedUrl = releaseUrl;
      try {
        decodedUrl = Uri.decodeFull(releaseUrl);
      } catch (_) {}

      final versionRegex = RegExp(r'v(\d+(?:\.\d+)*)');
      final buildRegex = RegExp(r'\+(\d+)');

      Match? versionMatch = versionRegex.firstMatch(filename);
      versionMatch ??= versionRegex.firstMatch(decodedUrl);
      Match? buildMatch = buildRegex.firstMatch(filename);
      buildMatch ??= buildRegex.firstMatch(decodedUrl);

      final version = versionMatch?.group(1) ?? '';
      final build = buildMatch?.group(1) ?? '';

      final hasUpdate = isUpdateAvailable(
        packageInfo.version,
        packageInfo.buildNumber,
        version.isNotEmpty ? version : '0.0.0',
        build.isNotEmpty ? build : '0',
        checkBuild: platform != 'linux',
      );

      return {
        'source': 'sourceforge',
        'status': hasUpdate ? 'updateAvailable' : 'upToDate',
        'newVer': version,
        'newBuild': build,
        'download_url': releaseUrl,
        'currVer': packageInfo.version,
        'currBuild': packageInfo.buildNumber,
        'results': hasUpdate,
      };
    } else {
      throw HttpException('SourceForge returned ${response.statusCode}');
    }
  } catch (e, st) {
    log('SourceForge update check failed: $e\n$st', name: 'UpdaterTools');
    rethrow;
  }
}

/// Legacy GitHub update checker.
///
/// NOTE: The upstream repository endpoint may return 404 if releases are unpublished.
/// Callers must handle exceptions without interpreting a failure as "up-to-date".
Future<Map<String, dynamic>> githubUpdate(
    {Duration timeout = const Duration(seconds: 6)}) async {
  const url =
      'https://api.github.com/repos/Ankitcodes30/Orvia/releases/latest';
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  try {
    final response = await http.get(Uri.parse(url)).timeout(timeout);
    log("GitHub response status code: ${response.statusCode}",
        name: 'UpdaterTools');
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final tag = (data['tag_name'] as String?) ?? '';
      final tagParts = tag.split('+');
      final versionPart =
          tagParts.isNotEmpty ? tagParts[0].replaceFirst('v', '') : '';
      final buildPart = tagParts.length > 1 ? tagParts[1] : '';

      String? download = extractUpUrl(data);
      download ??= data['html_url'] ?? '';

      final hasUpdate = isUpdateAvailable(
        packageInfo.version,
        packageInfo.buildNumber,
        versionPart.isNotEmpty ? versionPart : '0.0.0',
        buildPart.isNotEmpty ? buildPart : '0',
        checkBuild: true,
      );

      return {
        'source': 'github',
        'status': hasUpdate ? 'updateAvailable' : 'upToDate',
        'newVer': versionPart,
        'newBuild': buildPart,
        'download_url': download,
        'currVer': packageInfo.version,
        'currBuild': packageInfo.buildNumber,
        'results': hasUpdate,
      };
    } else {
      throw HttpException('GitHub returned ${response.statusCode}');
    }
  } catch (e, st) {
    log('GitHub update check failed: $e\n$st', name: 'UpdaterTools');
    rethrow;
  }
}

/// Formats user-facing release notes into structured changelog markdown.
/// Uses the authoritative version and build number from release metadata.
/// Provides a graceful user-friendly fallback if release notes are missing/empty.
/// Never outputs technical package/dependency lists.
String formatReleaseNotesAsChangelog({
  required String version,
  String? buildNumber,
  String? releaseNotes,
}) {
  final cleanVersion = version.trim().replaceFirst(RegExp(r'^v'), '');
  final cleanBuild = buildNumber?.trim();
  final versionTag = (cleanBuild != null && cleanBuild.isNotEmpty)
      ? '$cleanVersion+$cleanBuild'
      : cleanVersion;

  final trimmedNotes = releaseNotes?.trim() ?? '';

  if (trimmedNotes.isEmpty) {
    return '''
## [$versionTag]

### What's New
- Bug fixes and performance improvements.
''';
  }

  // If already formatted with markdown version headings, return as-is
  if (trimmedNotes.contains(RegExp(r'^##\s+\[', multiLine: true))) {
    return trimmedNotes;
  }

  final List<String> bulletPoints = [];
  if (trimmedNotes.contains('\n')) {
    for (final rawLine in trimmedNotes.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('-') || line.startsWith('*')) {
        bulletPoints.add(line.replaceFirst(RegExp(r'^[-*]\s*'), ''));
      } else {
        bulletPoints.add(line);
      }
    }
  } else if (trimmedNotes.contains(', ')) {
    for (final part in trimmedNotes.split(', ')) {
      final t = part.trim();
      if (t.isNotEmpty) bulletPoints.add(t);
    }
  } else {
    bulletPoints.add(trimmedNotes);
  }

  final items = bulletPoints.map((bp) => '- $bp').join('\n');

  return '''
## [$versionTag]

### What's New
$items
''';
}

/// Primary update check API: checks the configured release manifest via [OrviaUpdateService].
/// Returns a structured map containing results, status ('updateAvailable', 'upToDate', 'checkFailed'),
/// version info, and error message if the check could not be completed.
///
/// NEVER reports 'up-to-date' when the check failed!
Future<Map<String, dynamic>> getAppUpdates() async {
  final checkResult = await OrviaUpdateService.instance.checkForUpdates();
  final Map<String, dynamic> updates = checkResult.toLegacyMap();

  try {
    if (DBProvider.isInitialized) {
      final readChangelogs = await SettingsDAO(DBProvider.db)
          .getSettingStr(SettingKeys.readChangelogs);
      final currVer = "v${updates['currVer']}";
      final newVer = "v${updates['newVer']}";

      log('Current version: $currVer, New version: $newVer, Read changelogs: $readChangelogs',
          name: 'UpdaterTools');

      if (currVer == newVer &&
          (readChangelogs == null || readChangelogs != currVer)) {
        final ver = checkResult.currentVersion ?? updates['currVer'] ?? '';
        final build = checkResult.currentBuild ?? updates['currBuild'];
        final changelogText = formatReleaseNotesAsChangelog(
          version: ver,
          buildNumber: build,
          releaseNotes: checkResult.releaseNotes,
        );
        updates['changelogs'] = changelogText;
      } else {
        updates['changelogs'] = null;
      }
    }
  } catch (e, st) {
    log('Attaching changelog failed: $e\n$st', name: 'UpdaterTools');
    updates['changelogs'] = null;
  }

  return updates;
}

/// Fetch the project's CHANGELOG.md from the hosted GitHub Pages site.
/// Returns the changelog text on success, or null on any failure.
Future<String?> fetchChangelog(
    {Duration timeout = const Duration(seconds: 6)}) async {
  const changelogUrl =
      'https://ankitcodes30.github.io/Orvia/CHANGELOG.md';
  try {
    final response = await http.get(Uri.parse(changelogUrl)).timeout(timeout);
    if (response.statusCode == 200) {
      return response.body;
    } else {
      log('Changelog fetch returned status ${response.statusCode}',
          name: 'UpdaterTools');
      return null;
    }
  } catch (e, st) {
    log('Failed to fetch changelog: $e\n$st', name: 'UpdaterTools');
    return null;
  }
}

/// Backwards-compatible wrapper for existing callers
Future<Map<String, dynamic>> getLatestVersion() async => await getAppUpdates();

String? extractUpUrl(Map<String, dynamic> data) {
  if (data["assets"] is! List) return null;
  for (var element in (data["assets"] as List)) {
    final url = element["browser_download_url"]?.toString() ?? '';
    if (url.contains("windows") && Platform.isWindows) {
      return url;
    } else if (url.contains("android") && Platform.isAndroid) {
      return url;
    }
  }
  return null;
}
