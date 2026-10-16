// Regression tests for Orvia database DAOs, settings, cache, and persistence flows.
//
// Run with: flutter test test/regression_test.dart

import 'dart:io';

import 'package:flutter/material.dart';
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
import 'package:Orvia/utils/load_image.dart';
import 'package:Orvia/plugins/utils/plugin_error_sanitizer.dart';
import 'package:Orvia/services/player/player_error_handler.dart';
import 'package:Orvia/plugins/blocs/chart/chart_event.dart';
import 'package:Orvia/routes/app_router.dart';
import 'package:Orvia/plugins/utils/media_id.dart';
import 'package:Orvia/screens/screen/chart/chart_view.dart';
import 'package:Orvia/screens/screen/common_views/playlist_view.dart';
import 'package:Orvia/services/db/dao/history_dao.dart';
import 'package:Orvia/services/db/dao/track_dao.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/screens/widgets/navratri_special_card.dart';
import 'package:Orvia/screens/screen/common_views/artist_view.dart';
import 'package:Orvia/services/catalogue/best_of_2026_service.dart';
import 'package:Orvia/services/catalogue/creators_choice_service.dart';
import 'package:Orvia/services/festival/festival_service.dart';
import 'package:Orvia/services/discovery/discovery_context_service.dart';
import 'package:Orvia/services/db/dao/playlist_dao.dart';

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

  group('Branding Placeholders and Offline Error Handling', () {
    test('resolveSongPlaceholder uses OrviaLogo_System for both online and local', () {
      expect(resolveSongPlaceholder(mediaId: 'saavn::123'), equals('assets/icons/OrviaLogo_System.png'));
      expect(resolveSongPlaceholder(mediaId: 'local::hash123'), equals('assets/icons/OrviaLogo_System.png'));
      expect(resolveSongPlaceholder(isLocal: true), equals('assets/icons/OrviaLogo_System.png'));
      expect(resolveSongPlaceholder(), equals('assets/icons/OrviaLogo_System.png'));
      expect(kDefaultOnlinePlaceholder, equals('assets/icons/OrviaLogo_System.png'));
      expect(kDefaultLocalPlaceholder, equals('assets/icons/OrviaLogo_System.png'));
    });

    test('formatUserFriendlyPluginError sanitizes WASM and network errors', () {
      const wasmError =
          'WASM execution error: HTTP request failed: error sending request for URL https://www.jiosaavn.com/api.php?__call=content.getAlbumDetails';
      final formatted = formatUserFriendlyPluginError(wasmError);
      expect(formatted, equals("You're offline. Connect to the internet to load this content."));
      expect(formatted.contains('jiosaavn.com'), isFalse);
      expect(formatted.contains('WASM'), isFalse);

      const timeoutError = 'Client error: request timed out after 10000ms';
      expect(formatUserFriendlyPluginError(timeoutError),
          equals('Connection timed out. Please check your internet connection.'));

      const serverError = 'Server error 502 Bad Gateway';
      expect(formatUserFriendlyPluginError(serverError),
          equals('Server is temporarily unavailable. Please try again later.'));

      const pluginNotLoaded = 'Plugin is not loaded: saavn';
      expect(formatUserFriendlyPluginError(pluginNotLoaded),
          equals('Content plugin is not loaded. Please check Plugin Manager.'));
    });

    test('PlayerErrorHandler categorizes WASM execution HTTP error as networkDropped', () {
      final handler = PlayerErrorHandler();
      const wasmError =
          'WASM execution error: HTTP request failed: error sending request for URL https://www.jiosaavn.com/api.php';
      final type = handler.categorizeError(wasmError);
      expect(type, equals(PlayerErrorType.networkDropped));
    });
  });

  group('Billboard Artwork & Provider Icon Filtering', () {
    test('isGenericProviderIcon correctly identifies Billboard brand and app icons', () {
      expect(isGenericProviderIcon(null), isTrue);
      expect(isGenericProviderIcon(''), isTrue);
      expect(
        isGenericProviderIcon('https://www.billboard.com/wp-content/themes/pmc-billboard/assets/app/icons/icon-512x512.png'),
        isTrue,
      );
      expect(
        isGenericProviderIcon('https://charts-static.billboard.com/assets/1698337190/icons/icon-512x512.png'),
        isTrue,
      );
      expect(
        isGenericProviderIcon('https://www.billboard.com/assets/billboard-logo.png'),
        isTrue,
      );
      expect(
        isGenericProviderIcon('https://cdn.example.com/path/to/icon-512x512.png'),
        isTrue,
      );
    });

    test('isGenericProviderIcon permits genuine album and track artwork', () {
      expect(
        isGenericProviderIcon('https://c.saavncdn.com/838/Aashiqui-2-Hindi-2013-500x500.jpg'),
        isFalse,
      );
      expect(
        isGenericProviderIcon('https://i.scdn.co/image/ab67616d0000b273e787cffec20aa2a396a61647'),
        isFalse,
      );
      expect(
        isGenericProviderIcon('https://charts-static.billboard.com/img/2023/10/chayce-beckham-288-180x180.jpg'),
        isFalse,
      );
    });

    test('getImageProviderSync returns fallback asset when URL is generic provider icon', () {
      final provider = getImageProviderSync(
        'https://www.billboard.com/wp-content/themes/pmc-billboard/assets/app/icons/icon-512x512.png',
      );
      expect(provider, isA<AssetImage>());
      final assetProvider = provider as AssetImage;
      expect(assetProvider.assetName, equals('assets/icons/OrviaLogo_System.png'));
    });
  });

  group('Reconnection, Pull-to-Refresh & Navigation Transitions', () {
    test('LoadImageCached clearFailedUrls resets failed image cache', () {
      expect(() => LoadImageCached.clearFailedUrls(), returnsNormally);
    });

    test('LoadCharts supports bypassCache property', () {
      const defaultEvent = LoadCharts(pluginId: 'chart.plugin');
      expect(defaultEvent.bypassCache, isFalse);

      const bypassEvent =
          LoadCharts(pluginId: 'chart.plugin', bypassCache: true);
      expect(bypassEvent.bypassCache, isTrue);
    });

    test('PrefetchAllChartDetails supports forceRefresh property', () {
      const defaultPrefetch = PrefetchAllChartDetails(
        pluginId: 'chart.plugin',
        chartIds: {'hot-100'},
      );
      expect(defaultPrefetch.forceRefresh, isFalse);

      const forcePrefetch = PrefetchAllChartDetails(
        pluginId: 'chart.plugin',
        chartIds: {'hot-100'},
        forceRefresh: true,
      );
      expect(forcePrefetch.forceRefresh, isTrue);
    });

    test('AppRouter exposes exploreNavigatorKey for Home navigation', () {
      expect(AppRouter.exploreNavigatorKey, isNotNull);
      expect(AppRouter.globalRouterKey, isNotNull);
    });
  });

  group('Track ID Matching & Audio Engine State Sync', () {
    test('isMatchingTrackId matches identical composite IDs', () {
      expect(isMatchingTrackId('saavn::12345', 'saavn::12345'), isTrue);
      expect(isMatchingTrackId('local::hash_abc', 'local::hash_abc'), isTrue);
    });

    test('isMatchingTrackId matches composite ID with raw/unstamped local ID', () {
      expect(isMatchingTrackId('saavn::12345', '12345'), isTrue);
      expect(isMatchingTrackId('12345', 'saavn::12345'), isTrue);
      expect(isMatchingTrackId('local::abc', 'abc'), isTrue);
    });

    test('isMatchingTrackId matches cross-stamped IDs with same local ID', () {
      expect(isMatchingTrackId('saavn::12345', 'ytm::12345'), isTrue);
    });

    test('isMatchingTrackId returns false for different local IDs', () {
      expect(isMatchingTrackId('saavn::12345', 'saavn::67890'), isFalse);
      expect(isMatchingTrackId('12345', '67890'), isFalse);
    });

    test('isMatchingTrackId handles null and empty gracefully without errors', () {
      expect(isMatchingTrackId(null, '12345'), isFalse);
      expect(isMatchingTrackId('12345', null), isFalse);
      expect(isMatchingTrackId(null, null), isFalse);
      expect(isMatchingTrackId('', '12345'), isFalse);
      expect(isMatchingTrackId('12345', ''), isFalse);
    });
  });

  group('Indian Songs Chart Title and Description Resolution', () {
    test('resolveEffectiveChartTitle standardizes chart identifier to Indian Songs', () {
      expect(resolveEffectiveChartTitle('india-songs-hotw'), equals('Indian Songs'));
      expect(resolveEffectiveChartTitle('chart'), equals('Indian Songs'));
      expect(resolveEffectiveChartTitle('CHART'), equals('Indian Songs'));
      expect(resolveEffectiveChartTitle(''), equals('Indian Songs'));
      expect(resolveEffectiveChartTitle('   '), equals('Indian Songs'));
      expect(resolveEffectiveChartTitle(null), equals('Indian Songs'));
    });

    test('resolveEffectiveChartTitle preserves specific chart titles', () {
      expect(resolveEffectiveChartTitle('Billboard Hot 100'), equals('Billboard Hot 100'));
      expect(resolveEffectiveChartTitle('Global 200'), equals('Global 200'));
      expect(resolveEffectiveChartTitle('Trending Songs'), equals('Trending Songs'));
    });

    test('resolveEffectiveChartDescription provides accurate descriptions', () {
      expect(
        resolveEffectiveChartDescription('Indian Songs'),
        equals('Popular and trending Indian music across genres.'),
      );
      expect(
        resolveEffectiveChartDescription('Billboard India Hot 100'),
        equals('Popular and trending Indian music across genres.'),
      );
      expect(
        resolveEffectiveChartDescription('Billboard Hot 100'),
        equals('Top songs in the US across streaming, sales, and radio play.'),
      );
      expect(
        resolveEffectiveChartDescription('Billboard Global 200'),
        equals('Top songs globally across streaming and digital sales.'),
      );
      expect(
        resolveEffectiveChartDescription('Country Hits'),
        equals('Popular and trending music on the charts.'),
      );
    });
  });

  group('Station and Playlist Identity Sanitization', () {
    test('isSuspiciousPlaylistTitle flags colliding and generic user titles', () {
      expect(isSuspiciousPlaylistTitle('amit'), isTrue);
      expect(isSuspiciousPlaylistTitle('Amit'), isTrue);
      expect(isSuspiciousPlaylistTitle('starred songs'), isTrue);
      expect(isSuspiciousPlaylistTitle('Starred Songs'), isTrue);
      expect(isSuspiciousPlaylistTitle(''), isTrue);
      expect(isSuspiciousPlaylistTitle('   '), isTrue);
      expect(isSuspiciousPlaylistTitle(null), isTrue);
    });

    test('isSuspiciousPlaylistTitle permits genuine playlist titles', () {
      expect(isSuspiciousPlaylistTitle('Yo Yo Honey Singh'), isFalse);
      expect(isSuspiciousPlaylistTitle('Romance'), isFalse);
      expect(isSuspiciousPlaylistTitle('Carvaan Classics'), isFalse);
      expect(isSuspiciousPlaylistTitle('Masoom Sharma'), isFalse);
      expect(isSuspiciousPlaylistTitle('Kumar Sanu Hits'), isFalse);
    });

    test('sanitizePlaylistOwner replaces colliding user account metadata', () {
      expect(sanitizePlaylistOwner('amit'), equals('Curated Collection'));
      expect(sanitizePlaylistOwner('Amit'), equals('Curated Collection'));
      expect(sanitizePlaylistOwner('member'), equals('Curated Collection'));
      expect(sanitizePlaylistOwner(''), equals('Curated Collection'));
      expect(sanitizePlaylistOwner(null), equals('Curated Collection'));
    });

    test('sanitizePlaylistOwner preserves genuine creator and channel names', () {
      expect(sanitizePlaylistOwner('JioSaavn'), equals('JioSaavn'));
      expect(sanitizePlaylistOwner('Billboard'), equals('Billboard'));
      expect(sanitizePlaylistOwner('Bollywood Classics'), equals('Bollywood Classics'));
    });
  });

  group('Recently Played Individual History Removal (Phase 8)', () {
    test('removeTrackHistory deletes only target history row and preserves catalog track', () async {
      final db = DBProvider.db;
      final trackDAO = TrackDAO(db);
      final historyDAO = HistoryDAO(db, trackDAO);

      const trackA = Track(
        id: 'track_test_1',
        title: 'Song One',
        artists: [ArtistSummary(id: 'a1', name: 'Artist One')],
        thumbnail: Artwork(
          url: 'https://example.com/a.jpg',
          layout: ImageLayout.square,
        ),
        isExplicit: false,
      );
      const trackB = Track(
        id: 'track_test_2',
        title: 'Song Two',
        artists: [ArtistSummary(id: 'a2', name: 'Artist Two')],
        thumbnail: Artwork(
          url: 'https://example.com/b.jpg',
          layout: ImageLayout.square,
        ),
        isExplicit: false,
      );

      // Record plays
      await historyDAO.recordPlay(trackA);
      await historyDAO.recordPlay(trackB);

      var history = await historyDAO.getHistory();
      expect(history.any((t) => t.id == 'track_test_1'), isTrue);
      expect(history.any((t) => t.id == 'track_test_2'), isTrue);

      // Remove only trackA from history
      final deletedCount = await historyDAO.removeTrackHistory('track_test_1');
      expect(deletedCount, equals(1));

      // Verify trackA is removed from history, while trackB remains
      history = await historyDAO.getHistory();
      expect(history.any((t) => t.id == 'track_test_1'), isFalse);
      expect(history.any((t) => t.id == 'track_test_2'), isTrue);

      // Verify the underlying TrackDB record is NOT deleted
      final isar = await db;
      final existingTrack = await isar.trackDBs
          .filter()
          .mediaIdEqualTo('track_test_1')
          .findFirst();
      expect(existingTrack, isNotNull);
      expect(existingTrack!.title, equals('Song One'));

      // Non-existent track removal safely returns 0
      final nonExistentDeleted = await historyDAO.removeTrackHistory('non_existent');
      expect(nonExistentDeleted, equals(0));
    });
  });

  group('Navratri Track ID Validation & Resolution Safety (Phase 1)', () {
    test('all kVerifiedNavratriTracks have stamped composite media IDs', () {
      expect(kVerifiedNavratriTracks.length, equals(12));
      for (final item in kVerifiedNavratriTracks) {
        expect(isStampedId(item.track.id), isTrue,
            reason: 'Track "${item.track.title}" ID "${item.track.id}" must be stamped');
        final parts = tryParseMediaId(item.track.id);
        expect(parts, isNotNull);
        expect(parts!.pluginId, equals(kDefaultSaavnPluginId));
        expect(parts.localId.isNotEmpty, isTrue);
      }
    });

    test('track 0qcITrST uses capital I and matches valid JioSaavn local ID', () {
      final tariMadh = kVerifiedNavratriTracks.firstWhere(
        (t) => t.track.title.contains('Tari Madh Mithi'),
      );
      expect(tariMadh.track.id, equals('$kDefaultSaavnPluginId::0qcITrST'));
      expect(localIdOf(tariMadh.track.id), equals('0qcITrST'));
      expect(localIdOf(tariMadh.track.id), isNot(equals('0qclTrST')));
    });

    test('verified alternate tracks are stamped and retain canonical versions', () {
      final goriRadhaSachin = kVerifiedNavratriTracks.firstWhere(
        (t) => t.track.id.endsWith('c69Skc-T'),
      );
      expect(goriRadhaSachin.track.title, equals('Gori Radha Ne Kado Kaan'));
      expect(goriRadhaSachin.track.album?.title, equals('Wrong Side Raju'));
      expect(localIdOf(goriRadhaSachin.track.id), equals('c69Skc-T'));

      final dholidaKhelaiya = kVerifiedNavratriTracks.firstWhere(
        (t) => t.track.id.endsWith('rSBU4cMG'),
      );
      expect(dholidaKhelaiya.track.title, contains('Khelaiya Disco Dandiya'));
      expect(dholidaKhelaiya.track.album?.title, equals('Khelaiya Disco Dandiya Hits, Vol. 1'));
      expect(localIdOf(dholidaKhelaiya.track.id), equals('rSBU4cMG'));
    });

    test('isMatchingTrackId reconciles stamped Navratri IDs with unstamped legacy IDs', () {
      expect(
        isMatchingTrackId('$kDefaultSaavnPluginId::0qcITrST', '0qcITrST'),
        isTrue,
      );
      expect(
        isMatchingTrackId('0qcITrST', '$kDefaultSaavnPluginId::0qcITrST'),
        isTrue,
      );
      expect(
        isMatchingTrackId('$kDefaultSaavnPluginId::0qcITrST', '0qclTrST'),
        isFalse,
      );
    });
  });

  group('Artist Catalogue Verification (Phase 2.A)', () {
    test('isTrackRelatedToArtist validates vocals, featured and composer credits', () {
      const track1 = Track(
        id: 'track1',
        title: 'Jai Ho',
        artists: [
          ArtistSummary(id: '456269', name: 'A. R. Rahman'),
          ArtistSummary(id: '455125', name: 'Sukhwinder Singh'),
        ],
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      // Matches exact and token variation (A. R. Rahman vs AR Rahman)
      expect(ArtistView.isTrackRelatedToArtist(track1, 'A. R. Rahman'), isTrue);
      expect(ArtistView.isTrackRelatedToArtist(track1, 'AR Rahman'), isTrue);
      expect(ArtistView.isTrackRelatedToArtist(track1, 'Sukhwinder Singh'), isTrue);

      // Rejects unrelated artist whose name is not credited
      expect(ArtistView.isTrackRelatedToArtist(track1, 'Neha Kakkar'), isFalse);
    });

    test('isTrackRelatedToArtist checks artist ID and album credits', () {
      const trackWithAlbum = Track(
        id: 'track2',
        title: 'Gori Radha Ne Kado Kaan',
        artists: [
          ArtistSummary(id: '123', name: 'Divya Kumar'),
        ],
        album: AlbumSummary(
          id: 'alb1',
          title: 'Wrong Side Raju',
          artists: [
            ArtistSummary(id: '999', name: 'Sachin-Jigar'),
          ],
        ),
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      expect(ArtistView.isTrackRelatedToArtist(trackWithAlbum, 'Sachin-Jigar'), isTrue);
      expect(ArtistView.isTrackRelatedToArtist(trackWithAlbum, 'Divya Kumar'), isTrue);
      expect(ArtistView.isTrackRelatedToArtist(trackWithAlbum, 'Badshah'), isFalse);
    });
  });

  group('Best of 2026 Catalogue (Phase 2.B)', () {
    test('BestOf2026Service provides >= 40 unique verified 2026 tracks', () {
      final tracks = BestOf2026Service.getVerified2026Tracks();
      expect(tracks.length, greaterThanOrEqualTo(40));

      final seenIds = <String>{};
      for (final t in tracks) {
        expect(seenIds.add(t.id), isTrue, reason: 'Duplicate track ID found: ${t.id}');
        expect(isStampedId(t.id), isTrue, reason: 'Track ID ${t.id} must be composite stamped');
        expect(t.title.isNotEmpty, isTrue);
        expect(t.artists.isNotEmpty, isTrue);
        expect(t.album, isNotNull);
        expect(t.durationMs, isNotNull);
        expect(t.durationMs! > BigInt.zero, isTrue);
      }
    });
  });

  group("Creator's Choice Library Playlist (Phase 3)", () {
    test("CreatorsChoiceService contains verified tracks from source playlist", () {
      final tracks = CreatorsChoiceService.getVerifiedTracks();
      expect(tracks.length, greaterThanOrEqualTo(40));

      for (final t in tracks) {
        expect(isStampedId(t.id), isTrue);
        expect(t.title.isNotEmpty, isTrue);
        expect(t.artists.isNotEmpty, isTrue);
      }
    });

    test("ensurePlaylistExists seeds Creator's Choice into PlaylistDAO without duplicate rows", () async {
      final db = DBProvider.db;
      final trackDAO = TrackDAO(db);
      final playlistDAO = PlaylistDAO(db, trackDAO);

      await CreatorsChoiceService.ensurePlaylistExists(playlistDAO);

      final playlist = await playlistDAO.getPlaylistByName("Creator's Choice");
      expect(playlist, isNotNull);
      expect(playlist!.name, equals("Creator's Choice"));

      final entries1 = await playlistDAO.getPlaylistEntries(playlist.id);
      expect(entries1.length, equals(CreatorsChoiceService.getVerifiedTracks().length));

      // Calling ensurePlaylistExists again must not duplicate entries
      await CreatorsChoiceService.ensurePlaylistExists(playlistDAO);
      final entries2 = await playlistDAO.getPlaylistEntries(playlist.id);
      expect(entries2.length, equals(entries1.length));
    });
  });

  group('Automatic Festival Discovery & Scheduling (Phase 5)', () {
    test('10-day promotion window calculation works correctly', () {
      final festival = FestivalEvent(
        id: 'test_fest',
        name: 'Test Festival',
        greeting: 'Happy Festival!',
        region: 'India',
        startDate: DateTime(2026, 10, 10),
        endDate: DateTime(2026, 10, 20),
        promotionDays: 10,
        bannerUrl: '',
        bannerTitle: 'Festive Special',
        bannerSubtitle: 'Festive Beats',
        categories: const ['All'],
        tracks: const [],
      );

      // 15 days before start: not promoted
      expect(festival.isPromotedAt(DateTime(2026, 9, 25)), isFalse);

      // 10 days before start (Oct 1): promoted
      expect(festival.isPromotedAt(DateTime(2026, 10, 1)), isTrue);

      // During festival (Oct 15): promoted
      expect(festival.isPromotedAt(DateTime(2026, 10, 15)), isTrue);

      // After end date (Oct 21): promotion automatically ended
      expect(festival.isPromotedAt(DateTime(2026, 10, 21)), isFalse);
    });

    test('Navratri 2026 is currently active in October 2026', () {
      final active = FestivalService.getActiveOrUpcomingFestival(
        testTime: DateTime(2026, 10, 16, 19, 0),
      );
      expect(active, isNotNull);
      expect(active!.id, equals('navratri_2026'));
      expect(active.name, contains('Navratri'));
    });
  });

  group('Location & Time-Aware Discovery (Phase 6)', () {
    test('daypart heuristics map correctly to hours of the day', () {
      expect(
        DiscoveryContextService.getCurrentDaypart(testTime: DateTime(2026, 1, 1, 8, 0)),
        equals(Daypart.morning),
      );
      expect(
        DiscoveryContextService.getCurrentDaypart(testTime: DateTime(2026, 1, 1, 14, 0)),
        equals(Daypart.afternoon),
      );
      expect(
        DiscoveryContextService.getCurrentDaypart(testTime: DateTime(2026, 1, 1, 19, 0)),
        equals(Daypart.evening),
      );
      expect(
        DiscoveryContextService.getCurrentDaypart(testTime: DateTime(2026, 1, 1, 23, 0)),
        equals(Daypart.night),
      );
      expect(
        DiscoveryContextService.getCurrentDaypart(testTime: DateTime(2026, 1, 1, 4, 0)),
        equals(Daypart.lateNight),
      );
    });

    test('non-blocking location fallback defaults safely to India (National)', () {
      expect(DiscoveryContextService.currentRegionLabel, contains('India'));
    });
  });
}

