import 'package:Orvia/core/utils/track_identity.dart';
import 'package:Orvia/routes/app_router.dart';
import 'package:Orvia/screens/widgets/bhakti_section.dart';
import 'package:Orvia/screens/widgets/indian_browse_categories.dart';
import 'package:Orvia/services/catalogue/curated_playlists_service.dart';
import 'package:Orvia/services/catalogue/playlist_import_service.dart';
import 'package:Orvia/services/share/orvia_deep_link_service.dart';
import 'package:Orvia/src/rust/api/plugin/models.dart';
import 'package:flutter_test/flutter_test.dart';

const _kEmptyThumb = Artwork(url: '', layout: ImageLayout.square);

Track _makeTrack({
  required String id,
  required String title,
  List<ArtistSummary> artists = const [],
  String? url,
}) {
  return Track(
    id: id,
    title: title,
    artists: artists,
    thumbnail: _kEmptyThumb,
    url: url,
    isExplicit: false,
  );
}

void main() {
  group('Task A — TrackIdentity Canonical Key & Deduplication', () {
    test('Identifies tracks by composite provider ID first', () {
      final t1 = _makeTrack(
        id: 'content-resolver.bloomfactory.jisaavn::song123',
        title: 'Song Title',
      );
      final key = TrackIdentity.computeKey(t1);
      expect(key, equals('id:content-resolver.bloomfactory.jisaavn::song123'));
    });

    test('Identifies tracks by URL if ID is empty', () {
      final t1 = _makeTrack(
        id: '',
        title: 'Song Title',
        url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
      final key = TrackIdentity.computeKey(t1);
      expect(key, equals('url:youtube:dQw4w9WgXcQ'));
    });

    test('Falls back to normalized title and artist when ID and URL are empty', () {
      final t1 = _makeTrack(
        id: '',
        title: 'Bom Diggy Diggy [Official Music Video]',
        artists: [ArtistSummary(id: '', name: 'Zack Knight')],
      );
      final key = TrackIdentity.computeKey(t1);
      expect(key, equals('fallback:bom diggy diggy::zack knight'));
    });

    test('deduplicateTracks preserves order and rejects duplicates against existing list', () {
      final existing = <Track>[
        _makeTrack(id: 'id1', title: 'T1'),
        _makeTrack(id: 'id2', title: 'T2'),
      ];

      final incoming = <Track>[
        _makeTrack(id: 'id2', title: 'T2 Duplicate'),
        _makeTrack(id: 'id3', title: 'T3 New'),
        _makeTrack(id: 'id3', title: 'T3 Duplicate'),
      ];

      final result = TrackIdentity.deduplicateTracks(incoming, existingTracks: existing);
      expect(result.length, equals(1));
      expect(result.first.id, equals('id3'));
    });
  });

  group('Task B — Curated Playlists & Indian-First Discovery', () {
    test('Bollywood Hits has exactly 20 verified tracks with zero duplicates', () {
      final tracks = CuratedPlaylistsService.getBollywoodTracks();
      expect(tracks.length, equals(20));
      final ids = tracks.map((t) => t.id).toSet();
      expect(ids.length, equals(20));
    });

    test('Marathi Hits has 18 verified tracks with zero duplicates', () {
      final tracks = CuratedPlaylistsService.getMarathiTracks();
      expect(tracks.length, equals(18));
      final ids = tracks.map((t) => t.id).toSet();
      expect(ids.length, equals(18));
    });

    test('Instrumental Classics has 18 verified tracks with zero duplicates', () {
      final tracks = CuratedPlaylistsService.getInstrumentalTracks();
      expect(tracks.length, equals(18));
      final ids = tracks.map((t) => t.id).toSet();
      expect(ids.length, equals(18));
    });

    test('Indian-First Discovery contains curated categories in requested order', () {
      expect(kIndianBrowseCategories.first.title, equals('Best of 2026'));
      expect(kIndianBrowseCategories[1].title, equals('Bollywood Hits'));
      expect(kIndianBrowseCategories[2].title, equals('Lofi & Chill'));
      expect(kIndianBrowseCategories.last.title, equals('Navratri 2026'));
      expect(kIndianBrowseCategories.any((c) => c.title == 'Latest Hindi Hits'), isFalse);
    });
  });

  group('Task D — AppRouter & Library Navigation Consistency', () {
    test('AppRouter defines dedicated libraryNavigatorKey for Library branch', () {
      expect(AppRouter.libraryNavigatorKey, isNotNull);
      expect(AppRouter.exploreNavigatorKey, isNotNull);
      expect(AppRouter.globalRouterKey, isNotNull);
    });
  });

  group('Task F — Artwork Fallback Cascades', () {
    test('Bhakti tracks have complete artwork cascades across thumbnail, album, and artist', () {
      for (final t in kVerifiedBhaktiTracks) {
        expect(t.thumbnail.url, isNotEmpty);
        expect(t.thumbnail.urlLow, isNotEmpty);
        expect(t.thumbnail.urlHigh, isNotEmpty);
        expect(t.album?.thumbnail?.url, isNotEmpty);
        expect(t.artists.first.thumbnail?.url, isNotEmpty);
      }
    });
  });

  group('Task H — Playlist Import Platform Detection', () {
    test('Detects Spotify playlist, album, and track URLs', () {
      expect(
        PlaylistImportService.detectPlatform('https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M'),
        equals(ImportPlatform.spotify),
      );
      expect(
        PlaylistImportService.detectPlatform('https://open.spotify.com/album/4eLPsYPBmXABThSJ821sqY'),
        equals(ImportPlatform.spotify),
      );
    });

    test('Detects YouTube playlist and video URLs', () {
      expect(
        PlaylistImportService.detectPlatform('https://www.youtube.com/playlist?list=PLU4QT-w5zH6k'),
        equals(ImportPlatform.youtube),
      );
      expect(
        PlaylistImportService.detectPlatform('https://youtu.be/I0b88L53Gbg'),
        equals(ImportPlatform.youtube),
      );
    });

    test('Detects JioSaavn featured playlist and album URLs', () {
      expect(
        PlaylistImportService.detectPlatform('https://www.jiosaavn.com/featured/weekly-top-songs/LdbVc1Z5i9E_'),
        equals(ImportPlatform.jiosaavn),
      );
      expect(
        PlaylistImportService.detectPlatform('https://www.jiosaavn.com/album/dhadkan/NEokZI7Ut3s_'),
        equals(ImportPlatform.jiosaavn),
      );
    });

    test('Rejects unknown platforms', () {
      expect(
        PlaylistImportService.detectPlatform('https://example.com/music'),
        equals(ImportPlatform.unknown),
      );
      expect(
        PlaylistImportService.isValidImportUrl('not-a-url'),
        isFalse,
      );
    });
  });

  group('Task I — Orvia Deep Link Generation & Parsing', () {
    test('Builds custom scheme and web deep links for tracks', () {
      final track = _makeTrack(
        id: 'content-resolver.bloomfactory.jisaavn::W13ekRcO',
        title: 'Bom Diggy Diggy',
        artists: [ArtistSummary(id: '', name: 'Zack Knight')],
        url: 'https://www.jiosaavn.com/song/bom-diggy-diggy/W13ekRcO',
      );

      final appUri = OrviaDeepLinkService.buildTrackDeepLink(track, useAppScheme: true);
      expect(appUri.scheme, equals('orvia'));
      expect(appUri.host, equals('track'));
      // Clean user-facing URL does NOT leak bloomfactory internal namespaces
      expect(appUri.queryParameters['id'], equals('W13ekRcO'));
      expect(appUri.queryParameters['src'], equals('saavn'));
      expect(appUri.queryParameters['title'], equals('Bom Diggy Diggy'));

      final webUri = OrviaDeepLinkService.buildTrackDeepLink(track, useAppScheme: false);
      expect(webUri.scheme, equals('https'));
      expect(webUri.host, equals('ankitcodes30.github.io'));
      expect(webUri.path, equals('/Orvia/track'));

      // Test parsing: internal composite media ID is safely reconstructed
      final parsed = OrviaDeepLinkService.parseDeepLink(appUri);
      expect(parsed, isNotNull);
      expect(parsed!['type'], equals('track'));
      expect(parsed['id'], equals(track.id));
      expect(parsed['title'], equals('Bom Diggy Diggy'));
      expect(parsed['artist'], equals('Zack Knight'));
    });

    test('encodes and parses Unicode and reserved characters exactly once', () {
      const title = 'दिल से & stars 🎵 + 100%';
      const artist = 'आरिजीत & Friends 💚';
      const album = 'हिंदी / English?';
      const providerUrl = 'https://example.com/watch?v=abc&list=xyz';
      final track = Track(
        id: 'content-resolver.bloomfactory.ytvideo::abc12345678',
        title: title,
        artists: [const ArtistSummary(id: '', name: artist)],
        album: const AlbumSummary(id: '', title: album, artists: []),
        durationMs: BigInt.from(180000),
        thumbnail: _kEmptyThumb,
        url: providerUrl,
        isExplicit: false,
      );

      for (final useAppScheme in [true, false]) {
        final uri = OrviaDeepLinkService.buildTrackDeepLink(
          track,
          useAppScheme: useAppScheme,
        );
        expect(uri.queryParameters['title'], title);
        expect(uri.queryParameters['artist'], artist);
        expect(uri.queryParameters['album'], album);
        expect(uri.queryParameters['providerUrl'], providerUrl);

        final parsed = OrviaDeepLinkService.parseDeepLink(Uri.parse(uri.toString()));
        expect(parsed?['title'], title);
        expect(parsed?['artist'], artist);
        expect(parsed?['album'], album);
        expect(parsed?['providerUrl'], providerUrl);
      }
    });

    test('Builds and parses playlist deep links', () {
      final appUri = OrviaDeepLinkService.buildPlaylistDeepLink(
        name: 'Bollywood Dance Hits',
        useAppScheme: true,
      );
      expect(appUri.scheme, equals('orvia'));
      expect(appUri.host, equals('playlist'));
      expect(appUri.queryParameters['name'], equals('Bollywood Dance Hits'));

      final parsed = OrviaDeepLinkService.parseDeepLink(appUri);
      expect(parsed, isNotNull);
      expect(parsed!['type'], equals('playlist'));
      expect(parsed['name'], equals('Bollywood Dance Hits'));
    });
  });
}
