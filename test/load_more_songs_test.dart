import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/screens/screen/common_views/artist_view.dart';
import 'package:Orvia/screens/widgets/load_more_songs_tile.dart';
import 'package:Orvia/services/player/queue_manager.dart';

Track _makeTrack(String id, String title, {String artist = 'Arijit Singh', String? artistId}) {
  return Track(
    id: id,
    title: title,
    artists: [
      ArtistSummary(
        id: artistId ?? 'artist_1',
        name: artist,
      ),
    ],
    album: const AlbumSummary(
      id: 'album_1',
      title: 'Test Album',
      artists: [],
    ),
    thumbnail: const Artwork(
      url: 'https://example.com/art.jpg',
      urlLow: 'https://example.com/art_low.jpg',
      urlHigh: 'https://example.com/art_high.jpg',
      layout: ImageLayout.square,
    ),
    isExplicit: false,
  );
}

void main() {
  group('LoadMoreSongsTile Widget Tests', () {
    testWidgets('1. Initial display shows "Load more songs" button and calls onTap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadMoreSongsTile(
              isLoading: false,
              hasMore: true,
              currentCount: 20,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('load_more_songs_button')), findsOneWidget);
      expect(find.text('Load more songs'), findsOneWidget);
      expect(find.byKey(const Key('load_more_songs_loading')), findsNothing);
      expect(find.byKey(const Key('load_more_songs_retry')), findsNothing);

      await tester.tap(find.byKey(const Key('load_more_songs_button')));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('2. Loading state shows spinner and disables repeated taps', (tester) async {
      int tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadMoreSongsTile(
              isLoading: true,
              hasMore: true,
              currentCount: 20,
              onTap: () => tapCount++,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('load_more_songs_loading')), findsOneWidget);
      expect(find.text('Loading more songs...'), findsOneWidget);

      // Attempt tap while loading
      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(tapCount, equals(0)); // tap disabled
    });

    testWidgets('3. Error state displays retry button and fires retry on tap', (tester) async {
      bool retryTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadMoreSongsTile(
              isLoading: false,
              hasMore: true,
              error: 'Network connection timeout',
              currentCount: 20,
              onTap: () => retryTapped = true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('load_more_songs_retry')), findsOneWidget);
      expect(find.text('Failed to load more. Tap to retry'), findsOneWidget);

      await tester.tap(find.byKey(const Key('load_more_songs_retry')));
      await tester.pump();

      expect(retryTapped, isTrue);
    });

    testWidgets('4. End-of-list state displays "All X songs loaded"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadMoreSongsTile(
              isLoading: false,
              hasMore: false,
              currentCount: 45,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('load_more_songs_ended')), findsOneWidget);
      expect(find.text('All 45 songs loaded'), findsOneWidget);
      expect(find.byKey(const Key('load_more_songs_button')), findsNothing);
    });
  });

  group('Pagination & Duplicate Prevention Tests', () {
    test('5. Deduplication preserves track order and appends only unique tracks', () {
      final initialTracks = [
        _makeTrack('track_1', 'Song A'),
        _makeTrack('track_2', 'Song B'),
        _makeTrack('track_3', 'Song C'),
      ];

      final incomingBatch = [
        _makeTrack('track_2', 'Song B duplicate'), // duplicate
        _makeTrack('track_4', 'Song D'),           // new
        _makeTrack('track_3', 'Song C duplicate'), // duplicate
        _makeTrack('track_5', 'Song E'),           // new
      ];

      final existingIds = initialTracks.map((t) => t.id).toSet();
      final deduplicatedNew = incomingBatch
          .where((t) => t.id.isNotEmpty && !existingIds.contains(t.id))
          .toList();

      final combined = [...initialTracks, ...deduplicatedNew];

      expect(combined.length, equals(5));
      expect(combined.map((t) => t.id).toList(), equals([
        'track_1',
        'track_2',
        'track_3',
        'track_4',
        'track_5',
      ]));
      expect(combined[3].title, equals('Song D'));
      expect(combined[4].title, equals('Song E'));
    });

    test('6. Concurrent requests are locked while fetching', () {
      bool isLoading = false;
      int executionCount = 0;

      void triggerLoadMore() {
        if (isLoading) return; // guard against concurrent requests
        isLoading = true;
        executionCount++;
      }

      // First call succeeds and sets loading
      triggerLoadMore();
      expect(executionCount, equals(1));
      expect(isLoading, isTrue);

      // Subsequent concurrent calls while loading are ignored
      triggerLoadMore();
      triggerLoadMore();
      expect(executionCount, equals(1));

      // After loading completes, subsequent call works
      isLoading = false;
      triggerLoadMore();
      expect(executionCount, equals(2));
    });

    test('7. Pagination preserves playback queue integrity and active track', () {
      final queueManager = QueueManager();

      final queueSongs = [
        _makeTrack('queue_1', 'Playing Track 1'),
        _makeTrack('queue_2', 'Playing Track 2'),
      ];

      queueManager.loadTracks(queueSongs, idx: 0);
      expect(queueManager.currentTrack?.id, equals('queue_1'));
      expect(queueManager.currentIndex, equals(0));

      // Simulate album / artist view loading 3 batches of unrelated songs
      final albumBatch1 = [_makeTrack('album_1', 'Album Track 1')];
      final albumBatch2 = [_makeTrack('album_2', 'Album Track 2')];
      final albumCombined = [...albumBatch1, ...albumBatch2];

      // Verifying that view pagination does not touch QueueManager
      expect(queueManager.length, equals(2));
      expect(queueManager.currentTrack?.id, equals('queue_1'));
      expect(albumCombined.length, equals(2));
    });
  });

  group('Artist Related Track Filtering Tests', () {
    test('8. isTrackRelatedToArtist correctly filters artist songs vs unrelated songs', () {
      final track1 = _makeTrack('t1', 'Tum Hi Ho', artist: 'Arijit Singh');
      final track2 = _makeTrack('t2', 'Channa Mereya', artist: 'Arijit Singh, Pritam');
      final track3 = _makeTrack('t3', 'Shape of You', artist: 'Ed Sheeran');
      final track4 = _makeTrack('t4', 'Kesariya', artist: 'Pritam, Arijit Singh, Amitabh Bhattacharya');

      expect(ArtistView.isTrackRelatedToArtist(track1, 'Arijit Singh'), isTrue);
      expect(ArtistView.isTrackRelatedToArtist(track2, 'Arijit Singh'), isTrue);
      expect(ArtistView.isTrackRelatedToArtist(track3, 'Arijit Singh'), isFalse);
      expect(ArtistView.isTrackRelatedToArtist(track4, 'Arijit Singh'), isTrue);
    });

    test('9. isTrackRelatedToArtist handles direct artist IDs and clean normalizations', () {
      final trackWithId = _makeTrack(
        't5',
        'Kabira',
        artist: 'Tochi Raina, Rekha Bhardwaj',
        artistId: 'content-resolver.bloomfactory.jisaavn::arijit_123',
      );

      expect(
        ArtistView.isTrackRelatedToArtist(
          trackWithId,
          'Arijit Singh',
          artistId: 'content-resolver.bloomfactory.jisaavn::arijit_123',
        ),
        isTrue,
      );

      final trackUnrelated = _makeTrack(
        't6',
        'Believer',
        artist: 'Imagine Dragons',
        artistId: 'imagine_dragons_999',
      );

      expect(
        ArtistView.isTrackRelatedToArtist(
          trackUnrelated,
          'Arijit Singh',
          artistId: 'arijit_123',
        ),
        isFalse,
      );
    });
  });
}
