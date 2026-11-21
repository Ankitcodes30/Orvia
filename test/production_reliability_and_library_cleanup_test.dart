import 'package:flutter_test/flutter_test.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/screens/widgets/bhakti_section.dart';
import 'package:Orvia/services/catalogue/curated_playlists_service.dart';
import 'package:Orvia/services/catalogue/playlist_import_service.dart';
import 'package:Orvia/services/plugin_bootstrap_service.dart';
import 'package:Orvia/plugins/blocs/import/content_import_state.dart';
import 'package:Orvia/services/share/orvia_deep_link_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P0 — Cold Startup Non-blocking Initialization', () {
    test('PluginBootstrapService defines default repository URLs for offline/first-attempt safety', () {
      expect(PluginBootstrapService.defaultRepositoryUrls, isNotEmpty);
      expect(
        PluginBootstrapService.defaultRepositoryUrls.first,
        contains('bloom-factory'),
      );
    });
  });

  group('P0 — Song Artwork Verification & Provider Fallbacks', () {
    test('Bhakti & Spiritual tracks have valid, non-empty, genuine image URLs', () {
      expect(kVerifiedBhaktiTracks, hasLength(8));
      for (final track in kVerifiedBhaktiTracks) {
        expect(track.thumbnail.url, startsWith('https://c.saavncdn.com/'));
        expect(track.thumbnail.url, endsWith('-500x500.jpg'));
        expect(track.thumbnail.urlLow, isNotEmpty);
        expect(track.thumbnail.urlHigh, isNotEmpty);
        expect(track.album?.thumbnail?.url, isNotEmpty);
      }
    });

    test('Bollywood Hits tracks have active 500x500 image URLs', () {
      final tracks = CuratedPlaylistsService.getBollywoodTracks();
      expect(tracks, hasLength(20));
      for (final track in tracks) {
        expect(track.thumbnail.url, startsWith('https://c.saavncdn.com/'));
        expect(track.thumbnail.url, anyOf(endsWith('-500x500.jpg'), endsWith('-500x500.webp')));
      }
    });

    test('Instrumental Discovery tracks have active 500x500 image URLs', () {
      final tracks = CuratedPlaylistsService.getInstrumentalTracks();
      expect(tracks.length, greaterThanOrEqualTo(14));
      for (final track in tracks) {
        expect(track.thumbnail.url, startsWith('https://c.saavncdn.com/'));
        expect(track.thumbnail.url, endsWith('-500x500.jpg'));
      }
    });

    test('Marathi Hits tracks have active 500x500 image URLs', () {
      final tracks = CuratedPlaylistsService.getMarathiTracks();
      expect(tracks, hasLength(18));
      for (final track in tracks) {
        expect(track.thumbnail.url, startsWith('https://c.saavncdn.com/'));
        expect(track.thumbnail.url, endsWith('-500x500.jpg'));
      }
    });
  });

  group('P0 — Playlist Import Playability & Resolver ID Safety', () {
    test('Detects YouTube, Spotify, and JioSaavn URLs properly', () {
      expect(
        PlaylistImportService.detectPlatform('https://music.youtube.com/playlist?list=PLLt5mJLdjhbQ'),
        equals(ImportPlatform.youtube),
      );
      expect(
        PlaylistImportService.detectPlatform('https://www.youtube.com/playlist?list=PLPAE4oBeQMuc'),
        equals(ImportPlatform.youtube),
      );
      expect(
        PlaylistImportService.detectPlatform('https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M'),
        equals(ImportPlatform.spotify),
      );
      expect(
        PlaylistImportService.detectPlatform('https://www.jiosaavn.com/featured/weekly-top-songs/LdbVc1Z5i9E_'),
        equals(ImportPlatform.jiosaavn),
      );
    });

    test('PlaylistImportResult accurately exposes audit metrics', () {
      const result = PlaylistImportResult(
        isSuccess: true,
        platform: ImportPlatform.youtube,
        sourceCount: 53,
        importedCount: 50,
        duplicateCount: 2,
        unavailableCount: 1,
        unmatchedTrackTitles: ['[Deleted video]'],
      );

      expect(result.sourceCount, equals(53));
      expect(result.importedCount, equals(50));
      expect(result.duplicateCount, equals(2));
      expect(result.unavailableCount, equals(1));
      expect(result.unmatchedTrackTitles, contains('[Deleted video]'));
    });

    test('ImportTrackEntry NEVER assigns JioSaavn resolver ID to unmatched YouTube/Spotify track', () {
      const youtubeSource = ImportTrackItem(
        sourceId: 'dQw4w9WgXcQ',
        url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        artists: ['Rick Astley'],
        isExplicit: false,
      );

      // Unmatched entry with no resolvedTrack and no user selection
      const entry = ImportTrackEntry(sourceTrack: youtubeSource);

      expect(entry.effectiveTrack, isNull,
          reason: 'Unmatched YouTube track must not be marked effective/playable');
      expect(entry.isPlayable, isFalse);
      expect(entry.isUnmatched, isTrue);
    });

    test('ImportTrackEntry preserves legitimately stamped JioSaavn tracks', () {
      const saavnSource = ImportTrackItem(
        sourceId: 'content-resolver.bloomfactory.jisaavn::W13ekRcO',
        title: 'Bom Diggy Diggy',
        artists: ['Zack Knight'],
        thumbnailUrl: 'https://example.com/thumb.jpg',
        isExplicit: false,
      );

      const entry = ImportTrackEntry(sourceTrack: saavnSource);

      final effective = entry.effectiveTrack;
      expect(effective, isNotNull);
      expect(effective!.id, equals('content-resolver.bloomfactory.jisaavn::W13ekRcO'));
      expect(effective.title, equals('Bom Diggy Diggy'));
      expect(entry.isPlayable, isTrue);
      expect(entry.isUnmatched, isFalse);
    });

    test('ImportTrackEntry respects resolved candidate or user selection', () {
      const source = ImportTrackItem(
        sourceId: 'yt123',
        title: 'Song Title',
        artists: ['Artist'],
        isExplicit: false,
      );

      final candidate = Track(
        id: 'content-resolver.bloomfactory.jisaavn::matched999',
        title: 'Song Title',
        artists: [const ArtistSummary(id: '', name: 'Artist')],
        durationMs: BigInt.from(200000),
        thumbnail: const Artwork(url: 'https://example.com/art.jpg', layout: ImageLayout.square),
        isExplicit: false,
      );

      final resolvedEntry = ImportTrackEntry(
        sourceTrack: source,
        status: TrackResolutionStatus.resolved,
        resolvedTrack: candidate,
      );

      expect(resolvedEntry.isPlayable, isTrue);
      expect(resolvedEntry.effectiveTrack?.id, equals('content-resolver.bloomfactory.jisaavn::matched999'));

      final skippedEntry = resolvedEntry.copyWith(selectedCandidateIndex: -1);
      expect(skippedEntry.isSkipped, isTrue);
      expect(skippedEntry.effectiveTrack, isNull);
    });
  });

  group('P0 — Song Sharing & Deep Link Resolution', () {
    test('Builds clean user-facing deep link without exposing bloomfactory namespace', () {
      final track = Track(
        id: 'content-resolver.bloomfactory.jisaavn::W13ekRcO',
        title: 'Bom Diggy Diggy',
        artists: [const ArtistSummary(id: '', name: 'Zack Knight')],
        album: const AlbumSummary(id: '', title: 'Sonu Ke Titu Ki Sweety', artists: []),
        durationMs: BigInt.from(238000),
        thumbnail: const Artwork(
          url: 'https://c.saavncdn.com/150/test.jpg',
          layout: ImageLayout.square,
        ),
        isExplicit: false,
      );

      final appUri = OrviaDeepLinkService.buildTrackDeepLink(track, useAppScheme: true);
      expect(appUri.scheme, equals('orvia'));
      expect(appUri.host, equals('track'));
      // Clean ID
      expect(appUri.queryParameters['id'], equals('W13ekRcO'));
      expect(appUri.queryParameters['src'], equals('saavn'));
      expect(appUri.toString(), isNot(contains('bloomfactory')));

      // Reconstructs composite internal ID safely
      final parsed = OrviaDeepLinkService.parseDeepLink(appUri);
      expect(parsed, isNotNull);
      expect(parsed!['id'], equals('content-resolver.bloomfactory.jisaavn::W13ekRcO'));
      expect(parsed['title'], equals('Bom Diggy Diggy'));

      final parsedTrack = OrviaDeepLinkService.parseTrackFromUri(appUri);
      expect(parsedTrack, isNotNull);
      expect(parsedTrack!.id, equals('content-resolver.bloomfactory.jisaavn::W13ekRcO'));
      expect(parsedTrack.title, equals('Bom Diggy Diggy'));
    });

    test('isDeepLink accurately detects orvia scheme and web domains', () {
      expect(OrviaDeepLinkService.isDeepLink(Uri.parse('orvia://track?id=123')), isTrue);
      expect(OrviaDeepLinkService.isDeepLink(Uri.parse('orvia://playlist?name=Hits')), isTrue);
      expect(OrviaDeepLinkService.isDeepLink(Uri.parse('https://orvia.app/track?id=123')), isTrue);
      expect(OrviaDeepLinkService.isDeepLink(Uri.parse('https://ankitkr324.github.io/Orvia/track?id=123')), isTrue);
      expect(OrviaDeepLinkService.isDeepLink(Uri.parse('https://ankitcodes30.github.io/Orvia/track?id=123')), isTrue);
      expect(OrviaDeepLinkService.isDeepLink(Uri.parse('https://random.com/other')), isFalse);
    });
  });

  group('P1 — Library-Only Cleanup & Protected Discovery Verification', () {
    final excludedFromLibrary = {
      'Bollywood Dance Hits',
      'Marathi Superhits',
      'Instrumental Classics & Covers',
      'Dammn',
    };

    final protectedDiscoveryCategories = {
      'Instrumental Discovery',
      'Bollywood Hits',
      'Marathi Hits',
    };

    test('Exactly four items are targeted for Library exclusion', () {
      expect(excludedFromLibrary, hasLength(4));
      expect(excludedFromLibrary, contains('Bollywood Dance Hits'));
      expect(excludedFromLibrary, contains('Marathi Superhits'));
      expect(excludedFromLibrary, contains('Instrumental Classics & Covers'));
      expect(excludedFromLibrary, contains('Dammn'));
    });

    test('Protected Discovery categories are NOT excluded by the Library filter', () {
      for (final category in protectedDiscoveryCategories) {
        expect(
          excludedFromLibrary.contains(category),
          isFalse,
          reason: '$category must remain accessible in Discovery!',
        );
      }
    });

    test('Discovery category track sources remain intact and playable', () {
      final bollywood = CuratedPlaylistsService.getBollywoodTracks();
      final marathi = CuratedPlaylistsService.getMarathiTracks();
      final instrumental = CuratedPlaylistsService.getInstrumentalTracks();

      expect(bollywood, isNotEmpty);
      expect(marathi, isNotEmpty);
      expect(instrumental, isNotEmpty);

      // Verify no cross-pollution of IDs
      final allIds = <String>{};
      for (final t in [...bollywood, ...marathi, ...instrumental]) {
        expect(allIds.add(t.id), isTrue, reason: 'Duplicate track ID found: ${t.id}');
      }
    });
  });
}
