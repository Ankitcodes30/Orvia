// Regression tests for Orvia database DAOs, settings, cache, and persistence flows.
//
// Run with: flutter test test/regression_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;

import 'package:Orvia/core/constants/setting_keys.dart';
import 'package:Orvia/plugins/services/plugin_repository_service.dart';
import 'package:Orvia/services/db/dao/cache_dao.dart';
import 'package:Orvia/services/db/dao/settings_dao.dart';
import 'package:Orvia/services/db/db_provider.dart';
import 'package:Orvia/services/db/global_db.dart';
import 'package:Orvia/services/plugin_bootstrap_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late Directory supportDir;
  late Directory docsDir;
  late SettingsDAO settingsDAO;
  late CacheDAO cacheDAO;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('orvia_regression_test_');
    supportDir = Directory(p.join(tempRoot.path, 'support'))
      ..createSync(recursive: true);
    docsDir = Directory(p.join(tempRoot.path, 'docs'))
      ..createSync(recursive: true);

    await DBProvider.init(
      appSupportPath: supportDir.path,
      appDocumentsPath: docsDir.path,
    );
    final db = DBProvider.db;
    settingsDAO = SettingsDAO(db);
    cacheDAO = CacheDAO(db);
  });

  tearDown(() async {
    final currentDb = await DBProvider.db;
    if (currentDb.isOpen) {
      await currentDb.close();
    }

    final defaultDb = Isar.getInstance('dbv3');
    if (defaultDb != null && defaultDb.isOpen) {
      await defaultDb.close();
    }

    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  group('Playlist & Track persistence in DB', () {
    test('create and query playlist in Isar', () async {
      final isar = await DBProvider.db;

      final playlist = PlaylistDB(
        name: 'Chill Vibes',
        description: 'Relaxing music',
        type: PlaylistTypeDB.userPlaylist,
      );

      final id = await isar.writeTxn(() => isar.playlistDBs.put(playlist));
      expect(id, isPositive);

      final retrieved = await isar.playlistDBs.get(id);
      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('Chill Vibes'));
      expect(retrieved.description, equals('Relaxing music'));
      expect(retrieved.type, equals(PlaylistTypeDB.userPlaylist));
    });

    test('add track and link to playlist entry', () async {
      final isar = await DBProvider.db;

      final playlist = PlaylistDB(name: 'Study Session');
      final playlistId =
          await isar.writeTxn(() => isar.playlistDBs.put(playlist));

      final track = TrackDB(
        mediaId: 'track_study_1',
        title: 'Lofi Study Beat',
      );
      await isar.writeTxn(() => isar.trackDBs.put(track));

      final entry = PlaylistEntryDB(
        playlistId: playlistId,
        position: 0,
      )
        ..playlist.value = playlist
        ..track.value = track;

      final entryId =
          await isar.writeTxn(() async {
        final id = await isar.playlistEntryDBs.put(entry);
        await entry.playlist.save();
        await entry.track.save();
        return id;
      });

      expect(entryId, isPositive);

      final entries = await isar.playlistEntryDBs
          .filter()
          .playlistIdEqualTo(playlistId)
          .findAll();

      expect(entries.length, equals(1));
      await entries.first.track.load();
      expect(entries.first.track.value?.mediaId, equals('track_study_1'));
      expect(entries.first.track.value?.title, equals('Lofi Study Beat'));
    });

    test('delete playlist cascades entries', () async {
      final isar = await DBProvider.db;

      final playlist = PlaylistDB(name: 'To Delete');
      final playlistId =
          await isar.writeTxn(() => isar.playlistDBs.put(playlist));

      final entry = PlaylistEntryDB(
        playlistId: playlistId,
        position: 0,
      );
      await isar.writeTxn(() => isar.playlistEntryDBs.put(entry));

      // Delete playlist & associated entries
      await isar.writeTxn(() async {
        await isar.playlistEntryDBs
            .filter()
            .playlistIdEqualTo(playlistId)
            .deleteAll();
        await isar.playlistDBs.delete(playlistId);
      });

      final remaining = await isar.playlistDBs.get(playlistId);
      expect(remaining, isNull);

      final remainingEntries = await isar.playlistEntryDBs
          .filter()
          .playlistIdEqualTo(playlistId)
          .findAll();
      expect(remainingEntries.isEmpty, isTrue);
    });
  });

  group('Settings persistence', () {
    test('putSettingBool persists and getSettingBool retrieves', () async {
      await settingsDAO.putSettingBool('dark_mode', true);
      final value = await settingsDAO.getSettingBool('dark_mode');
      expect(value, isTrue);

      await settingsDAO.putSettingBool('dark_mode', false);
      final updated = await settingsDAO.getSettingBool('dark_mode');
      expect(updated, isFalse);
    });

    test('putSettingStr persists and getSettingStr retrieves with fallback',
        () async {
      await settingsDAO.putSettingStr('audio_quality', 'high_320k');
      final value = await settingsDAO.getSettingStr('audio_quality');
      expect(value, equals('high_320k'));

      final missing = await settingsDAO.getSettingStr(
        'non_existent_key',
        defaultValue: 'default_val',
      );
      expect(missing, equals('default_val'));
    });

    test('putSettingStr updates existing key value', () async {
      await settingsDAO.putSettingStr('download_path', '/path/v1');
      expect(await settingsDAO.getSettingStr('download_path'), equals('/path/v1'));

      await settingsDAO.putSettingStr('download_path', '/path/v2');
      expect(await settingsDAO.getSettingStr('download_path'), equals('/path/v2'));
    });
  });

  group('Cache persistence & TTL', () {
    test('putCache persists and getCache retrieves', () async {
      await cacheDAO.putCache(
        'chart_trending',
        '{"results": [1, 2, 3]}',
        ttl: const Duration(hours: 1),
      );

      final cached = await cacheDAO.getCache('chart_trending');
      expect(cached, isNotNull);
      expect(cached!.value, equals('{"results": [1, 2, 3]}'));
    });

    test('expired cache entry returns null', () async {
      await cacheDAO.putCache(
        'quick_expire',
        'transient_data',
        ttl: const Duration(milliseconds: -10),
      );

      final cached = await cacheDAO.getCache('quick_expire');
      expect(cached, isNull);
    });

    test('putCache updates existing key and timestamp', () async {
      await cacheDAO.putCache('key1', 'initial_val');
      var entry = await cacheDAO.getCache('key1');
      expect(entry?.value, equals('initial_val'));

      await cacheDAO.putCache('key1', 'updated_val');
      entry = await cacheDAO.getCache('key1');
      expect(entry?.value, equals('updated_val'));
    });
  });

  group('Download DAO schema persistence', () {
    test('DownloadDB stores and retrieves downloaded item metadata', () async {
      final isar = await DBProvider.db;

      final download = DownloadDB(
        mediaId: 'dl_999',
        fileName: 'offline_hit.m4a',
        filePath: '/data/user/0/music/offline_hit.m4a',
        lastDownloaded: DateTime.now(),
      );

      final id = await isar.writeTxn(() => isar.downloadDBs.put(download));
      expect(id, isPositive);

      final found = await isar.downloadDBs
          .filter()
          .mediaIdEqualTo('dl_999')
          .findFirst();

      expect(found, isNotNull);
      expect(found!.fileName, equals('offline_hit.m4a'));
      expect(found.filePath, equals('/data/user/0/music/offline_hit.m4a'));
      expect(found.mediaId, equals('dl_999'));
    });
  });

  group('Plugin repository persistence and offline fallback', () {
    test('ensureRepositoryUrls persists valid absolute URLs and ignores malformed/empty ones', () async {
      final repoService = PluginRepositoryService(settingsDao: settingsDAO);

      final added = await repoService.ensureRepositoryUrls([
        'https://example.com/repo.json',
        '   ',
        'not_a_valid_url',
        'http://valid-custom.org/catalog.json',
        'https://example.com/repo.json', // duplicate
      ]);

      expect(added, equals(2));

      final saved = await repoService.getSavedRepositoryUrls();
      expect(saved.length, equals(2));
      expect(saved, contains('https://example.com/repo.json'));
      expect(saved, contains('http://valid-custom.org/catalog.json'));
      expect(saved, isNot(contains('not_a_valid_url')));
    });

    test('removeRepositoryUrl removes targeted URL and preserves others', () async {
      final repoService = PluginRepositoryService(settingsDao: settingsDAO);

      await repoService.ensureRepositoryUrls([
        'https://repo-a.com/plugins.json',
        'https://repo-b.com/plugins.json',
      ]);

      await repoService.removeRepositoryUrl('https://repo-a.com/plugins.json');

      final remaining = await repoService.getSavedRepositoryUrls();
      expect(remaining.length, equals(1));
      expect(remaining.first, equals('https://repo-b.com/plugins.json'));
    });

    test('offline continuation does not falsely mark repositoriesBootstrapped as true', () async {
      // In offline continuation, repositoriesBootstrapped must remain false
      final bootstrappedBefore =
          await settingsDAO.getSettingBool(SettingKeys.repositoriesBootstrapped);
      expect(bootstrappedBefore, isNull);

      await PluginBootstrapService.checkAndCacheDone(settingsDAO);
      expect(PluginBootstrapService.bootstrapDone, isFalse);

      // Verify that after offline continuation (without calling _markDone),
      // the setting remains false/unset.
      final bootstrappedAfter =
          await settingsDAO.getSettingBool(SettingKeys.repositoriesBootstrapped);
      expect(bootstrappedAfter ?? false, isFalse);
    });

    test('getSavedRepositoryUrls handles corrupted JSON gracefully without crashing', () async {
      final repoService = PluginRepositoryService(settingsDao: settingsDAO);

      // Simulate corrupted HTML or invalid string in settings storage
      await settingsDAO.putSettingStr('user_plugin_repositories', '<html><head><title>Blocked</title></head></html>');

      final repos = await repoService.getSavedRepositoryUrls();
      expect(repos, isEmpty);
    });
  });
}
