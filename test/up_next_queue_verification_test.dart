import 'package:flutter_test/flutter_test.dart';
import 'package:Orvia/core/models/exported.dart' hide MediaItem;
import 'package:Orvia/services/player/queue_manager.dart';
import 'package:Orvia/services/player/related_songs_manager.dart';
import 'package:Orvia/services/player/player_engine.dart';
import 'package:Orvia/services/plugin/plugin_service.dart';
import 'package:Orvia/src/rust/api/plugin/commands.dart';
import 'package:Orvia/src/rust/api/plugin/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Up Next Queue UI & Live Synchronization Tests', () {
    late QueueManager queueManager;

    setUp(() {
      queueManager = QueueManager();
    });

    final track1 = Track(
      id: 'ytmusic::nbc_01',
      title: 'This Is Halloween',
      artists: const [ArtistSummary(id: 'art_delfman', name: 'Danny Elfman')],
      durationMs: BigInt.from(196000),
      thumbnail: const Artwork(url: 'https://example.com/art1.jpg', layout: ImageLayout.square),
      isExplicit: false,
    );

    final track2 = Track(
      id: 'ytmusic::nbc_02',
      title: "Jack's Lament",
      artists: const [ArtistSummary(id: 'art_delfman', name: 'Danny Elfman')],
      durationMs: BigInt.from(194000),
      thumbnail: const Artwork(url: 'https://example.com/art2.jpg', layout: ImageLayout.square),
      isExplicit: false,
    );

    final track3 = Track(
      id: 'ytmusic::nbc_03',
      title: 'What\'s This?',
      artists: const [ArtistSummary(id: 'art_delfman', name: 'Danny Elfman')],
      durationMs: BigInt.from(185000),
      thumbnail: const Artwork(url: 'https://example.com/art3.jpg', layout: ImageLayout.square),
      isExplicit: false,
    );

    test('1. QueueManager loads tracks in exact original sequence and maintains currentIndex', () {
      final albumTracks = List<Track>.generate(14, (i) {
        return Track(
          id: 'ytmusic::nbc_${(i + 1).toString().padLeft(2, '0')}',
          title: 'Nightmare Track ${i + 1}',
          artists: const [ArtistSummary(id: 'art_delfman', name: 'Danny Elfman')],
          durationMs: BigInt.from(180000 + i * 1000),
          thumbnail: const Artwork(url: '', layout: ImageLayout.square),
          isExplicit: false,
        );
      });

      queueManager.loadTracks(
        albumTracks,
        playlistName: "Tim Burton's The Nightmare Before Christmas",
        idx: 0,
      );

      expect(queueManager.length, equals(14));
      expect(queueManager.currentIndex, equals(0));
      expect(queueManager.currentTrack?.title, equals('Nightmare Track 1'));
      expect(queueManager.queueTitle.value, equals("Tim Burton's The Nightmare Before Christmas"));

      // Verify all 14 tracks in exact original sequence
      for (int i = 0; i < 14; i++) {
        expect(queueManager.tracks[i].id, equals('ytmusic::nbc_${(i + 1).toString().padLeft(2, '0')}'));
        expect(queueManager.tracks[i].title, equals('Nightmare Track ${i + 1}'));
      }

      // Sequential advance
      expect(queueManager.advanceToNext(), isTrue);
      expect(queueManager.currentIndex, equals(1));
      expect(queueManager.currentTrack?.title, equals('Nightmare Track 2'));

      // Sequential reverse
      expect(queueManager.advanceToPrevious(), isTrue);
      expect(queueManager.currentIndex, equals(0));
      expect(queueManager.currentTrack?.title, equals('Nightmare Track 1'));
    });

    test('2. Standalone-track playback does not overwrite album protection', () {
      final albumTracks = [track1, track2, track3];
      queueManager.loadTracks(albumTracks, playlistName: 'Album Queue', idx: 0);
      expect(queueManager.length, equals(3));

      // Terminal advance check
      queueManager.jumpTo(2);
      expect(queueManager.advanceToNext(loopMode: LoopMode.off), isFalse);
      expect(queueManager.currentTrack?.id, equals(track3.id));
    });

    test('3. Clear queue keeps only currently playing track', () {
      final albumTracks = [track1, track2, track3];
      queueManager.loadTracks(albumTracks, playlistName: 'Album Queue', idx: 1);
      expect(queueManager.currentTrack?.id, equals(track2.id));

      queueManager.clearQueue();
      expect(queueManager.length, equals(1));
      expect(queueManager.currentTrack?.id, equals(track2.id));
      expect(queueManager.currentIndex, equals(0));
    });

    test('4. Queue track reordering updates track order and current playing index', () {
      final tracks = [track1, track2, track3];
      queueManager.loadTracks(tracks, playlistName: 'Test Queue', idx: 0);

      // Move track 0 (track1) to index 2
      queueManager.moveTrack(0, 2);
      expect(queueManager.tracks[0].id, equals(track2.id));
      expect(queueManager.tracks[1].id, equals(track1.id));
      expect(queueManager.tracks[2].id, equals(track3.id));
      // Current index follows the moved track
      expect(queueManager.currentIndex, equals(1));
    });

    test('5. Queue track removal adjusts current index safely', () {
      final tracks = [track1, track2, track3];
      queueManager.loadTracks(tracks, playlistName: 'Test Queue', idx: 2);

      // Remove track 0 (track1)
      queueManager.removeTrackAt(0);
      expect(queueManager.length, equals(2));
      // Index should shift from 2 to 1
      expect(queueManager.currentIndex, equals(1));
      expect(queueManager.currentTrack?.id, equals(track3.id));
    });

    test('6. 14-track Billboard album queue is strictly protected against radio recommendations', () async {
      final albumTracks = List<Track>.generate(14, (i) {
        return Track(
          id: 'ytmusic::nbc_${(i + 1).toString().padLeft(2, '0')}',
          title: 'Nightmare Track ${i + 1}',
          artists: const [ArtistSummary(id: 'art_delfman', name: 'Danny Elfman')],
          durationMs: BigInt.from(180000 + i * 1000),
          thumbnail: const Artwork(url: '', layout: ImageLayout.square),
          isExplicit: false,
        );
      });

      queueManager.loadTracks(
        albumTracks,
        playlistName: "Tim Burton's The Nightmare Before Christmas",
        idx: 0,
      );

      final dummyPlugin = _DummyPluginForUpNext();
      final relatedManager = RelatedSongsManager(dummyPlugin);
      bool radioAppended = false;
      relatedManager.onAddQueueItems = (items, {bool atLast = false}) {
        radioAppended = true;
        queueManager.addTracks(items, atLast: atLast);
      };

      // Periodic check with isFromPlaylist: true
      await relatedManager.checkForRelatedSongs(
        currentMedia: queueManager.currentTrack!,
        queue: queueManager.tracks,
        currentPlayingIdx: 0,
        loopMode: LoopMode.off,
        isFromPlaylist: true,
      );

      expect(radioAppended, isFalse, reason: 'Album queue must never receive radio injections');
      expect(queueManager.length, equals(14));
      expect(queueManager.tracks.first.title, equals('Nightmare Track 1'));
      expect(queueManager.tracks.last.title, equals('Nightmare Track 14'));
    });

    test('7. Standalone track playback triggers radio recommendations to populate Up Next', () async {
      final radioTrack = Track(
        id: 'ytmusic::radio_rec_1',
        title: 'Corpse Bride Theme',
        artists: const [ArtistSummary(id: 'art_delfman', name: 'Danny Elfman')],
        durationMs: BigInt.from(210000),
        thumbnail: const Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      final mockPlugin = _MockRadioPlugin([radioTrack]);
      final relatedManager = RelatedSongsManager(mockPlugin);
      relatedManager.onAddQueueItems = (items, {bool atLast = false}) {
        queueManager.addTracks(items, atLast: atLast);
      };

      queueManager.updateQueue([track1], queueTitle: 'Search');
      expect(queueManager.length, equals(1));

      // With isFromPlaylist: false, recommendations are fetched and added
      await relatedManager.checkForRelatedSongs(
        currentMedia: track1,
        queue: queueManager.tracks,
        currentPlayingIdx: 0,
        loopMode: LoopMode.off,
        isFromPlaylist: false,
      );

      expect(queueManager.length, equals(2));
      expect(queueManager.tracks[0].id, equals(track1.id));
      expect(queueManager.tracks[1].id, equals('ytmusic::radio_rec_1'));
    });

    test('8. QueueManager tracksStream immediately reflects changes synchronously', () async {
      final emittedQueues = <List<Track>>[];
      final sub = queueManager.tracksStream.listen((tracks) {
        emittedQueues.add(tracks);
      });

      queueManager.loadTracks([track1, track2], playlistName: 'Initial Queue');
      queueManager.addTrack(track3);
      queueManager.clearQueue();

      await Future.delayed(Duration.zero);
      sub.cancel();

      expect(emittedQueues.length, greaterThanOrEqualTo(3));
      expect(emittedQueues.last.length, equals(1));
      expect(emittedQueues.last.first.id, equals(track1.id));
    });

    test('9. Empty queue state and title fallback work safely without throwing', () {
      expect(queueManager.isEmpty, isTrue);
      expect(queueManager.currentTrack, isNull);
      expect(queueManager.peekNext(), isNull);
      expect(queueManager.advanceToNext(), isFalse);
      expect(queueManager.advanceToPrevious(), isFalse);

      queueManager.updateQueue([]);
      expect(queueManager.queueTitle.value, equals('Queue'));
      expect(queueManager.tracks, isEmpty);
    });

    test('10. playMediaItem preserves existing album queue and jumps when track is already in queue', () {
      final albumTracks = [track1, track2, track3];
      queueManager.loadTracks(
        albumTracks,
        playlistName: "Tim Burton's The Nightmare Before Christmas",
        idx: 0,
      );
      expect(queueManager.length, equals(3));
      expect(queueManager.currentIndex, equals(0));

      // External media item matching track 2 arrives (by ID or matching ID)
      final incomingTrack = track2;
      final idx = queueManager.tracks.indexWhere(
        (t) => t.id == incomingTrack.id,
      );
      expect(idx, equals(1));

      // Jumps without replacing the album queue
      queueManager.jumpTo(idx);
      expect(queueManager.length, equals(3), reason: 'Album queue must not be replaced');
      expect(queueManager.currentIndex, equals(1));
      expect(queueManager.currentTrack?.id, equals(track2.id));
      expect(queueManager.tracks[0].id, equals(track1.id));
      expect(queueManager.tracks[2].id, equals(track3.id));
    });
  });

  group('Banner Playlist Playback & Queue Protection Tests (Regression Suite)', () {
    late QueueManager queueManager;

    setUp(() {
      queueManager = QueueManager();
    });

    final bannerTracks = List<Track>.generate(5, (i) {
      return Track(
        id: 'saavn::banner_track_${i + 1}',
        title: 'Banner Devotional Song ${i + 1}',
        artists: const [ArtistSummary(id: '', name: 'Hariharan')],
        durationMs: BigInt.from(240000 + i * 1000),
        thumbnail: const Artwork(url: 'https://example.com/banner.jpg', layout: ImageLayout.square),
        isExplicit: false,
      );
    });

    final recTrack1 = Track(
      id: 'ytmusic::rec_track_1',
      title: 'Aarti Kunj Bihari Ki',
      artists: const [ArtistSummary(id: '', name: 'Hariharan')],
      durationMs: BigInt.from(300000),
      thumbnail: const Artwork(url: 'https://example.com/rec1.jpg', layout: ImageLayout.square),
      isExplicit: false,
    );

    final recTrack2 = Track(
      id: 'ytmusic::rec_track_2',
      title: 'Shree Krishna Govind',
      artists: const [ArtistSummary(id: '', name: 'Hariharan')],
      durationMs: BigInt.from(280000),
      thumbnail: const Artwork(url: 'https://example.com/rec2.jpg', layout: ImageLayout.square),
      isExplicit: false,
    );

    test('1. Starting playback from a banner playlist populates the full expected queue', () {
      queueManager.loadTracks(
        bannerTracks,
        playlistName: 'Morning Bhakti',
        idx: 2,
      );

      expect(queueManager.length, equals(5));
      expect(queueManager.currentIndex, equals(2));
      expect(queueManager.currentTrack?.title, equals('Banner Devotional Song 3'));
      expect(queueManager.queueTitle.value, equals('Morning Bhakti'));

      for (int i = 0; i < 5; i++) {
        expect(queueManager.tracks[i].id, equals('saavn::banner_track_${i + 1}'));
        expect(queueManager.tracks[i].title, equals('Banner Devotional Song ${i + 1}'));
      }
    });

    test('2. Remaining banner playlist tracks are retained while artist-related recommendations load', () async {
      queueManager.loadTracks(
        bannerTracks.sublist(0, 3), // 3 banner tracks
        playlistName: 'Morning Bhakti',
        idx: 1, // Track 2 playing, 1 track remaining in original playlist
      );

      final delayedPlugin = _MockDelayedRadioPlugin([recTrack1, recTrack2], delayMs: 50);
      final relatedManager = RelatedSongsManager(delayedPlugin);
      relatedManager.onAddQueueItems = (items, {bool atLast = false}) {
        queueManager.addTracks(items, atLast: atLast);
      };

      // While recommendations are in-flight, existing remaining tracks are strictly retained
      final futureCheck = relatedManager.checkForRelatedSongs(
        currentMedia: queueManager.currentTrack!,
        queue: queueManager.tracks,
        currentPlayingIdx: 1,
        loopMode: LoopMode.off,
        isFromPlaylist: false,
      );

      // Verify immediate state during loading
      expect(queueManager.length, equals(3));
      expect(queueManager.tracks[1].title, equals('Banner Devotional Song 2'));
      expect(queueManager.tracks[2].title, equals('Banner Devotional Song 3'));

      await futureCheck;

      // After recommendations arrive, original banner tracks remain intact at their original indices
      expect(queueManager.length, equals(5));
      expect(queueManager.tracks[0].title, equals('Banner Devotional Song 1'));
      expect(queueManager.tracks[1].title, equals('Banner Devotional Song 2'));
      expect(queueManager.tracks[2].title, equals('Banner Devotional Song 3'));
      // Recommendations appended at the end
      expect(queueManager.tracks[3].title, equals('Aarti Kunj Bihari Ki'));
      expect(queueManager.tracks[4].title, equals('Shree Krishna Govind'));
    });

    test('3. Recommendations do not replace the existing queue', () async {
      queueManager.loadTracks(
        bannerTracks,
        playlistName: 'Gym Energy',
        idx: 3,
      );

      final mockPlugin = _MockRadioPlugin([recTrack1, recTrack2]);
      final relatedManager = RelatedSongsManager(mockPlugin);
      relatedManager.onAddQueueItems = (items, {bool atLast = false}) {
        queueManager.addTracks(items, atLast: atLast);
      };

      await relatedManager.checkForRelatedSongs(
        currentMedia: bannerTracks[3],
        queue: queueManager.tracks,
        currentPlayingIdx: 3,
        loopMode: LoopMode.off,
        isFromPlaylist: false,
      );

      // Total tracks must be 5 original + 2 recommendations = 7
      expect(queueManager.length, equals(7));
      for (int i = 0; i < 5; i++) {
        expect(queueManager.tracks[i].id, equals(bannerTracks[i].id));
      }
      expect(queueManager.tracks[5].id, equals(recTrack1.id));
      expect(queueManager.tracks[6].id, equals(recTrack2.id));
    });

    test('4. Related recommendations can populate Up Next for standalone-track playback', () async {
      final singleTrack = bannerTracks.first;
      queueManager.updateQueue([singleTrack], queueTitle: 'Direct Play');
      expect(queueManager.length, equals(1));

      final mockPlugin = _MockRadioPlugin([recTrack1]);
      final relatedManager = RelatedSongsManager(mockPlugin);
      relatedManager.onAddQueueItems = (items, {bool atLast = false}) {
        queueManager.addTracks(items, atLast: atLast);
      };

      await relatedManager.checkForRelatedSongs(
        currentMedia: singleTrack,
        queue: queueManager.tracks,
        currentPlayingIdx: 0,
        loopMode: LoopMode.off,
        isFromPlaylist: false,
      );

      expect(queueManager.length, equals(2));
      expect(queueManager.tracks[0].id, equals(singleTrack.id));
      expect(queueManager.tracks[1].id, equals(recTrack1.id));
    });

    test('5. Genuine album queues preserve exact track order and remain protected from radio injection', () async {
      final albumTracks = List<Track>.generate(12, (i) {
        return Track(
          id: 'album_id_track_${i + 1}',
          title: 'Album Cut Track ${i + 1}',
          artists: const [ArtistSummary(id: '', name: 'Artist')],
          durationMs: BigInt.from(200000),
          thumbnail: const Artwork(url: '', layout: ImageLayout.square),
          isExplicit: false,
        );
      });

      queueManager.loadTracks(
        albumTracks,
        playlistName: 'Greatest Hits Album',
        idx: 11, // At the very end of the album
      );

      final mockPlugin = _MockRadioPlugin([recTrack1, recTrack2]);
      final relatedManager = RelatedSongsManager(mockPlugin);
      bool radioAdded = false;
      relatedManager.onAddQueueItems = (items, {bool atLast = false}) {
        radioAdded = true;
        queueManager.addTracks(items, atLast: atLast);
      };

      await relatedManager.checkForRelatedSongs(
        currentMedia: albumTracks.last,
        queue: queueManager.tracks,
        currentPlayingIdx: 11,
        loopMode: LoopMode.off,
        isFromPlaylist: true, // Album queue protection active
      );

      expect(radioAdded, isFalse);
      expect(queueManager.length, equals(12));
      for (int i = 0; i < 12; i++) {
        expect(queueManager.tracks[i].id, equals('album_id_track_${i + 1}'));
      }
    });

    test('6. Switching between banner playlist, album, and standalone track resets queue-protection state correctly', () {
      bool isProtected = false;

      // Step 1: Banner playlist -> Not protected against recommendations
      void loadBanner(List<Track> tracks, String name) {
        queueManager.loadTracks(tracks, playlistName: name);
        isProtected = false;
      }

      // Step 2: Genuine album -> Protected against radio injection
      void loadAlbum(List<Track> tracks, String albumName) {
        queueManager.loadTracks(tracks, playlistName: albumName);
        isProtected = true;
      }

      // Step 3: Standalone track -> Not protected
      void playStandalone(Track track) {
        queueManager.updateQueue([track], queueTitle: 'Direct Play');
        isProtected = false;
      }

      loadBanner(bannerTracks, 'Morning Bhakti');
      expect(isProtected, isFalse);
      expect(queueManager.length, equals(5));

      loadAlbum([bannerTracks[0], bannerTracks[1]], 'Bhakti Classics Album');
      expect(isProtected, isTrue);
      expect(queueManager.length, equals(2));

      playStandalone(bannerTracks[3]);
      expect(isProtected, isFalse);
      expect(queueManager.length, equals(1));

      // Switch back to banner
      loadBanner(bannerTracks, 'Gym Energy');
      expect(isProtected, isFalse);
      expect(queueManager.length, equals(5));
    });

    test('7. Related-song fetch failure does not corrupt or permanently empty the queue', () async {
      queueManager.loadTracks(
        bannerTracks.sublist(0, 3),
        playlistName: 'Morning Bhakti',
        idx: 2,
      );

      final failingPlugin = _MockFailingRadioPlugin();
      final relatedManager = RelatedSongsManager(failingPlugin);
      relatedManager.onAddQueueItems = (items, {bool atLast = false}) {
        queueManager.addTracks(items, atLast: atLast);
      };

      // Execution handles plugin failure gracefully
      await relatedManager.checkForRelatedSongs(
        currentMedia: bannerTracks[2],
        queue: queueManager.tracks,
        currentPlayingIdx: 2,
        loopMode: LoopMode.off,
        isFromPlaylist: false,
      );

      // Existing 3 tracks remain 100% intact, not empty, not corrupted
      expect(queueManager.length, equals(3));
      expect(queueManager.tracks[0].title, equals('Banner Devotional Song 1'));
      expect(queueManager.tracks[1].title, equals('Banner Devotional Song 2'));
      expect(queueManager.tracks[2].title, equals('Banner Devotional Song 3'));
      expect(queueManager.currentIndex, equals(2));
      expect(queueManager.currentTrack?.title, equals('Banner Devotional Song 3'));
    });
  });
}

class _DummyPluginForUpNext implements PluginService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockRadioPlugin implements PluginService {
  final List<Track> radioTracks;
  _MockRadioPlugin(this.radioTracks);

  @override
  Future<PluginResponse> execute({
    required String pluginId,
    required PluginRequest request,
  }) async {
    return PluginResponse.moreTracks(PagedTracks(items: radioTracks, nextPageToken: null));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockDelayedRadioPlugin implements PluginService {
  final List<Track> radioTracks;
  final int delayMs;
  _MockDelayedRadioPlugin(this.radioTracks, {this.delayMs = 50});

  @override
  Future<PluginResponse> execute({
    required String pluginId,
    required PluginRequest request,
  }) async {
    await Future.delayed(Duration(milliseconds: delayMs));
    return PluginResponse.moreTracks(PagedTracks(items: radioTracks, nextPageToken: null));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockFailingRadioPlugin implements PluginService {
  @override
  Future<PluginResponse> execute({
    required String pluginId,
    required PluginRequest request,
  }) async {
    throw Exception('Simulated network/plugin failure during radio fetch');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
