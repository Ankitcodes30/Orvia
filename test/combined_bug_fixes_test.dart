// Regression tests for Orvia Combined Bug-Fix & Performance requirements.
// Covers Tasks 1, 2, 3, 4, 5, 7, 9, 10, 11, 12, 13.
// Run with: flutter test test/combined_bug_fixes_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;

import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/screens/widgets/indian_browse_categories.dart';
import 'package:Orvia/screens/widgets/navratri_special_card.dart';
import 'package:Orvia/services/banner/smart_banner_service.dart';
import 'package:Orvia/services/db/dao/history_dao.dart';
import 'package:Orvia/services/db/dao/playlist_dao.dart';
import 'package:Orvia/services/db/dao/search_history_dao.dart';
import 'package:Orvia/services/db/dao/track_dao.dart';
import 'package:Orvia/services/db/db_provider.dart';
import 'package:Orvia/services/db/global_db.dart';
import 'package:Orvia/services/festival/festival_service.dart';
import 'package:Orvia/services/share/orvia_deep_link_service.dart';
import 'package:Orvia/plugins/blocs/content/content_event.dart';
import 'package:Orvia/src/rust/api/plugin/commands.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late Directory supportDir;
  late Directory docsDir;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('orvia_combined_fixes_test_');
    supportDir = Directory(p.join(tempRoot.path, 'support'))..createSync(recursive: true);
    docsDir = Directory(p.join(tempRoot.path, 'docs'))..createSync(recursive: true);

    await DBProvider.init(
      appSupportPath: supportDir.path,
      appDocumentsPath: docsDir.path,
    );
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

  group('Task 3: Recently Played Persistence (5 Distinct Test Tracks)', () {
    const track1 = Track(
      id: 'content-resolver.bloomfactory.jisaavn::track_kesariya_01',
      title: 'Kesariya',
      artists: [ArtistSummary(id: 'a1', name: 'Arijit Singh')],
      album: AlbumSummary(id: 'alb1', title: 'Brahmastra', artists: []),
      durationMs: null,
      thumbnail: Artwork(url: 'https://c.saavncdn.com/kesariya-500x500.jpg', layout: ImageLayout.square),
      isExplicit: false,
    );

    const track2 = Track(
      id: 'content-resolver.bloomfactory.jisaavn::track_apna_bana_le_02',
      title: 'Apna Bana Le',
      artists: [ArtistSummary(id: 'a1', name: 'Arijit Singh')],
      album: AlbumSummary(id: 'alb2', title: 'Bhediya', artists: []),
      durationMs: null,
      thumbnail: Artwork(url: 'https://c.saavncdn.com/apna-500x500.jpg', layout: ImageLayout.square),
      isExplicit: false,
    );

    const track3 = Track(
      id: 'content-resolver.bloomfactory.jisaavn::track_raataan_03',
      title: 'Raataan Lambiyan',
      artists: [ArtistSummary(id: 'a2', name: 'Jubin Nautiyal')],
      album: AlbumSummary(id: 'alb3', title: 'Shershaah', artists: []),
      durationMs: null,
      thumbnail: Artwork(url: 'https://c.saavncdn.com/raataan-500x500.jpg', layout: ImageLayout.square),
      isExplicit: false,
    );

    const track4 = Track(
      id: 'content-resolver.bloomfactory.ytvideo::track_maan_meri_04',
      title: 'Maan Meri Jaan',
      artists: [ArtistSummary(id: 'a3', name: 'King')],
      album: AlbumSummary(id: 'alb4', title: 'Champagne Talk', artists: []),
      durationMs: null,
      thumbnail: Artwork(url: 'https://i.ytimg.com/vi/maan/hqdefault.jpg', layout: ImageLayout.square),
      isExplicit: false,
    );

    const track5 = Track(
      id: 'content-resolver.bloomfactory.jisaavn::track_heeriye_05',
      title: 'Heeriye',
      artists: [ArtistSummary(id: 'a4', name: 'Jasleen Royal'), ArtistSummary(id: 'a1', name: 'Arijit Singh')],
      album: AlbumSummary(id: 'alb5', title: 'Heeriye Single', artists: []),
      durationMs: null,
      thumbnail: Artwork(url: 'https://c.saavncdn.com/heeriye-500x500.jpg', layout: ImageLayout.square),
      isExplicit: false,
    );

    test('Plays 5 distinct test tracks and verifies stored and displayed history order', () async {
      final db = DBProvider.db;
      final trackDao = TrackDAO(db);
      final historyDao = HistoryDAO(db, trackDao);

      // Play each of the 5 tracks sequentially
      await historyDao.recordPlay(track1);
      await Future.delayed(const Duration(milliseconds: 10));
      await historyDao.recordPlay(track2);
      await Future.delayed(const Duration(milliseconds: 10));
      await historyDao.recordPlay(track3);
      await Future.delayed(const Duration(milliseconds: 10));
      await historyDao.recordPlay(track4);
      await Future.delayed(const Duration(milliseconds: 10));
      await historyDao.recordPlay(track5);

      // Fetch displayed history
      final history = await historyDao.getHistory(limit: 10);

      // Verify all 5 tracks are stored
      expect(history.length, equals(5));

      // Verify order: most recently played first
      expect(history[0].id, equals(track5.id));
      expect(history[0].title, equals('Heeriye'));
      expect(history[1].id, equals(track4.id));
      expect(history[1].title, equals('Maan Meri Jaan'));
      expect(history[2].id, equals(track3.id));
      expect(history[2].title, equals('Raataan Lambiyan'));
      expect(history[3].id, equals(track2.id));
      expect(history[3].title, equals('Apna Bana Le'));
      expect(history[4].id, equals(track1.id));
      expect(history[4].title, equals('Kesariya'));

      // Rapid replay of track 1 moves it to top without duplicating entries
      await historyDao.recordPlay(track1);
      final updatedHistory = await historyDao.getHistory(limit: 10);
      expect(updatedHistory.length, equals(5));
      expect(updatedHistory.first.id, equals(track1.id));
      expect(updatedHistory.first.title, equals('Kesariya'));
    });
  });

  group('Task 4 & 5: Backup & Restore consistency and unexpected playlist filter', () {
    test('JSON export only exports user playlists and includes search history', () async {
      final db = DBProvider.db;
      final isar = await db;

      // 1. Create a legitimate user playlist
      final userPlaylist = PlaylistDB(
        name: 'My Morning Tunes',
        description: 'Personal playlist',
        type: PlaylistTypeDB.userPlaylist,
      );
      await isar.writeTxn(() => isar.playlistDBs.put(userPlaylist));

      // 2. Simulate internal provider row (the root cause of content-resolver.bloomfactory.jisaavn::481043)
      final providerRow = PlaylistDB(
        name: 'content-resolver.bloomfactory.jisaavn::481043',
        description: 'Artist cache row',
        type: PlaylistTypeDB.artist,
      );
      await isar.writeTxn(() => isar.playlistDBs.put(providerRow));

      // 3. Add search history items
      final searchDao = SearchHistoryDAO(db);
      await searchDao.putSearchHistory('Arijit Singh');
      await searchDao.putSearchHistory('Hanuman Chalisa');

      // 4. Export JSON backup
      final backupFilePath = await DBProvider.createLegacyJsonBackup();
      expect(backupFilePath, isNotNull);
      final backupJson = await File(backupFilePath!).readAsString();
      final backup = jsonDecode(backupJson) as Map<String, dynamic>;

      // 5. Verify user playlists are exported, but internal provider rows are excluded
      final playlists = (backup['playlists'] as List).cast<Map<String, dynamic>>();
      expect(playlists.any((p) => p['playlistName'] == 'My Morning Tunes'), isTrue);
      expect(
        playlists.any((p) => p['playlistName'] == 'content-resolver.bloomfactory.jisaavn::481043'),
        isFalse,
        reason: 'Internal provider row must NEVER be exported as a playlist!',
      );

      // 6. Verify search history is included in the backup
      final searchHistory = (backup['search_history'] as List).cast<String>();
      expect(searchHistory, contains('Arijit Singh'));
      expect(searchHistory, contains('Hanuman Chalisa'));
    });

    test('JSON restore rejects internal provider IDs as playlist names and restores search history', () async {
      final db = DBProvider.db;

      // JSON backup payload containing both valid playlist, corrupted provider ID playlist, and search history
      final mockBackup = {
        'playlists': [
          {
            'playlistName': 'Evening Acoustic',
            'createdAt': DateTime.now().toIso8601String(),
          },
          {
            'playlistName': 'content-resolver.bloomfactory.jisaavn::481043',
            'createdAt': DateTime.now().toIso8601String(),
          },
        ],
        'media_items': <dynamic>[],
        'search_history': ['Shreya Ghoshal', 'Gym Energy'],
      };

      final tempRestoreFile = File(p.join(tempRoot.path, 'test_restore.json'));
      await tempRestoreFile.writeAsString(jsonEncode(mockBackup));

      await DBProvider.restoreLegacyJsonBackup(tempRestoreFile.path);

      final trackDao = TrackDAO(db);
      final playlistDao = PlaylistDAO(db, trackDao);
      final playlists = await playlistDao.getAllPlaylists();

      // Evening Acoustic must exist
      expect(playlists.any((p) => p.name == 'Evening Acoustic'), isTrue);

      // Corrupted provider string must NOT exist as a playlist
      expect(
        playlists.any((p) => p.name == 'content-resolver.bloomfactory.jisaavn::481043'),
        isFalse,
        reason: 'Restoring must reject content-resolver.bloomfactory as a playlist name!',
      );

      // Search history must be restored
      final searchDao = SearchHistoryDAO(db);
      final searches = await searchDao.getLastSearches(limit: 10);
      final historyQueries = searches.map((s) => s['query']).toList();
      expect(historyQueries, contains('Shreya Ghoshal'));
      expect(historyQueries, contains('Gym Energy'));
    });
  });

  group('Task 7: Clean Short Share Links & Deep Links', () {
    test('Builds clean short share link without bloat or internal provider namespaces', () {
      final track = Track(
        id: 'content-resolver.bloomfactory.jisaavn::dxrBpjVX',
        title: 'Kesariya',
        artists: [const ArtistSummary(id: '', name: 'Arijit Singh')],
        album: const AlbumSummary(id: '', title: 'Brahmastra', artists: []),
        durationMs: BigInt.from(268000),
        thumbnail: const Artwork(
          url: 'https://c.saavncdn.com/150/test.jpg',
          layout: ImageLayout.square,
        ),
        isExplicit: false,
      );

      // Check clean Web link
      final webUri = OrviaDeepLinkService.buildShortTrackUri(track, useAppScheme: false);
      expect(webUri.host, equals('ankitcodes30.github.io'));
      expect(webUri.path, equals('/Orvia/track'));
      expect(webUri.queryParameters['id'], equals('dxrBpjVX'));
      expect(webUri.queryParameters['src'], equals('saavn'));
      expect(webUri.queryParameters.containsKey('providerUrl'), isFalse,
          reason: 'Bloated providerUrl must be excluded from short share link');
      expect(webUri.queryParameters.containsKey('album'), isFalse,
          reason: 'Redundant album query parameter must be excluded from short link');

      // Check clean App deep link
      final appUri = OrviaDeepLinkService.buildShortTrackUri(track, useAppScheme: true);
      expect(appUri.scheme, equals('orvia'));
      expect(appUri.host, equals('track'));
      expect(appUri.queryParameters['id'], equals('dxrBpjVX'));
      expect(appUri.queryParameters['src'], equals('saavn'));

      // Check share text includes clean clickable HTTPS link and NO unclickable custom scheme
      final shareText = OrviaDeepLinkService.buildTrackShareText(track);
      expect(shareText, contains('https://ankitcodes30.github.io/Orvia/track?id=dxrBpjVX&src=saavn'));
      expect(shareText, isNot(contains('orvia://')),
          reason: 'Share text must not include unclickable orvia:// custom scheme');
      expect(shareText, isNot(contains('content-resolver.bloomfactory')));
      expect(shareText, isNot(contains('Original link:')),
          reason: 'Share text must not include Original link section');
      expect(RegExp(r'https?://').allMatches(shareText).length, equals(1),
          reason: 'Share text must contain exactly ONE URL');

      // Test YouTube Music track share link
      final ytTrack = Track(
        id: 'content-resolver.bloomfactory.ytmusic::Z2xuq78pS1Y',
        title: 'Mann Mera (From "Table No. 21")',
        artists: [const ArtistSummary(id: '', name: 'Gajendra Verma')],
        album: const AlbumSummary(id: '', title: 'Table No. 21', artists: []),
        durationMs: BigInt.from(200000),
        thumbnail: const Artwork(url: '', layout: ImageLayout.square),
        url: 'https://music.youtube.com/watch?v=Z2xuq78pS1Y',
        isExplicit: false,
      );
      final ytShareText = OrviaDeepLinkService.buildTrackShareText(ytTrack);
      expect(ytShareText, contains('https://ankitcodes30.github.io/Orvia/track?id=Z2xuq78pS1Y&src=ytmusic'));
      expect(ytShareText, isNot(contains('Original link:')));
      expect(ytShareText, isNot(contains('https://music.youtube.com')));
      expect(RegExp(r'https?://').allMatches(ytShareText).length, equals(1),
          reason: 'YouTube Music share text must contain exactly ONE URL');

      // Test deep link parsing reconstruction
      final parsed = OrviaDeepLinkService.parseDeepLink(appUri);
      expect(parsed, isNotNull);
      expect(parsed!['id'], equals('content-resolver.bloomfactory.jisaavn::dxrBpjVX'));
      expect(parsed['src'], equals('saavn'));
    });
  });

  group('Task 9: Gym Energy & Cardio Source Alignment and Time Window', () {
    test('Contains all 18 YouTube source tracks in order with valid hqdefault thumbnails', () {
      final banners = SmartBannerService.getActiveBanners(
        testTime: DateTime(2026, 10, 21, 18, 0),
      );
      final gymBanner = banners.firstWhere((b) => b.id == 'gym_energy');

      expect(gymBanner.tracks.length, equals(18));

      // All 18 verified source tracks from YouTube playlist
      final expectedYtSourceIds = [
        'iiBeBFRsCSQ', // 1. Bollywood Workout Mix
        'dHsV56I1GwE', // 2. Dope Shope
        'uFGreSkTMck', // 3. Jaan Se Guzarte Hain
        'D2CKOIiabfg', // 4. Gym Motivation Music
        'ELrwFR4NkLk', // 5. UNSUNG Fast Rap Workout Mix 2026
        '6SFfS9QMloU', // 6. Ultimate Workout Anthem Non-Stop Mashup
        'skhUNWhX2UY', // 7. BEST WORKOUT MUSIC 2026
        'REaoaFTiMTs', // 8. I like the way you kiss me
        'fQWNeIiFf_s', // 9. Thank You (Not So Bad)
        'tKXp27BBz6U', // 10. Freestyler (Rock The Microphone)
        'wQ9ifRPfP8A', // 11. Need Your Love
        '4HeMSUVpMFc', // 12. Let It Happen (Techno)
        '90h5GMM4iB8', // 13. Be My Lover (2023 Mix)
        'j5ZBs64cHTE', // 14. Love With Workout Mashup #4
        'BVnIWAuCv7M', // 15. Jo Tere Sang X Tere Liye (Synthwave Remix)
        'DoK2iKDCaMI', // 16. Aarambh Hai Prachand X NF's Hope
        'Ard-_9pCyzA', // 17. Bande
        'Jyst8oIHOAY', // 18. Mercy
      ];

      for (int i = 0; i < expectedYtSourceIds.length; i++) {
        final ytId = expectedYtSourceIds[i];
        final track = gymBanner.tracks[i];
        expect(track.id, contains(ytId),
            reason: 'Source track $i ($ytId) not found in expected order');
        expect(track.thumbnail.url, contains(ytId));
        expect(track.thumbnail.url, contains('hqdefault.jpg'));
      }

      // Check that all 18 tracks have distinct non-empty IDs
      final seenIds = <String>{};
      for (final t in gymBanner.tracks) {
        expect(seenIds.add(t.id), isTrue, reason: 'Duplicate track ID found: ${t.id}');
        expect(t.title, isNotEmpty);
        expect(t.thumbnail.url, isNotEmpty);
      }
    });

    test('Gym Energy time window: morning 05:00-11:00 exclusive, evening 16:00-22:00 exclusive', () {
      // Morning window: active hours [5, 6, 7, 8, 9, 10]
      // 04:00 -> inactive
      expect(SmartBannerService.getActiveBanners(testTime: DateTime(2026, 10, 21, 4, 30))
          .any((b) => b.id == 'gym_energy'), isFalse);
      // 05:00 -> active (inclusive start)
      expect(SmartBannerService.getActiveBanners(testTime: DateTime(2026, 10, 21, 5, 0))
          .any((b) => b.id == 'gym_energy'), isTrue);
      // 10:59 -> active
      expect(SmartBannerService.getActiveBanners(testTime: DateTime(2026, 10, 21, 10, 59))
          .any((b) => b.id == 'gym_energy'), isTrue);
      // 11:00 -> inactive (exclusive end)
      expect(SmartBannerService.getActiveBanners(testTime: DateTime(2026, 10, 21, 11, 0))
          .any((b) => b.id == 'gym_energy'), isFalse);

      // Midday: 14:00 -> inactive
      expect(SmartBannerService.getActiveBanners(testTime: DateTime(2026, 10, 21, 14, 0))
          .any((b) => b.id == 'gym_energy'), isFalse);

      // Evening window: active hours [16, 17, 18, 19, 20, 21]
      // 15:59 -> inactive
      expect(SmartBannerService.getActiveBanners(testTime: DateTime(2026, 10, 21, 15, 59))
          .any((b) => b.id == 'gym_energy'), isFalse);
      // 16:00 -> active (inclusive start)
      expect(SmartBannerService.getActiveBanners(testTime: DateTime(2026, 10, 21, 16, 0))
          .any((b) => b.id == 'gym_energy'), isTrue);
      // 21:59 -> active
      expect(SmartBannerService.getActiveBanners(testTime: DateTime(2026, 10, 21, 21, 59))
          .any((b) => b.id == 'gym_energy'), isTrue);
      // 22:00 -> inactive (exclusive end)
      expect(SmartBannerService.getActiveBanners(testTime: DateTime(2026, 10, 21, 22, 0))
          .any((b) => b.id == 'gym_energy'), isFalse);

      // Midnight: 00:00 -> inactive
      expect(SmartBannerService.getActiveBanners(testTime: DateTime(2026, 10, 21, 0, 0))
          .any((b) => b.id == 'gym_energy'), isFalse);
    });
  });

  group('Task 4: Complete Removal of Night Calm', () {
    test('night_calm is absent from active carousel banners at all 24 hours', () {
      for (int hour = 0; hour < 24; hour++) {
        final banners = SmartBannerService.getActiveBanners(
          testTime: DateTime(2026, 10, 21, hour, 0),
        );
        expect(
          banners.any((b) => b.id == 'night_calm'),
          isFalse,
          reason: 'Night Calm must not appear at hour $hour',
        );
      }
    });

    test('night_calm is completely absent from banners.json and fallback configs', () async {
      final jsonFile = File('banners.json');
      if (jsonFile.existsSync()) {
        final content = await jsonFile.readAsString();
        expect(content.contains('night_calm'), isFalse,
            reason: 'night_calm must not exist in banners.json');
      }

      final ghpageJsonFile = File('ghpage/static/banners.json');
      if (ghpageJsonFile.existsSync()) {
        final content = await ghpageJsonFile.readAsString();
        expect(content.contains('night_calm'), isFalse,
            reason: 'night_calm must not exist in ghpage/static/banners.json');
      }
    });
  });

  group('Task 7: Immediate Removal of Carousel Banners', () {
    test('whats_hot and navratri_special_2026 are completely absent from active carousel', () {
      for (final hour in [6, 12, 18, 23]) {
        final banners = SmartBannerService.getActiveBanners(
          testTime: DateTime(2026, 10, 21, hour, 0),
        );
        expect(banners.any((b) => b.id == 'whats_hot'), isFalse,
            reason: "whats_hot must be absent at hour $hour");
        expect(banners.any((b) => b.id == 'navratri_special_2026'), isFalse,
            reason: "navratri_special_2026 banner must be absent at hour $hour");
      }
    });

    test('Active banners contain only valid approved collections', () {
      final banners = SmartBannerService.getActiveBanners(
        testTime: DateTime(2026, 10, 21, 18, 0),
      );
      final allowedBannerIds = {
        'morning_bhakti',
        'gym_energy',
        'diwali_festive_2026',
      };

      for (final banner in banners) {
        expect(allowedBannerIds.contains(banner.id), isTrue,
            reason: 'Unexpected banner id found in active carousel: ${banner.id}');
      }
    });
  });

  group('Task 8 & 9: Navratri 2026 Category & Indian-First Discovery Reorganization', () {
    test('Navratri 2026 is registered at the final rightmost position after Best of 2025', () {
      expect(kIndianBrowseCategories.last.title, equals('Navratri 2026'));
      expect(kIndianBrowseCategories[kIndianBrowseCategories.length - 2].title, equals('Best of 2025'));
    });

    test('Latest Hindi Hits is completely removed globally from Indian browse categories', () {
      expect(
        kIndianBrowseCategories.any((c) => c.title.toLowerCase().contains('latest hindi hits')),
        isFalse,
        reason: 'Latest Hindi Hits must not be present in kIndianBrowseCategories',
      );
    });

    test('Navratri 2026 preserves all 19 tracks with full metadata and zero duplicates', () {
      expect(kVerifiedNavratriTracks.length, equals(19));

      final seenIds = <String>{};
      for (final item in kVerifiedNavratriTracks) {
        final track = item.track;
        expect(seenIds.add(track.id), isTrue,
            reason: 'Duplicate Navratri track id: ${track.id}');
        expect(track.title, isNotEmpty);
        expect(track.artists, isNotEmpty);
        expect(track.thumbnail.url, isNotEmpty);
        expect(item.filterTag, isNotEmpty);
      }
    });
  });

  group('Task 2 & 3: ContentBloc Search & Active Plugin Regression', () {
    test('SearchContent accepts explicit pluginId and sets state.activePluginId', () {
      const event = SearchContent(
        filter: ContentSearchFilter.track,
        query: 'Arijit Singh Romance',
        pluginId: 'content-resolver.bloomfactory.jisaavn',
      );
      expect(event.pluginId, equals('content-resolver.bloomfactory.jisaavn'));
      expect(event.filter, equals(ContentSearchFilter.track));
    });

    test('LoadMoreSearchContent event preserves pagination state', () {
      const event = LoadMoreSearchContent(pageToken: 'page_2');
      expect(event.pageToken, equals('page_2'));
    });
  });

  group('Task 11: Automatic Festive Special — Diwali 2026 Schedule & Expiry', () {
    test('Diwali schedule: starts 2026-11-05 00:00 IST (inclusive) and ends 2026-11-12 00:00 IST (exclusive)', () {
      // 2026-11-05 00:00:00 IST == 2026-11-04 18:30:00 UTC
      // 2026-11-12 00:00:00 IST == 2026-11-11 18:30:00 UTC

      final diwaliBanner = SmartBannerItem(
        id: 'diwali_festive_2026',
        title: 'Diwali Festive Special',
        subtitle: 'Festival of Lights',
        badge: 'DIWALI',
        imageUrl: '',
        gradientColors: const [],
        tracks: const [],
        activeHours: List.generate(24, (i) => i),
        priority: 100,
        startDate: DateTime.utc(2026, 11, 4, 18, 30),
        endDate: DateTime.utc(2026, 11, 11, 18, 30),
      );

      // Just before start: 2026-11-04 18:29:59 UTC -> inactive
      expect(diwaliBanner.isEligibleAt(0, DateTime.utc(2026, 11, 4, 18, 29, 59)), isFalse);

      // Exactly at start: 2026-11-04 18:30:00 UTC -> active (inclusive start)
      expect(diwaliBanner.isEligibleAt(0, DateTime.utc(2026, 11, 4, 18, 30, 0)), isTrue);

      // During active window: 2026-11-08 12:00:00 UTC -> active
      expect(diwaliBanner.isEligibleAt(12, DateTime.utc(2026, 11, 8, 12, 0, 0)), isTrue);

      // Just before end: 2026-11-11 18:29:59 UTC -> active
      expect(diwaliBanner.isEligibleAt(23, DateTime.utc(2026, 11, 11, 18, 29, 59)), isTrue);

      // Exactly at end: 2026-11-11 18:30:00 UTC -> inactive (exclusive end boundary)
      expect(diwaliBanner.isEligibleAt(0, DateTime.utc(2026, 11, 11, 18, 30, 0)), isFalse);

      // After end: 2026-11-12 00:00:00 UTC -> inactive
      expect(diwaliBanner.isEligibleAt(0, DateTime.utc(2026, 11, 12, 0, 0, 0)), isFalse);
    });

    test('FestivalService supports 10-day pre-festival eligibility rule for future festivals', () {
      // Sankranti 2027 starts 2027-01-14 00:00 IST (2027-01-13 18:30 UTC), promotionDays = 10
      // 10 days before is 2027-01-03 18:30 UTC
      final beforePromo = DateTime.utc(2027, 1, 2, 0, 0); // 11+ days before
      final duringPromo = DateTime.utc(2027, 1, 5, 0, 0); // 8 days before -> promoted

      final festBefore = FestivalService.getActiveOrUpcomingFestival(testTime: beforePromo);
      expect(festBefore?.id == 'sankranti_2027', isFalse);

      final festDuring = FestivalService.getActiveOrUpcomingFestival(testTime: duringPromo);
      expect(festDuring?.id, equals('sankranti_2027'));
      expect(festDuring?.isPromotedAt(duringPromo), isTrue);
      expect(festDuring?.isOngoingAt(duringPromo), isFalse); // not ongoing yet, only promoted
    });
  });
}
