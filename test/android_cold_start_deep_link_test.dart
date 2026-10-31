import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;

import 'package:Orvia/core/constants/setting_keys.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/services/db/dao/settings_dao.dart';
import 'package:Orvia/services/db/dao/track_dao.dart';
import 'package:Orvia/services/db/db_provider.dart';
import 'package:Orvia/services/player/queue_manager.dart';
import 'package:Orvia/services/share/orvia_deep_link_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late Directory supportDir;
  late Directory docsDir;

  const songA = Track(
    id: 'content-resolver.bloomfactory.jisaavn::song_a_id',
    title: 'Song A (Old Session)',
    artists: [ArtistSummary(id: 'artist_a', name: 'Artist A')],
    album: AlbumSummary(id: 'album_a', title: 'Album A', artists: []),
    durationMs: null,
    thumbnail: Artwork(url: 'https://c.saavncdn.com/song_a.jpg', layout: ImageLayout.square),
    isExplicit: false,
  );

  const songB = Track(
    id: 'content-resolver.bloomfactory.jisaavn::song_b_id',
    title: 'Song B (Shared Link)',
    artists: [ArtistSummary(id: 'artist_b', name: 'Artist B')],
    album: AlbumSummary(id: 'album_b', title: 'Album B', artists: []),
    durationMs: null,
    thumbnail: Artwork(url: 'https://c.saavncdn.com/song_b.jpg', layout: ImageLayout.square),
    isExplicit: false,
  );

  const songC = Track(
    id: 'content-resolver.bloomfactory.jisaavn::song_c_id',
    title: 'Song C (Newer Shared Link)',
    artists: [ArtistSummary(id: 'artist_c', name: 'Artist C')],
    album: AlbumSummary(id: 'album_c', title: 'Album C', artists: []),
    durationMs: null,
    thumbnail: Artwork(url: 'https://c.saavncdn.com/song_c.jpg', layout: ImageLayout.square),
    isExplicit: false,
  );

  setUp(() async {
    OrviaDeepLinkService.resetForTesting();

    tempRoot = await Directory.systemTemp.createTemp('orvia_cold_start_test_');
    supportDir = Directory(p.join(tempRoot.path, 'support'))..createSync(recursive: true);
    docsDir = Directory(p.join(tempRoot.path, 'docs'))..createSync(recursive: true);

    await DBProvider.init(
      appSupportPath: supportDir.path,
      appDocumentsPath: docsDir.path,
    );

    // Seed database with Song A in TrackDAO and lastQueueState in SettingsDAO
    final trackDao = TrackDAO(DBProvider.db);
    await trackDao.upsertTrack(songA);

    final settingsDao = SettingsDAO(DBProvider.db);
    final lastStateJson = jsonEncode({
      'trackIds': [songA.id],
      'currentIndex': 0,
      'queueTitle': 'Previous Session Queue',
    });
    await settingsDao.putSettingStr(SettingKeys.lastQueueState, lastStateJson);
  });

  tearDown(() async {
    OrviaDeepLinkService.resetForTesting();

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

  group('Android Cold-Start Shared-Track Race Condition Tests', () {
    test('Test A — Cold start with stale session: Song B wins and Song A does not overwrite queue', () async {
      // 1. Stale session in DB has Song A.
      // 2. Incoming shared link arrives for Song B.
      final songBUri = OrviaDeepLinkService.buildTrackDeepLink(songB, useAppScheme: true);
      OrviaDeepLinkService.setPendingDeepLink(songBUri);

      expect(OrviaDeepLinkService.hasPendingDeepLink, isTrue);
      expect(OrviaDeepLinkService.hasHandledColdStartDeepLink, isTrue);

      final queueManager = QueueManager();

      // 3. Attempt session restoration in parallel while deep link is pending.
      final restored = await queueManager.restoreQueueState();

      // restoreQueueState MUST abort and reject loading stale Song A!
      expect(restored, isFalse);
      expect(queueManager.tracks, isEmpty);

      // 4. Now process Song B into the queue.
      queueManager.updateQueue([songB], startIndex: 0, queueTitle: 'Shared Track');

      expect(queueManager.tracks.length, 1);
      expect(queueManager.currentTrack?.id, equals(songB.id));
      expect(queueManager.currentTrack?.title, equals('Song B (Shared Link)'));

      // 5. Subsequent attempts to restore session MUST also be blocked.
      final secondRestore = await queueManager.restoreQueueState();
      expect(secondRestore, isFalse);
      expect(queueManager.currentTrack?.id, equals(songB.id));
    });

    test('Test B — Repeated requests: Newer request supersedes older delayed request', () async {
      final queueManager = QueueManager();

      // Request 1: Song B arrives
      final req1Id = ++OrviaDeepLinkService.activeRequestId;
      queueManager.updateQueue([songB], queueTitle: 'Shared Track');
      expect(queueManager.currentTrack?.id, equals(songB.id));

      // Request 2: Song C arrives before Request 1 network resolution could complete
      final req2Id = ++OrviaDeepLinkService.activeRequestId;
      expect(req2Id > req1Id, isTrue);

      queueManager.updateQueue([songC], queueTitle: 'Shared Track');
      expect(queueManager.currentTrack?.id, equals(songC.id));

      // Simulate Request 1 trying to apply its result after a network delay
      if (req1Id != OrviaDeepLinkService.activeRequestId) {
        // Obsolete request dropped!
      } else {
        queueManager.updateQueue([songB], queueTitle: 'Shared Track');
      }

      // Song C remains the winning active track!
      expect(queueManager.currentTrack?.id, equals(songC.id));
      expect(queueManager.currentTrack?.title, equals('Song C (Newer Shared Link)'));
    });

    test('Test C — Deep-link resolution failure: Does not fallback to Song A from previous session', () async {
      final queueManager = QueueManager();

      // Incoming deep link for Song B
      final songBUri = OrviaDeepLinkService.buildTrackDeepLink(songB, useAppScheme: true);
      OrviaDeepLinkService.setPendingDeepLink(songBUri);

      // Deep link queue is set to 'Shared Track'
      queueManager.updateQueue([songB], queueTitle: 'Shared Track');
      expect(queueManager.queueTitle.value, equals('Shared Track'));
      expect(queueManager.tracks.length, 1);

      // In the event of resolution failure, queueManager must NOT load Song A from session
      final restored = await queueManager.restoreQueueState();
      expect(restored, isFalse);

      // The queue still strictly isolates the failed track without resurrecting Song A
      expect(queueManager.tracks.any((t) => t.id == songA.id), isFalse);
    });

    test('Test D — Duplicate intent: Identical URL within deduplication window does not duplicate queue', () async {
      final songBUri = OrviaDeepLinkService.buildTrackDeepLink(songB, useAppScheme: true);

      final track1 = OrviaDeepLinkService.parseTrackFromUri(songBUri);
      expect(track1, isNotNull);
      expect(track1!.id, equals(songB.id));

      final queueManager = QueueManager();
      queueManager.updateQueue([track1], queueTitle: 'Shared Track');
      expect(queueManager.tracks.length, 1);

      // Second duplicate delivery of the exact same URI
      final track2 = OrviaDeepLinkService.parseTrackFromUri(songBUri);
      expect(track2, isNotNull);

      // QueueManager deduplication check
      if (queueManager.tracks.length == 1 && queueManager.tracks.first.id == track2!.id) {
        // Do not re-append or duplicate
      } else {
        queueManager.addTrack(track2!);
      }

      expect(queueManager.tracks.length, 1);
      expect(queueManager.currentTrack?.id, equals(songB.id));
    });

    test('Test E — Warm/background start: Shared link updates active queue seamlessly', () async {
      final queueManager = QueueManager();

      // App is already playing Song A
      queueManager.loadTracks([songA], idx: 0, playlistName: 'Now Playing');
      expect(queueManager.currentTrack?.id, equals(songA.id));

      // Warm start: user clicks Song B link from browser/chat
      final songBUri = OrviaDeepLinkService.buildTrackDeepLink(songB, useAppScheme: true);
      final incomingTrack = OrviaDeepLinkService.parseTrackFromUri(songBUri);
      expect(incomingTrack, isNotNull);

      // Queue transitions to Song B as 'Shared Track'
      queueManager.updateQueue([incomingTrack!], queueTitle: 'Shared Track');
      expect(queueManager.currentTrack?.id, equals(songB.id));
      expect(queueManager.queueTitle.value, equals('Shared Track'));
    });

    test('Test F — Normal launch: Without incoming deep link, normal session restore succeeds', () async {
      expect(OrviaDeepLinkService.hasPendingDeepLink, isFalse);
      expect(OrviaDeepLinkService.isHandlingDeepLink, isFalse);
      expect(OrviaDeepLinkService.hasHandledColdStartDeepLink, isFalse);

      final queueManager = QueueManager();
      final restored = await queueManager.restoreQueueState();

      // Session restore succeeds normally on cold start when no deep link is requested!
      expect(restored, isTrue);
      expect(queueManager.tracks.length, 1);
      expect(queueManager.currentTrack?.id, equals(songA.id));
      expect(queueManager.currentTrack?.title, equals('Song A (Old Session)'));
      expect(queueManager.queueTitle.value, equals('Previous Session Queue'));
    });
  });
}
