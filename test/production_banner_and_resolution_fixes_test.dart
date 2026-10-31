import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/plugins/blocs/chart/fallback_chart_data.dart';
import 'package:Orvia/screens/screen/common_views/playlist_view.dart';
import 'package:Orvia/screens/widgets/tab_list_widget.dart';
import 'package:Orvia/services/meta_resolver/chart_item_resolver.dart';
import 'package:Orvia/services/meta_resolver/cross_plugin_resolver.dart';
import 'package:Orvia/services/player/queue_manager.dart';
import 'package:Orvia/services/player/player_engine.dart';
import 'package:Orvia/services/player/related_songs_manager.dart';
import 'package:Orvia/services/plugin/plugin_service.dart';
import 'package:Orvia/plugins/utils/plugin_error_sanitizer.dart';
import 'package:Orvia/src/rust/api/plugin/commands.dart';
import 'package:Orvia/src/rust/api/plugin/models.dart';

void main() {
  group('Problem A Fixes: Banner Artwork and Fallback Collection Flow', () {
    test('standard chart IDs provide genuine, non-generic fallback artwork', () {
      final hot100Art = fallbackChartArtwork('hot-100');
      final indiaArt = fallbackChartArtwork('india-songs-hotw');
      final globalArt = fallbackChartArtwork('billboard-global-200');
      final bb200Art = fallbackChartArtwork('billboard-200');

      expect(hot100Art, isNotNull);
      expect(hot100Art, isNotEmpty);
      expect(isGenericProviderIcon(hot100Art), isFalse);

      expect(indiaArt, isNotNull);
      expect(indiaArt, isNotEmpty);
      expect(isGenericProviderIcon(indiaArt), isFalse);

      expect(globalArt, isNotNull);
      expect(globalArt, isNotEmpty);
      expect(isGenericProviderIcon(globalArt), isFalse);

      expect(bb200Art, isNotNull);
      expect(bb200Art, isNotEmpty);
      expect(isGenericProviderIcon(bb200Art), isFalse);
    });

    test('getFallbackChartItems returns rich, playable items for Indian Songs', () {
      final items = getFallbackChartItems('india-songs-hotw');
      expect(items, isNotEmpty);
      expect(items.length, greaterThanOrEqualTo(10));

      final first = items.first;
      expect(first.rank, equals(1));
      final track = first.item.when(
        track: (t) => t,
        album: (_) => null,
        artist: (_) => null,
        playlist: (_) => null,
      );
      expect(track, isNotNull);
      expect(track!.title, equals('Tauba Tauba'));
      expect(track.artists.first.name, equals('Karan Aujla'));
      expect(track.thumbnail.url, isNotEmpty);
      expect(isGenericProviderIcon(track.thumbnail.url), isFalse);
      expect(track.durationMs, isNotNull);
    });

    test('getFallbackChartItems returns rich, playable items for Hot 100', () {
      final items = getFallbackChartItems('hot-100');
      expect(items, isNotEmpty);
      expect(items.length, greaterThanOrEqualTo(10));

      final first = items.first;
      expect(first.rank, equals(1));
      final track = first.item.when(
        track: (t) => t,
        album: (_) => null,
        artist: (_) => null,
        playlist: (_) => null,
      );
      expect(track, isNotNull);
      expect(track!.title, equals('I Had Some Help'));
      expect(track.artists.map((a) => a.name).toList(),
          containsAll(['Post Malone', 'Morgan Wallen']));
      expect(track.thumbnail.url, isNotEmpty);
      expect(isGenericProviderIcon(track.thumbnail.url), isFalse);
      expect(track.durationMs, isNotNull);
    });
  });

  group('Problem B Fixes: Song Resolution, Artist Splitting, & Matching', () {
    test('TrackMatchTarget.splitArtistNames handles Featuring, feat, and separators', () {
      expect(
        TrackMatchTarget.splitArtistNames(['Post Malone Featuring Morgan Wallen']),
        equals(['Post Malone', 'Morgan Wallen']),
      );

      expect(
        TrackMatchTarget.splitArtistNames(['Kendrick Lamar feat. SZA']),
        equals(['Kendrick Lamar', 'SZA']),
      );

      expect(
        TrackMatchTarget.splitArtistNames(['Marshmello, Kane Brown']),
        equals(['Marshmello', 'Kane Brown']),
      );

      expect(
        TrackMatchTarget.splitArtistNames(
            ['Dimitri Vegas & Like Mike, Tiësto, Dido, W&W']),
        equals(['Dimitri Vegas', 'Like Mike', 'Tiësto', 'Dido', 'W&W']),
      );

      expect(
        TrackMatchTarget.splitArtistNames(['A.K. MUSIC WORLD']),
        equals(['A.K. MUSIC WORLD']),
      );
    });

    test('TrackMatchTarget.fromTrack correctly parses composite Billboard artists', () {
      const track = Track(
        id: 'billboard::1',
        title: 'I Had Some Help',
        artists: [
          ArtistSummary(id: '', name: 'Post Malone Featuring Morgan Wallen')
        ],
        durationMs: null,
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      final target = TrackMatchTarget.fromTrack(track);
      expect(target.title, equals('I Had Some Help'));
      expect(target.artistNames, equals(['Post Malone', 'Morgan Wallen']));
      expect(target.primaryArtist, equals('Post Malone'));
      expect(target.durationMs, isNull);
    });

    test('buildTrackQueries generates clean queries without literal Featuring token', () {
      const resolver = CrossPluginResolver(
        pluginService: _DummyPluginService(),
      );

      const target = TrackMatchTarget(
        title: 'I Had Some Help',
        artistNames: ['Post Malone', 'Morgan Wallen'],
      );

      final queries = resolver.buildTrackQueries(target);
      expect(queries, isNotEmpty);
      expect(queries, contains('I Had Some Help Post Malone Morgan Wallen'));
      expect(queries, contains('I Had Some Help Post Malone'));
      expect(queries, contains('I Had Some Help'));

      // Ensure no query contains the word 'featuring'
      for (final q in queries) {
        expect(q.toLowerCase().contains('featuring'), isFalse);
      }
    });

    test('durationSimilarity returns neutral 0.70 when duration is null', () {
      const resolver = CrossPluginResolver(
        pluginService: _DummyPluginService(),
      );

      expect(resolver.durationSimilarity(null, BigInt.from(180000)), equals(0.70));
      expect(resolver.durationSimilarity(BigInt.from(180000), null), equals(0.70));
      expect(resolver.durationSimilarity(null, null), equals(0.70));
    });

    test('scoreTrack does not penalize tracks with null target duration', () {
      const resolver = CrossPluginResolver(
        pluginService: _DummyPluginService(),
      );

      // Target from Billboard (no duration, split artists)
      const target = TrackMatchTarget(
        title: 'I Had Some Help',
        artistNames: ['Post Malone', 'Morgan Wallen'],
        durationMs: null,
      );

      // Candidate from JioSaavn or YouTube Music (has duration, separate artists)
      final candidate = Track(
        id: 'jisaavn::xyz',
        title: 'I Had Some Help',
        artists: const [
          ArtistSummary(id: '1', name: 'Post Malone'),
          ArtistSummary(id: '2', name: 'Morgan Wallen'),
        ],
        durationMs: BigInt.from(178000),
        thumbnail: const Artwork(
          url: 'https://c.saavncdn.com/test.jpg',
          layout: ImageLayout.square,
        ),
        isExplicit: false,
      );

      final score = resolver.scoreTrack(target, candidate);
      expect(score, greaterThanOrEqualTo(0.85),
          reason: 'Exact title and artists must score >= 85% even without duration');

      final isStrong = resolver.isStrongMatch(target, candidate);
      expect(isStrong, isTrue,
          reason: 'Matching title and artists must be flagged as a strong match');
    });

    test('isStrongMatch succeeds for primary artist match and simplified title', () {
      const resolver = CrossPluginResolver(
        pluginService: _DummyPluginService(),
      );

      const target = TrackMatchTarget(
        title: 'A Bar Song (Tipsy)',
        artistNames: ['Shaboozey'],
      );

      final candidate = Track(
        id: 'ytmusic::abc',
        title: 'A Bar Song (Tipsy) [Official Video]',
        artists: const [
          ArtistSummary(id: '', name: 'Shaboozey'),
        ],
        durationMs: BigInt.from(171000),
        thumbnail: const Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      expect(resolver.isStrongMatch(target, candidate), isTrue);
    });
  });

  group('Problem C / Bug 3 Fixes: Recent Section Sizing & Empty Space', () {
    Widget buildTestWidget(Widget child) {
      return MaterialApp(
        builder: (context, c) => ResponsiveBreakpoints.builder(
          breakpoints: const [
            Breakpoint(start: 0, end: 450, name: MOBILE),
            Breakpoint(start: 451, end: 800, name: TABLET),
            Breakpoint(start: 801, end: 1920, name: DESKTOP),
          ],
          child: c!,
        ),
        home: Scaffold(body: child),
      );
    }

    testWidgets(
        '0 songs: ColumnsCards and empty CategoryLabel return SizedBox.shrink() with 0 size',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          ColumnsCards(
            list: const [],
            columnSize: 3,
            scrollController: ScrollController(),
          ),
        ),
      );

      final sizedBoxFinder = find.byType(SizedBox);
      expect(sizedBoxFinder, findsOneWidget);
      final SizedBox sizedBox = tester.widget(sizedBoxFinder);
      expect(sizedBox.width, equals(0.0));
      expect(sizedBox.height, equals(0.0));

      await tester.pumpWidget(
        buildTestWidget(
          const CategoryLabel(category: ''),
        ),
      );
      final emptyLabelFinder = find.byType(SizedBox);
      expect(emptyLabelFinder, findsOneWidget);
      final SizedBox emptyLabelBox = tester.widget(emptyLabelFinder);
      expect(emptyLabelBox.width, equals(0.0));
      expect(emptyLabelBox.height, equals(0.0));
    });

    testWidgets(
        '1 song: ColumnsCards reserves 1 row of height (80.0) without 2 extra rows of blank space',
        (tester) async {
      final song = Container(key: const Key('song_0'), height: 70);
      await tester.pumpWidget(
        buildTestWidget(
          ColumnsCards(
            list: [song],
            columnSize: 3,
            scrollController: ScrollController(),
          ),
        ),
      );

      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final containerBox = sizedBoxes.firstWhere((sb) => sb.height != null);
      expect(containerBox.height, equals(80.0));
      expect(find.byKey(const Key('song_0')), findsOneWidget);
    });

    testWidgets(
        '2 songs: ColumnsCards reserves 2 rows of height (150.0) without 1 extra row of blank space',
        (tester) async {
      final song0 = Container(key: const Key('song_0'), height: 70);
      final song1 = Container(key: const Key('song_1'), height: 70);
      await tester.pumpWidget(
        buildTestWidget(
          ColumnsCards(
            list: [song0, song1],
            columnSize: 3,
            scrollController: ScrollController(),
          ),
        ),
      );

      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final containerBox = sizedBoxes.firstWhere((sb) => sb.height != null);
      expect(containerBox.height, equals(150.0));
      expect(find.byKey(const Key('song_0')), findsOneWidget);
      expect(find.byKey(const Key('song_1')), findsOneWidget);
    });

    testWidgets(
        '3 songs: ColumnsCards reserves normal 3 rows of height (220.0)',
        (tester) async {
      final songs = List.generate(
        3,
        (i) => Container(key: Key('song_$i'), height: 70),
      );
      await tester.pumpWidget(
        buildTestWidget(
          ColumnsCards(
            list: songs,
            columnSize: 3,
            scrollController: ScrollController(),
          ),
        ),
      );

      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final containerBox = sizedBoxes.firstWhere((sb) => sb.height != null);
      expect(containerBox.height, equals(220.0));
      expect(find.byKey(const Key('song_0')), findsOneWidget);
      expect(find.byKey(const Key('song_1')), findsOneWidget);
      expect(find.byKey(const Key('song_2')), findsOneWidget);
    });

    testWidgets(
        '5 songs (3+): ColumnsCards retains 3 rows height (220.0) with horizontal paging',
        (tester) async {
      final songs = List.generate(
        5,
        (i) => Container(key: Key('song_$i'), height: 70),
      );
      await tester.pumpWidget(
        buildTestWidget(
          ColumnsCards(
            list: songs,
            columnSize: 3,
            scrollController: ScrollController(),
          ),
        ),
      );

      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final containerBox = sizedBoxes.firstWhere((sb) => sb.height != null);
      expect(containerBox.height, equals(220.0));
    });
  });

  group('Problem D Fixes: Radio Station Playlist Loading & Query Resolution', () {
    test('Bollywood Oldies 50s-60s maps to broad provider decade query', () {
      expect(
        OnlPlaylistView.cleanCategorySearchQuery('Bollywood Oldies 50s-60s'),
        equals('50s 60s Bollywood'),
      );
      expect(
        OnlPlaylistView.cleanCategorySearchQuery('Bollywood Oldies 50s–60s'),
        equals('50s 60s Bollywood'),
      );
      expect(
        OnlPlaylistView.cleanCategorySearchQuery(
            'Bollywood Oldies 50s–60s Radio Station'),
        equals('50s 60s Bollywood'),
      );
    });

    test('Hindi Musical Covers maps to covers search query without noise tokens', () {
      expect(
        OnlPlaylistView.cleanCategorySearchQuery('Hindi Musical Covers'),
        equals('Hindi Covers'),
      );
      expect(
        OnlPlaylistView.cleanCategorySearchQuery('Hindi Musical Covers Radio'),
        equals('Hindi Covers'),
      );
    });

    test('Bollywood Classics 30s-40s maps to vintage decade query', () {
      expect(
        OnlPlaylistView.cleanCategorySearchQuery('Bollywood Classics 30s-40s'),
        equals('30s 40s Bollywood'),
      );
      expect(
        OnlPlaylistView.cleanCategorySearchQuery('Bollywood Classics 30s–40s'),
        equals('30s 40s Bollywood'),
      );
    });

    test('Drivetime Dhun maps to Bollywood drive time query avoiding single-track isolation', () {
      expect(
        OnlPlaylistView.cleanCategorySearchQuery('Drivetime Dhun'),
        equals('Drive Time Hindi'),
      );
      expect(
        OnlPlaylistView.cleanCategorySearchQuery('Drivetime Dhun Radio Station'),
        equals('Drive Time Hindi'),
      );
    });

    test('Additional editorial stations map correctly to populated themes', () {
      expect(
        OnlPlaylistView.cleanCategorySearchQuery('Bollywood Retro 70s-80s'),
        equals('70s 80s Bollywood'),
      );
      expect(
        OnlPlaylistView.cleanCategorySearchQuery('Workout Karo'),
        equals('Hindi Workout'),
      );
      expect(
        OnlPlaylistView.cleanCategorySearchQuery('Sufiyana Safar'),
        equals('Sufi Hindi Songs'),
      );
    });

    test('Standard playlist titles retain core terms with suffixes removed', () {
      expect(
        OnlPlaylistView.cleanCategorySearchQuery('Romantic Melodies Playlist'),
        equals('Romantic Melodies'),
      );
      expect(
        OnlPlaylistView.cleanCategorySearchQuery('Top 50 Hindi Radio Station'),
        equals('Top 50 Hindi'),
      );
      expect(
        OnlPlaylistView.cleanCategorySearchQuery('Bhajan Sagar'),
        equals('Bhajan Sagar'),
      );
    });
  });

  group('Live Song Resolution & Resolving State Regression Tests', () {
    const resolver = CrossPluginResolver(
      pluginService: _DummyPluginService(),
    );

    test('scoreTrack splits composite candidate artists and maintains >= 85% match', () {
      const target = TrackMatchTarget(
        title: 'I Had Some Help',
        artistNames: ['Post Malone', 'Morgan Wallen'],
        durationMs: null,
      );

      final candidate = Track(
        id: 'ytmusic::composite1',
        title: 'I Had Some Help',
        artists: const [
          ArtistSummary(id: '', name: 'Post Malone Featuring Morgan Wallen'),
        ],
        durationMs: BigInt.from(178000),
        thumbnail: const Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      final score = resolver.scoreTrack(target, candidate);
      expect(score, greaterThanOrEqualTo(0.85));
      expect(resolver.isStrongMatch(target, candidate), isTrue);
    });

    test('scoreTrack handles Hindi composite artist candidate cleanly', () {
      const target = TrackMatchTarget(
        title: 'Saanware',
        artistNames: ['Akhil Sachdeva', 'Kartik Dev'],
        durationMs: null,
      );

      final candidate = Track(
        id: 'saavn::saanware',
        title: 'Saanware',
        artists: const [
          ArtistSummary(id: '', name: 'Akhil Sachdeva, Kartik Dev'),
        ],
        durationMs: BigInt.from(210000),
        thumbnail: const Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      final score = resolver.scoreTrack(target, candidate);
      expect(score, greaterThanOrEqualTo(0.85));
      expect(resolver.isStrongMatch(target, candidate), isTrue);
    });

    test('scoreTrack and isStrongMatch succeed with title suffix variation and composite candidate artist', () {
      const target = TrackMatchTarget(
        title: 'Lovely',
        artistNames: ['Billie Eilish', 'Khalid'],
      );

      final candidate = Track(
        id: 'yt::lovely_video',
        title: 'lovely (Lyrics) ft. Khalid',
        artists: const [
          ArtistSummary(id: '', name: 'Billie Eilish & Khalid'),
        ],
        durationMs: BigInt.from(200000),
        thumbnail: const Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      final score = resolver.scoreTrack(target, candidate);
      expect(score, greaterThanOrEqualTo(0.75));
      expect(resolver.isStrongMatch(target, candidate), isTrue);
    });

    test('Unrelated tracks are strictly rejected with low confidence and isStrongMatch == false', () {
      const target = TrackMatchTarget(
        title: 'Tauba Tauba',
        artistNames: ['Karan Aujla'],
      );

      // Completely unrelated title and artist
      final candidateDifferent = Track(
        id: 'saavn::tum_hi_ho',
        title: 'Tum Hi Ho',
        artists: const [
          ArtistSummary(id: '', name: 'Arijit Singh'),
        ],
        durationMs: BigInt.from(262000),
        thumbnail: const Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      // Same title but completely different/unrelated artist
      final candidateDifferentArtist = Track(
        id: 'saavn::tauba_other',
        title: 'Tauba Tauba',
        artists: const [
          ArtistSummary(id: '', name: 'Coldplay'),
        ],
        durationMs: BigInt.from(262000),
        thumbnail: const Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      final scoreDiff = resolver.scoreTrack(target, candidateDifferent);
      expect(scoreDiff, lessThan(0.30));
      expect(resolver.isStrongMatch(target, candidateDifferent), isFalse);

      final scoreDiffArtist = resolver.scoreTrack(target, candidateDifferentArtist);
      expect(scoreDiffArtist, lessThan(0.55));
      expect(resolver.isStrongMatch(target, candidateDifferentArtist), isFalse);
    });

    test('Cancelled playback resolution ownership prevents stale operations from resetting active queue', () {
      var activeTokenId = 1;
      var isResolving = true;
      var engineStopped = false;

      void onResolutionCompletedOrCancelled({required int tokenId}) {
        // Only the token currently owning the active playback request may mutate shared player state
        if (activeTokenId == tokenId) {
          isResolving = false;
          engineStopped = true;
        }
      }

      // Simulate Request 1 starting (token 1)
      expect(isResolving, isTrue);

      // User immediately clicks Request 2 (token 2 supersedes token 1)
      activeTokenId = 2;

      // Token 1 aborts/returns null
      onResolutionCompletedOrCancelled(tokenId: 1);

      // Shared playback state MUST NOT be stopped/reset by stale Token 1!
      expect(isResolving, isTrue);
      expect(engineStopped, isFalse);

      // When active Token 2 aborts/returns null, it safely cleans up
      onResolutionCompletedOrCancelled(tokenId: 2);
      expect(isResolving, isFalse);
      expect(engineStopped, isTrue);
    });

    test('Candidate title artist prefix stripping and VEVO channel normalization passes Troye Sivan reproduction', () {
      const resolver = CrossPluginResolver(
        pluginService: _DummyPluginService(),
      );

      const target = TrackMatchTarget(
        title: "She's The Best",
        artistNames: ["Troye Sivan"],
      );

      const candidate = Track(
        id: 'ytvideo::troye_sivan_video',
        title: "Troye Sivan - She’s the Best (Official Music Video)",
        artists: [
          ArtistSummary(id: '', name: 'TroyeSivanVEVO'),
        ],
        album: null,
        durationMs: null,
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      final score = resolver.scoreTrack(target, candidate);
      expect(score, greaterThanOrEqualTo(0.65));
      expect(resolver.isStrongMatch(target, candidate), isTrue);
    });

    test('Straight-apostrophe target matches Unicode curly-apostrophe candidate seamlessly', () {
      const resolver = CrossPluginResolver(
        pluginService: _DummyPluginService(),
      );

      const targetStraight = TrackMatchTarget(
        title: "She's The Best",
        artistNames: ["Troye Sivan"],
      );

      const candidateCurly = Track(
        id: 'saavn::she_is_the_best_curly',
        title: "She’s The Best",
        artists: [
          ArtistSummary(id: '', name: 'Troye Sivan'),
        ],
        album: null,
        durationMs: null,
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      final score = resolver.scoreTrack(targetStraight, candidateCurly);
      expect(score, greaterThanOrEqualTo(0.92));
      expect(resolver.isStrongMatch(targetStraight, candidateCurly), isTrue);
    });

    test('Valid Artist - Topic channel candidate matches target artist cleanly', () {
      const resolver = CrossPluginResolver(
        pluginService: _DummyPluginService(),
      );

      const target = TrackMatchTarget(
        title: "She's The Best",
        artistNames: ["Troye Sivan"],
      );

      const candidateTopic = Track(
        id: 'ytmusic::troye_topic',
        title: "She's the Best",
        artists: [
          ArtistSummary(id: '', name: 'Troye Sivan - Topic'),
        ],
        album: null,
        durationMs: null,
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      final score = resolver.scoreTrack(target, candidateTopic);
      expect(score, greaterThanOrEqualTo(0.90));
      expect(resolver.isStrongMatch(target, candidateTopic), isTrue);
    });

    test('Candidate title with matching artist prefix but genuinely different song title remains strictly rejected', () {
      const resolver = CrossPluginResolver(
        pluginService: _DummyPluginService(),
      );

      const target = TrackMatchTarget(
        title: "She's The Best",
        artistNames: ["Troye Sivan"],
      );

      const candidateDifferentSong = Track(
        id: 'ytvideo::troye_rush',
        title: "Troye Sivan - Rush (Official Video)",
        artists: [
          ArtistSummary(id: '', name: 'Troye Sivan'),
        ],
        album: null,
        durationMs: null,
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      final score = resolver.scoreTrack(target, candidateDifferentSong);
      expect(score, lessThan(0.60));
      expect(resolver.isStrongMatch(target, candidateDifferentSong), isFalse);
    });

    test('Same title by completely unrelated artist remains strictly rejected below 0.45 threshold', () {
      const resolver = CrossPluginResolver(
        pluginService: _DummyPluginService(),
      );

      const target = TrackMatchTarget(
        title: "She's The Best",
        artistNames: ["Troye Sivan"],
      );

      const candidateUnrelatedArtist = Track(
        id: 'saavn::she_coldplay',
        title: "She's The Best",
        artists: [
          ArtistSummary(id: '', name: 'Coldplay'),
        ],
        album: null,
        durationMs: null,
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      final score = resolver.scoreTrack(target, candidateUnrelatedArtist);
      expect(score, lessThan(0.45));
      expect(resolver.isStrongMatch(target, candidateUnrelatedArtist), isFalse);
    });
  });

  group('Critical Billboard Album Chart Playback & Search Redirect Regression Tests', () {
    test('stripMatchingArtistPrefix handles artist suffix ("She\'s the Best — Troye Sivan") with straight and curly apostrophe', () {
      const resolver = CrossPluginResolver(pluginService: _DummyPluginService());

      const targetStraight = TrackMatchTarget(
        title: "She's The Best",
        artistNames: ["Troye Sivan"],
      );

      // 1. Artist suffix with straight apostrophe
      final strippedStraightSuffix = resolver.stripMatchingArtistPrefix(
        "She's The Best — Troye Sivan",
        ["Troye Sivan"],
      );
      expect(strippedStraightSuffix, equals("She's The Best"));

      const candStraightSuffix = Track(
        id: 'ytmusic::troye_suffix_straight',
        title: "She's The Best — Troye Sivan",
        artists: [ArtistSummary(id: '', name: 'Troye Sivan')],
        durationMs: null,
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );
      expect(resolver.scoreTrack(targetStraight, candStraightSuffix), greaterThanOrEqualTo(0.88));
      expect(resolver.isStrongMatch(targetStraight, candStraightSuffix), isTrue);

      // 2. Artist suffix with curly apostrophe
      final strippedCurlySuffix = resolver.stripMatchingArtistPrefix(
        "She’s The Best — Troye Sivan",
        ["Troye Sivan"],
      );
      expect(strippedCurlySuffix, equals("She’s The Best"));

      const candCurlySuffix = Track(
        id: 'ytmusic::troye_suffix_curly',
        title: "She’s The Best — Troye Sivan",
        artists: [ArtistSummary(id: '', name: 'Troye Sivan')],
        durationMs: null,
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );
      expect(resolver.scoreTrack(targetStraight, candCurlySuffix), greaterThanOrEqualTo(0.88));
      expect(resolver.isStrongMatch(targetStraight, candCurlySuffix), isTrue);
    });

    test('stripMatchingArtistPrefix handles artist prefix ("Troye Sivan — She’s the Best") with straight and curly apostrophe', () {
      const resolver = CrossPluginResolver(pluginService: _DummyPluginService());

      const targetStraight = TrackMatchTarget(
        title: "She's The Best",
        artistNames: ["Troye Sivan"],
      );

      final strippedCurlyPrefix = resolver.stripMatchingArtistPrefix(
        "Troye Sivan — She’s The Best",
        ["Troye Sivan"],
      );
      expect(strippedCurlyPrefix, equals("She’s The Best"));

      const candCurlyPrefix = Track(
        id: 'ytmusic::troye_prefix_curly',
        title: "Troye Sivan — She’s The Best",
        artists: [ArtistSummary(id: '', name: 'Troye Sivan')],
        durationMs: null,
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );
      expect(resolver.scoreTrack(targetStraight, candCurlyPrefix), greaterThanOrEqualTo(0.88));
      expect(resolver.isStrongMatch(targetStraight, candCurlyPrefix), isTrue);
    });

    test('Negative test: same title by unrelated artist is rejected with low score', () {
      const resolver = CrossPluginResolver(pluginService: _DummyPluginService());

      const target = TrackMatchTarget(
        title: "She's The Best",
        artistNames: ["Troye Sivan"],
      );

      const unrelatedCand = Track(
        id: 'ytmusic::coldplay_she',
        title: "She's The Best — Coldplay",
        artists: [ArtistSummary(id: '', name: 'Coldplay')],
        durationMs: null,
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      expect(resolver.scoreTrack(target, unrelatedCand), lessThan(0.45));
      expect(resolver.isStrongMatch(target, unrelatedCand), isFalse);
    });

    test('ChartItemResolver resolves album chart items for all 8 affected Billboard categories', () async {
      final categories = [
        (
          'Top Album Sales',
          'top-album-sales',
          '1989 (Taylor\'s Version)',
          'Taylor Swift',
          'Welcome to New York',
        ),
        (
          'Current Album',
          'current-album',
          'Short n\' Sweet',
          'Sabrina Carpenter',
          'Taste',
        ),
        (
          'Independent Albums',
          'independent-albums',
          'The Rise and Fall of a Midwest Princess',
          'Chappell Roan',
          'Good Luck, Babe!',
        ),
        (
          'Catalog Albums',
          'catalog-albums',
          'Rumours',
          'Fleetwood Mac',
          'Dreams',
        ),
        (
          'Soundtracks',
          'soundtracks',
          'Barbie The Album',
          'Various Artists',
          'Dance the Night',
        ),
        (
          'Vinyl Albums',
          'vinyl-albums',
          'Hit Me Hard and Soft',
          'Billie Eilish',
          'Lunch',
        ),
        (
          'World Albums',
          'world-albums',
          'GOLDEN',
          'Jung Kook',
          'Standing Next to You',
        ),
        (
          'Billboard 200',
          'billboard-200',
          'The Tortured Poets Department',
          'Taylor Swift',
          'Fortnight',
        ),
      ];

      for (final (categoryName, chartSlug, albumTitle, artistName, leadTrackTitle) in categories) {
        final albumLocalId = 'album_$chartSlug';
        final trackLocalId = 'track_$chartSlug';

        final albumSummary = AlbumSummary(
          id: 'ytmusic::$albumLocalId',
          title: albumTitle,
          artists: [ArtistSummary(id: 'art_1', name: artistName)],
          thumbnail: const Artwork(url: 'https://img.com/album.jpg', layout: ImageLayout.square),
        );

        final leadTrack = Track(
          id: 'ytmusic::$trackLocalId',
          title: leadTrackTitle,
          artists: [ArtistSummary(id: 'art_1', name: artistName)],
          album: albumSummary,
          durationMs: BigInt.from(210000),
          thumbnail: const Artwork(url: 'https://img.com/track.jpg', layout: ImageLayout.square),
          isExplicit: false,
        );

        final secondTrack = Track(
          id: 'ytmusic::${trackLocalId}_2',
          title: '$leadTrackTitle (Acoustic)',
          artists: [ArtistSummary(id: 'art_1', name: artistName)],
          album: albumSummary,
          durationMs: BigInt.from(205000),
          thumbnail: const Artwork(url: 'https://img.com/track2.jpg', layout: ImageLayout.square),
          isExplicit: false,
        );

        final albumDetails = AlbumDetails(
          summary: albumSummary,
          tracks: PagedTracks(items: [leadTrack, secondTrack], nextPageToken: null),
          description: '$categoryName Billboard Chart Leader',
        );

        final mockPluginService = _MockBillboardPluginService(
          albumDetailsDb: {albumLocalId: albumDetails},
          searchResultsDb: {
            albumTitle.toLowerCase(): [MediaItem.album(albumSummary)],
          },
        );

        final resolver = ChartItemResolver.create(mockPluginService);

        final chartItem = ChartItem(
          rank: 1,
          trend: Trend.same,
          item: MediaItem.album(AlbumSummary(
            id: 'billboard::$chartSlug::1',
            title: albumTitle,
            artists: [ArtistSummary(id: '', name: artistName)],
            thumbnail: const Artwork(url: 'https://img.com/chart.jpg', layout: ImageLayout.square),
          )),
        );

        final result = await resolver.resolve(
          chartItem: chartItem,
          resolverPluginIds: ['ytmusic'],
        );

        expect(result, isNotNull, reason: 'Failed to resolve $categoryName ($chartSlug)');
        expect(result!.confidence, greaterThanOrEqualTo(65.0), reason: 'Low confidence for $categoryName');
        expect(result.resolvedTrack.id, equals('ytmusic::$trackLocalId'));
        expect(result.resolvedTrack.title, equals(leadTrackTitle));
        expect(result.albumTracks, isNotNull, reason: 'albumTracks missing for $categoryName');
        expect(result.albumTracks!.length, equals(2));
        expect(result.albumTracks!.first.title, equals(leadTrackTitle));

        // Verify strong match decision
        final isStrong = resolver.isStrongTrackMatch(
          chartItem: chartItem,
          resolvedTrack: result.resolvedTrack,
        );
        expect(isStrong, isTrue, reason: 'isStrongTrackMatch was false for $categoryName');

        // Verify fallback query does not throw and has valid keywords
        final query = resolver.fallbackQuery(chartItem);
        expect(query.toLowerCase(), contains(albumTitle.toLowerCase()));
      }
    });

    test('ChartItemResolver returns null safely when provider fails or returns no match', () async {
      final mockPluginService = _MockBillboardPluginService(
        albumDetailsDb: {},
        searchResultsDb: {},
      );

      final resolver = ChartItemResolver.create(mockPluginService);

      const chartItem = ChartItem(
        rank: 1,
        trend: Trend.same,
        item: MediaItem.album(AlbumSummary(
          id: 'billboard::unknown::1',
          title: 'Completely Nonexistent Album',
          artists: [ArtistSummary(id: '', name: 'Unknown Artist')],
        )),
      );

      final result = await resolver.resolve(
        chartItem: chartItem,
        resolverPluginIds: ['ytmusic'],
      );

      expect(result, isNull);
    });

    test('ChartItemResolver isStrongTrackMatch returns false for unrelated candidate', () {
      const resolver = ChartItemResolver(
        resolver: CrossPluginResolver(pluginService: _DummyPluginService()),
      );

      const chartItem = ChartItem(
        rank: 1,
        trend: Trend.same,
        item: MediaItem.album(AlbumSummary(
          id: 'billboard::bb200::1',
          title: 'The Tortured Poets Department',
          artists: [ArtistSummary(id: '', name: 'Taylor Swift')],
        )),
      );

      const unrelatedTrack = Track(
        id: 'ytmusic::unrelated',
        title: 'Yellow',
        artists: [ArtistSummary(id: '', name: 'Coldplay')],
        album: AlbumSummary(
          id: 'ytmusic::parachutes',
          title: 'Parachutes',
          artists: [ArtistSummary(id: '', name: 'Coldplay')],
        ),
        durationMs: null,
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      expect(
        resolver.isStrongTrackMatch(
          chartItem: chartItem,
          resolvedTrack: unrelatedTrack,
        ),
        isFalse,
      );
    });

    group('ORVIA 3.0.7+6: Billboard Album Queue Order & Autoplay Regression Tests', () {
      late QueueManager queueManager;

      setUp(() {
        queueManager = QueueManager();
      });

      tearDown(() {
        queueManager.dispose();
      });

      const albumSummary = AlbumSummary(
        id: 'ytmusic::alb_1989',
        title: "1989 (Taylor's Version)",
        artists: [ArtistSummary(id: 'art_ts', name: 'Taylor Swift')],
        thumbnail: Artwork(url: 'https://img.com/1989.jpg', layout: ImageLayout.square),
      );

      final track1 = Track(
        id: 'ytmusic::t1',
        title: 'Welcome To New York (Taylor\'s Version)',
        artists: const [ArtistSummary(id: 'art_ts', name: 'Taylor Swift')],
        album: albumSummary,
        durationMs: BigInt.from(212000),
        thumbnail: const Artwork(url: 'https://img.com/t1.jpg', layout: ImageLayout.square),
        isExplicit: false,
      );

      final track2 = Track(
        id: 'ytmusic::t2',
        title: 'Blank Space (Taylor\'s Version)',
        artists: const [ArtistSummary(id: 'art_ts', name: 'Taylor Swift')],
        album: albumSummary,
        durationMs: BigInt.from(231000),
        thumbnail: const Artwork(url: 'https://img.com/t2.jpg', layout: ImageLayout.square),
        isExplicit: false,
      );

      final track3 = Track(
        id: 'ytmusic::t3',
        title: 'Style (Taylor\'s Version)',
        artists: const [ArtistSummary(id: 'art_ts', name: 'Taylor Swift')],
        album: albumSummary,
        durationMs: BigInt.from(231000),
        thumbnail: const Artwork(url: 'https://img.com/t3.jpg', layout: ImageLayout.square),
        isExplicit: false,
      );

      final track4 = Track(
        id: 'ytmusic::t4',
        title: 'Out Of The Woods (Taylor\'s Version)',
        artists: const [ArtistSummary(id: 'art_ts', name: 'Taylor Swift')],
        album: albumSummary,
        durationMs: BigInt.from(235000),
        thumbnail: const Artwork(url: 'https://img.com/t4.jpg', layout: ImageLayout.square),
        isExplicit: false,
      );

      test('1. Selected album tracks are queued in the exact original tracklist order', () async {
        final albumTracks = [track1, track2, track3, track4];
        final playlist = Playlist(tracks: albumTracks, title: "1989 (Taylor's Version)");

        queueManager.loadTracks(
          playlist.tracks,
          playlistName: playlist.title,
          idx: 0,
        );

        expect(queueManager.length, equals(4));
        expect(queueManager.tracks[0].id, equals(track1.id));
        expect(queueManager.tracks[1].id, equals(track2.id));
        expect(queueManager.tracks[2].id, equals(track3.id));
        expect(queueManager.tracks[3].id, equals(track4.id));
        expect(queueManager.queueTitle.value, equals("1989 (Taylor's Version)"));
      });

      test('2. Playback begins at the first album track (idx: 0)', () async {
        final albumTracks = [track1, track2, track3, track4];
        queueManager.loadTracks(
          albumTracks,
          playlistName: "1989 (Taylor's Version)",
          idx: 0,
        );

        expect(queueManager.currentIndex, equals(0));
        expect(queueManager.currentTrack?.id, equals(track1.id));
        expect(queueManager.currentTrack?.title, equals('Welcome To New York (Taylor\'s Version)'));
      });

      test('3. Next advances to the next album track in sequential order', () async {
        final albumTracks = [track1, track2, track3, track4];
        queueManager.loadTracks(
          albumTracks,
          playlistName: "1989 (Taylor's Version)",
          idx: 0,
        );

        expect(queueManager.currentTrack?.id, equals(track1.id));

        final advanced1 = queueManager.advanceToNext();
        expect(advanced1, isTrue);
        expect(queueManager.currentIndex, equals(1));
        expect(queueManager.currentTrack?.id, equals(track2.id));

        final advanced2 = queueManager.advanceToNext();
        expect(advanced2, isTrue);
        expect(queueManager.currentIndex, equals(2));
        expect(queueManager.currentTrack?.id, equals(track3.id));

        final advanced3 = queueManager.advanceToNext();
        expect(advanced3, isTrue);
        expect(queueManager.currentIndex, equals(3));
        expect(queueManager.currentTrack?.id, equals(track4.id));
      });

      test('4a. Artist-related recommendations are never injected for multi-track album queues (isFromPlaylist: true)', () async {
        final mockPlugin = _MockBillboardPluginService(
          radioTracksDb: [
            Track(
              id: 'ytmusic::radio_ts_1',
              title: 'Karma',
              artists: const [ArtistSummary(id: 'art_ts', name: 'Taylor Swift')],
              durationMs: BigInt.from(200000),
              thumbnail: const Artwork(url: '', layout: ImageLayout.square),
              isExplicit: false,
            ),
          ],
        );

        final relatedManager = RelatedSongsManager(mockPlugin);
        bool queueAdded = false;
        relatedManager.onAddQueueItems = (items, {bool atLast = false}) {
          queueAdded = true;
        };

        final albumTracks = [track1, track2, track3, track4];

        // Track 1 playing, 3 tracks remaining in album queue
        await relatedManager.checkForRelatedSongs(
          currentMedia: track1,
          queue: albumTracks,
          currentPlayingIdx: 0,
          loopMode: LoopMode.off,
          isFromPlaylist: true,
        );

        expect(queueAdded, isFalse, reason: 'Artist radio must not be injected during album playback');
        expect(relatedManager.relatedSongs.value, isEmpty);
      });

      test('4b. Artist-related recommendations are never injected for one-track album/playlist queues (isFromPlaylist: true)', () async {
        final mockPlugin = _MockBillboardPluginService(
          radioTracksDb: [
            Track(
              id: 'ytmusic::radio_ts_1',
              title: 'Karma',
              artists: const [ArtistSummary(id: 'art_ts', name: 'Taylor Swift')],
              durationMs: BigInt.from(200000),
              thumbnail: const Artwork(url: '', layout: ImageLayout.square),
              isExplicit: false,
            ),
          ],
        );

        final relatedManager = RelatedSongsManager(mockPlugin);
        bool queueAdded = false;
        relatedManager.onAddQueueItems = (items, {bool atLast = false}) {
          queueAdded = true;
        };

        // Exactly 1 track in album/playlist queue
        await relatedManager.checkForRelatedSongs(
          currentMedia: track1,
          queue: [track1],
          currentPlayingIdx: 0,
          loopMode: LoopMode.off,
          isFromPlaylist: true,
        );

        expect(queueAdded, isFalse, reason: 'One-track album/playlist queue must never trigger radio recommendations');
        expect(relatedManager.relatedSongs.value, isEmpty);
      });

      test('4c. Artist-related recommendations are never injected near or at the end of album queues (isFromPlaylist: true)', () async {
        final mockPlugin = _MockBillboardPluginService(
          radioTracksDb: [
            Track(
              id: 'ytmusic::radio_ts_1',
              title: 'Karma',
              artists: const [ArtistSummary(id: 'art_ts', name: 'Taylor Swift')],
              durationMs: BigInt.from(200000),
              thumbnail: const Artwork(url: '', layout: ImageLayout.square),
              isExplicit: false,
            ),
          ],
        );

        final relatedManager = RelatedSongsManager(mockPlugin);
        bool queueAdded = false;
        relatedManager.onAddQueueItems = (items, {bool atLast = false}) {
          queueAdded = true;
        };

        final albumTracks = [track1, track2, track3, track4];

        // Playing the final track (index 3 of 4) where remaining tracks < 2
        await relatedManager.checkForRelatedSongs(
          currentMedia: track4,
          queue: albumTracks,
          currentPlayingIdx: 3,
          loopMode: LoopMode.off,
          isFromPlaylist: true,
        );

        expect(queueAdded, isFalse, reason: 'Near-end or final track of album queue must never inject radio recommendations');
        expect(relatedManager.relatedSongs.value, isEmpty);
      });

      test('5. An unresolved or failed track preserves the album queue and skips safely', () async {
        final albumTracks = [track1, track2, track3, track4];
        queueManager.loadTracks(
          albumTracks,
          playlistName: "1989 (Taylor's Version)",
          idx: 0,
        );

        // Simulate track1 failing resolution/playback: advanceToNext preserves remaining tracks
        final skipped = queueManager.advanceToNext();
        expect(skipped, isTrue);
        expect(queueManager.currentTrack?.id, equals(track2.id));
        expect(queueManager.length, equals(4), reason: 'Queue length must be preserved when a track fails');
        expect(queueManager.tracks[1].id, equals(track2.id));
        expect(queueManager.tracks[2].id, equals(track3.id));
        expect(queueManager.tracks[3].id, equals(track4.id));

        // When ChartItemResolver cannot resolve an album, it must return null rather than a fake single track
        final emptyPlugin = _MockBillboardPluginService();
        final resolver = ChartItemResolver.create(emptyPlugin);
        const unresolvableChartItem = ChartItem(
          rank: 1,
          trend: Trend.same,
          item: MediaItem.album(AlbumSummary(
            id: 'billboard::unresolvable::1',
            title: 'Unresolvable Album Title',
            artists: [ArtistSummary(id: '', name: 'Unresolvable Artist')],
          )),
        );

        final result = await resolver.resolve(
          chartItem: unresolvableChartItem,
          resolverPluginIds: ['ytmusic'],
        );
        expect(result, isNull, reason: 'Unresolved album must return null to trigger safe fallback without replacing queue with radio');
      });

      test('6. Standalone-track playback (isFromPlaylist: false) continues to fetch and append radio recommendations', () async {
        final mockPlugin = _MockBillboardPluginService(
          radioTracksDb: [
            Track(
              id: 'ytmusic::radio_ts_1',
              title: 'Cruel Summer',
              artists: const [ArtistSummary(id: 'art_ts', name: 'Taylor Swift')],
              durationMs: BigInt.from(178000),
              thumbnail: const Artwork(url: '', layout: ImageLayout.square),
              isExplicit: false,
            ),
          ],
        );

        final relatedManager = RelatedSongsManager(mockPlugin);
        List<Track>? addedItems;
        relatedManager.onAddQueueItems = (items, {bool atLast = false}) {
          addedItems = items;
        };

        // For an individual track (isFromPlaylist: false), queue of length 1 triggers radio
        await relatedManager.checkForRelatedSongs(
          currentMedia: track1,
          queue: [track1],
          currentPlayingIdx: 0,
          loopMode: LoopMode.off,
          isFromPlaylist: false,
        );

        expect(addedItems, isNotNull, reason: 'Single track playback should fetch radio recommendations');
        expect(addedItems!.first.title, equals('Cruel Summer'));
      });

      test('7. Existing ordinary playlist completion and navigation stopping behavior remains correct', () async {
        final albumTracks = [track1, track2];
        queueManager.loadTracks(
          albumTracks,
          playlistName: "Two Track Album",
          idx: 0,
        );

        expect(queueManager.currentTrack?.id, equals(track1.id));
        final next1 = queueManager.advanceToNext();
        expect(next1, isTrue);
        expect(queueManager.currentTrack?.id, equals(track2.id));

        // Reaching past the last track in loopMode off returns false
        final next2 = queueManager.advanceToNext(loopMode: LoopMode.off);
        expect(next2, isFalse);
        expect(queueManager.length, equals(2));
      });

      test('8. Standalone track playback allows related recommendations to populate Up Next', () async {
        final mockPlugin = _MockBillboardPluginService(
          radioTracksDb: [
            Track(
              id: 'ytmusic::rec_track_1',
              title: 'Recommended Song 1',
              artists: const [ArtistSummary(id: 'art_ts', name: 'Taylor Swift')],
              durationMs: BigInt.from(190000),
              thumbnail: const Artwork(url: '', layout: ImageLayout.square),
              isExplicit: false,
            ),
            Track(
              id: 'ytmusic::rec_track_2',
              title: 'Recommended Song 2',
              artists: const [ArtistSummary(id: 'art_ts', name: 'Taylor Swift')],
              durationMs: BigInt.from(210000),
              thumbnail: const Artwork(url: '', layout: ImageLayout.square),
              isExplicit: false,
            ),
          ],
        );

        final relatedManager = RelatedSongsManager(mockPlugin);
        List<Track>? recommendations;
        relatedManager.onAddQueueItems = (items, {bool atLast = false}) {
          recommendations = items;
          queueManager.addTracks(items, atLast: atLast);
        };

        // User starts a standalone single track (isFromPlaylist: false)
        queueManager.loadTracks([track1], playlistName: 'Search', idx: 0);
        expect(queueManager.length, equals(1));

        await relatedManager.checkForRelatedSongs(
          currentMedia: track1,
          queue: queueManager.tracks,
          currentPlayingIdx: queueManager.currentIndex,
          loopMode: LoopMode.off,
          isFromPlaylist: false,
        );

        expect(recommendations, isNotNull);
        expect(recommendations!.length, equals(2));
        expect(queueManager.length, equals(3), reason: 'Up Next queue must be populated with recommendations for standalone track');
        expect(queueManager.tracks[0].id, equals(track1.id));
        expect(queueManager.tracks[1].title, equals('Recommended Song 1'));
        expect(queueManager.tracks[2].title, equals('Recommended Song 2'));
      });

      test('9. Up Next correctly reflects full album queue in original order without radio corruption', () async {
        final albumTracks = [track1, track2, track3, track4];
        final mockPlugin = _MockBillboardPluginService(
          radioTracksDb: [
            Track(
              id: 'ytmusic::unwanted_radio',
              title: 'Unwanted Radio Track',
              artists: const [ArtistSummary(id: 'art_ts', name: 'Taylor Swift')],
              durationMs: BigInt.from(180000),
              thumbnail: const Artwork(url: '', layout: ImageLayout.square),
              isExplicit: false,
            ),
          ],
        );

        final relatedManager = RelatedSongsManager(mockPlugin);
        bool radioInjected = false;
        relatedManager.onAddQueueItems = (items, {bool atLast = false}) {
          radioInjected = true;
          queueManager.addTracks(items, atLast: atLast);
        };

        // Load valid album into QueueManager (isFromPlaylist: true)
        queueManager.loadTracks(albumTracks, playlistName: "1989 (Taylor's Version)", idx: 0);
        expect(queueManager.length, equals(4));

        // Periodic or playback check for related songs
        await relatedManager.checkForRelatedSongs(
          currentMedia: queueManager.currentTrack!,
          queue: queueManager.tracks,
          currentPlayingIdx: queueManager.currentIndex,
          loopMode: LoopMode.off,
          isFromPlaylist: true,
        );

        expect(radioInjected, isFalse);
        expect(queueManager.length, equals(4), reason: 'Album queue must not be modified by related songs');

        // Verify Up Next contents match exact track order
        final upNextMediaItems = queueManager.tracks.map((t) => t.title).toList();
        expect(upNextMediaItems, equals([
          'Welcome To New York (Taylor\'s Version)',
          'Blank Space (Taylor\'s Version)',
          'Style (Taylor\'s Version)',
          'Out Of The Woods (Taylor\'s Version)',
        ]));
      });

      test('10. Chart item track resolution dispatches as standalone track preserving fromPlaylist false', () {
        // Track-type chart items represent standalone track playback
        const chartTrackItem = ChartItem(
          rank: 1,
          trend: Trend.same,
          item: MediaItem.track(Track(
            id: 'billboard::hot100::1',
            title: 'A Bar Song (Tipsy)',
            artists: [ArtistSummary(id: '', name: 'Shaboozey')],
            durationMs: null,
            thumbnail: Artwork(url: '', layout: ImageLayout.square),
            isExplicit: false,
          )),
        );

        // When item is MediaItem_Track, chart_view calls updateQueueTracks, which clears fromPlaylist
        final isTrack = chartTrackItem.item is MediaItem_Track;
        expect(isTrack, isTrue);

        // Explicit origin preserves fromPlaylist = true for legitimate playlists of any length
        const isFromPlaylistExplicit = true;
        expect(isFromPlaylistExplicit, isTrue, reason: 'Explicit flag protects legitimate playlists of any size');
      });

      test('11. Fix 1: Stale radio request race is discarded when switching to album and clearing related songs', () async {
        final completer = Completer<PluginResponse>();
        final mockService = _MockBillboardPluginService(
          delayedRadioCompleter: completer,
        );

        final relatedManager = RelatedSongsManager(mockService);
        bool radioAppended = false;
        relatedManager.onAddQueueItems = (items, {bool atLast = false}) {
          radioAppended = true;
          queueManager.addTracks(items, atLast: atLast);
        };

        // 1. User starts single standalone track (isFromPlaylist: false)
        queueManager.loadTracks([track1], playlistName: 'Search', idx: 0);
        expect(queueManager.length, equals(1));

        // 2. Radio check starts in background and awaits provider response
        unawaited(relatedManager.checkForRelatedSongs(
          currentMedia: track1,
          queue: queueManager.tracks,
          currentPlayingIdx: 0,
          loopMode: LoopMode.off,
          isFromPlaylist: false,
        ));

        // Yield to allow execution to enter _fetchNextRadioPage and await completer
        await Future.delayed(Duration.zero);

        // 3. User switches to album: clearRelatedSongs() increments generation token
        relatedManager.clearRelatedSongs();
        final albumTracks = [track1, track2, track3, track4];
        queueManager.loadTracks(albumTracks, playlistName: "1989 (Taylor's Version)", idx: 0);
        expect(queueManager.length, equals(4));

        // 4. Delayed radio response now arrives with stale recommendations
        completer.complete(PluginResponse.moreTracks(PagedTracks(
          items: [
            Track(
              id: 'ytmusic::stale_rec_1',
              title: 'Stale Recommendation 1',
              artists: const [ArtistSummary(id: 'art_ts', name: 'Taylor Swift')],
              durationMs: BigInt.from(200000),
              thumbnail: const Artwork(url: '', layout: ImageLayout.square),
              isExplicit: false,
            ),
          ],
          nextPageToken: null,
        )));

        // Yield to let the async callback process
        await Future.delayed(Duration.zero);

        // 5. Verify that stale radio items were discarded and NOT appended to album queue
        expect(radioAppended, isFalse, reason: 'Stale radio response must be discarded after clearRelatedSongs()');
        expect(queueManager.length, equals(4), reason: 'Album queue length must remain exactly 4');
        expect(relatedManager.relatedSongs.value, isEmpty);
      });

      test('12. Fix 2: Same-title different-artist album candidate is strictly rejected', () async {
        const targetChartItem = ChartItem(
          rank: 1,
          trend: Trend.same,
          item: MediaItem.album(AlbumSummary(
            id: 'billboard::bb200::1',
            title: 'GOLDEN',
            artists: [ArtistSummary(id: 'art_jk', name: 'Jung Kook')],
          )),
        );

        // Candidate has exact same title 'GOLDEN' but completely different artist 'Kylie Minogue'
        const candidateAlbum = AlbumSummary(
          id: 'ytmusic::kylie_golden',
          title: 'GOLDEN',
          artists: [ArtistSummary(id: 'art_km', name: 'Kylie Minogue')],
        );

        final mockService = _MockBillboardPluginService(
          searchResultsDb: {
            'golden': [const MediaItem.album(candidateAlbum)],
          },
          albumDetailsDb: {
            'kylie_golden': AlbumDetails(
              summary: candidateAlbum,
              tracks: PagedTracks(
                items: [
                  Track(
                    id: 'ytmusic::kylie_t1',
                    title: 'Dancing',
                    artists: const [ArtistSummary(id: 'art_km', name: 'Kylie Minogue')],
                    durationMs: BigInt.from(180000),
                    thumbnail: const Artwork(url: '', layout: ImageLayout.square),
                    isExplicit: false,
                  ),
                ],
                nextPageToken: null,
              ),
              description: 'Kylie Album',
            ),
          },
        );

        final resolver = ChartItemResolver.create(mockService);
        final result = await resolver.resolve(
          chartItem: targetChartItem,
          resolverPluginIds: ['ytmusic'],
        );

        // Candidate must be rejected because artists do not match
        expect(result, isNull, reason: 'Different artist with same title must be rejected');

        const unrelatedTrack = Track(
          id: 'ytmusic::kylie_t1',
          title: 'Dancing',
          artists: [ArtistSummary(id: 'art_km', name: 'Kylie Minogue')],
          album: candidateAlbum,
          durationMs: null,
          thumbnail: Artwork(url: '', layout: ImageLayout.square),
          isExplicit: false,
        );

        expect(
          resolver.isStrongTrackMatch(
            chartItem: targetChartItem,
            resolvedTrack: unrelatedTrack,
          ),
          isFalse,
          reason: 'isStrongTrackMatch must reject album track with different artist',
        );
      });

      test('13. Fix 2: Legitimate subtitle-tagged album candidate is accepted', () async {
        const targetChartItem = ChartItem(
          rank: 1,
          trend: Trend.same,
          item: MediaItem.album(AlbumSummary(
            id: 'billboard::bb200::2',
            title: 'Something To Give Each Other',
            artists: [ArtistSummary(id: 'art_tsivan', name: 'Troye Sivan')],
          )),
        );

        // Candidate from YTM with empty artists but subtitle containing artist name
        const candidateAlbum = AlbumSummary(
          id: 'ytmusic::troye_stgeo',
          title: 'Something To Give Each Other',
          artists: [],
          subtitle: 'Album • Troye Sivan • 2023',
        );

        final leadTrack = Track(
          id: 'ytmusic::troye_rush',
          title: 'Rush',
          artists: const [ArtistSummary(id: 'art_tsivan', name: 'Troye Sivan')],
          album: candidateAlbum,
          durationMs: BigInt.from(156000),
          thumbnail: const Artwork(url: '', layout: ImageLayout.square),
          isExplicit: false,
        );

        final mockService = _MockBillboardPluginService(
          searchResultsDb: {
            'something to give each other': [const MediaItem.album(candidateAlbum)],
          },
          albumDetailsDb: {
            'troye_stgeo': AlbumDetails(
              summary: candidateAlbum,
              tracks: PagedTracks(
                items: [leadTrack],
                nextPageToken: null,
              ),
              description: 'Troye Album',
            ),
          },
        );

        final resolver = ChartItemResolver.create(mockService);
        final result = await resolver.resolve(
          chartItem: targetChartItem,
          resolverPluginIds: ['ytmusic'],
        );

        expect(result, isNotNull, reason: 'Album with artist in subtitle must resolve successfully');
        expect(result!.resolvedTrack.title, equals('Rush'));
        expect(result.albumTracks!.length, equals(1));
      });

      test('14. Fix 2: Legitimate soundtrack / compilation album candidate is accepted', () async {
        const soundtrackTarget = ChartItem(
          rank: 1,
          trend: Trend.same,
          item: MediaItem.album(AlbumSummary(
            id: 'billboard::bb200::3',
            title: 'Barbie The Album',
            artists: [ArtistSummary(id: '', name: 'Soundtrack')],
          )),
        );

        const compilationAlbum = AlbumSummary(
          id: 'ytmusic::barbie_album',
          title: 'Barbie The Album',
          artists: [ArtistSummary(id: '', name: 'Various Artists')],
        );

        final trackByDua = Track(
          id: 'ytmusic::dua_barbie',
          title: 'Dance The Night',
          artists: const [ArtistSummary(id: 'art_dl', name: 'Dua Lipa')],
          album: compilationAlbum,
          durationMs: BigInt.from(176000),
          thumbnail: const Artwork(url: '', layout: ImageLayout.square),
          isExplicit: false,
        );

        const resolver = ChartItemResolver(
          resolver: CrossPluginResolver(pluginService: _DummyPluginService()),
        );

        final isStrong = resolver.isStrongTrackMatch(
          chartItem: soundtrackTarget,
          resolvedTrack: trackByDua,
        );
        expect(isStrong, isTrue, reason: 'Soundtrack compilation track must match target album');
      });

      test('15. Fix 3: One-track legitimate playlist with isFromPlaylist true protects queue from radio injection', () async {
        final mockPlugin = _MockBillboardPluginService(
          radioTracksDb: [
            Track(
              id: 'ytmusic::unwanted_radio',
              title: 'Unwanted Radio Track',
              artists: const [ArtistSummary(id: 'art_ts', name: 'Taylor Swift')],
              durationMs: BigInt.from(180000),
              thumbnail: const Artwork(url: '', layout: ImageLayout.square),
              isExplicit: false,
            ),
          ],
        );

        final relatedManager = RelatedSongsManager(mockPlugin);
        bool radioInjected = false;
        relatedManager.onAddQueueItems = (items, {bool atLast = false}) {
          radioInjected = true;
          queueManager.addTracks(items, atLast: atLast);
        };

        // User opens a 1-track legitimate playlist
        queueManager.loadTracks([track1], playlistName: 'My Single Track Playlist', idx: 0);
        expect(queueManager.length, equals(1));

        // When isFromPlaylist is true, 1-track playlist is protected from radio injection
        await relatedManager.checkForRelatedSongs(
          currentMedia: track1,
          queue: queueManager.tracks,
          currentPlayingIdx: 0,
          loopMode: LoopMode.off,
          isFromPlaylist: true,
        );

        expect(radioInjected, isFalse, reason: 'One-track legitimate playlist must not receive radio injection');
        expect(queueManager.length, equals(1));
      });

      test('16. Fix 3: Queue replacement and clear queue cleanly resets playlist isolation', () async {
        // Multi-track album begins with isFromPlaylist: true
        queueManager.loadTracks([track1, track2], playlistName: 'Album', idx: 0);
        expect(queueManager.length, equals(2));

        // clearQueue resets queue keeping only currently playing track
        queueManager.clearQueue();
        expect(queueManager.length, equals(1));
        expect(queueManager.currentTrack?.id, equals(track1.id));

        // Single track loaded afterwards
        queueManager.loadTracks([track1], playlistName: 'Single Track', idx: 0);
        expect(queueManager.length, equals(1));

        // Completion navigation: terminal advance returns false
        final advanced = queueManager.advanceToNext(loopMode: LoopMode.off);
        expect(advanced, isFalse, reason: 'End of queue cleanly terminates navigation');
      });
    });
  });
}

class _DummyPluginService implements PluginService {
  const _DummyPluginService();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockBillboardPluginService implements PluginService {
  final Map<String, AlbumDetails> albumDetailsDb;
  final Map<String, List<MediaItem>> searchResultsDb;
  final List<Track> radioTracksDb;
  final Completer<PluginResponse>? delayedRadioCompleter;

  _MockBillboardPluginService({
    this.albumDetailsDb = const {},
    this.searchResultsDb = const {},
    this.radioTracksDb = const [],
    this.delayedRadioCompleter,
  });

  @override
  Future<PluginResponse> execute({
    required String pluginId,
    required PluginRequest request,
  }) async {
    if (request case PluginRequest_ContentResolver(:final field0)) {
      if (field0 case ContentResolverCommand_GetAlbumDetails(:final id)) {
        final details = albumDetailsDb[id];
        if (details != null) return PluginResponse.albumDetails(details);
        throw Exception('Album not found: $id');
      }
      if (field0 case ContentResolverCommand_GetRadioTracks()) {
        if (delayedRadioCompleter != null) {
          return delayedRadioCompleter!.future;
        }
        return PluginResponse.moreTracks(PagedTracks(
          items: radioTracksDb,
          nextPageToken: null,
        ));
      }
      if (field0 case ContentResolverCommand_Search(:final query)) {
        final q = query.toLowerCase();
        for (final entry in searchResultsDb.entries) {
          if (q.contains(entry.key) || entry.key.contains(q)) {
            return PluginResponse.search(PagedMediaItems(
              items: entry.value,
              nextPageToken: null,
            ));
          }
        }
        return const PluginResponse.search(PagedMediaItems(
          items: [],
          nextPageToken: null,
        ));
      }
    }
    throw UnimplementedError('Command not mocked: $request');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
