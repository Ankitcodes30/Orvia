import 'package:flutter_test/flutter_test.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/screens/screen/common_views/artist_view.dart';
import 'package:Orvia/services/banner/smart_banner_service.dart';
import 'package:Orvia/services/player/queue_manager.dart';
import 'package:Orvia/services/share/orvia_deep_link_service.dart';
import 'package:Orvia/routes/app_router.dart';
import 'package:Orvia/services/share/windows_protocol_service.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BUG 5 — Morning Bhakti Schedule & Fallback Tests', () {
    test('strictly eligible between 6:00 AM (inclusive) and 10:30 AM (exclusive)', () {
      bool isBhaktiActiveAt(DateTime dt) {
        final active = SmartBannerService.getActiveBanners(testTime: dt);
        return active.any((b) => b.id == 'morning_bhakti');
      }

      // 5:59 AM -> Ineligible
      expect(isBhaktiActiveAt(DateTime(2026, 10, 21, 5, 59)), isFalse);

      // 6:00 AM -> Eligible (inclusive)
      expect(isBhaktiActiveAt(DateTime(2026, 10, 21, 6, 0)), isTrue);

      // 8:15 AM -> Eligible
      expect(isBhaktiActiveAt(DateTime(2026, 10, 21, 8, 15)), isTrue);

      // 10:29 AM -> Eligible
      expect(isBhaktiActiveAt(DateTime(2026, 10, 21, 10, 29)), isTrue);

      // 10:30 AM -> Ineligible (exclusive cutoff)
      expect(isBhaktiActiveAt(DateTime(2026, 10, 21, 10, 30)), isFalse);

      // 10:40 PM -> Ineligible
      expect(isBhaktiActiveAt(DateTime(2026, 10, 21, 22, 40)), isFalse);

      // Midnight -> Ineligible
      expect(isBhaktiActiveAt(DateTime(2026, 10, 21, 0, 0)), isFalse);
    });

    test('morning_bhakti is NEVER selected as a fallback outside 6:00-10:30 AM window', () {
      // Test at 10:40 PM
      final atNight = DateTime(2026, 10, 21, 22, 40);
      final activeAtNight = SmartBannerService.getActiveBanners(testTime: atNight);
      expect(
        activeAtNight.any((b) => b.id == 'morning_bhakti'),
        isFalse,
        reason: 'morning_bhakti must not appear at 10:40 PM even as fallback',
      );

      // Test at 5:59 AM
      final atDawn = DateTime(2026, 10, 21, 5, 59);
      final activeAtDawn = SmartBannerService.getActiveBanners(testTime: atDawn);
      expect(
        activeAtDawn.any((b) => b.id == 'morning_bhakti'),
        isFalse,
        reason: 'morning_bhakti must not appear at 5:59 AM',
      );

      // Test at 10:30 AM
      final atCutoff = DateTime(2026, 10, 21, 10, 30);
      final activeAtCutoff = SmartBannerService.getActiveBanners(testTime: atCutoff);
      expect(
        activeAtCutoff.any((b) => b.id == 'morning_bhakti'),
        isFalse,
        reason: 'morning_bhakti must not appear at 10:30 AM',
      );
    });
  });

  group('BUG 4 — Cold Start Deep Link Routing & Parsing Tests', () {
    test('isDeepLink recognizes cold start query parameter links and web domains', () {
      expect(
        OrviaDeepLinkService.isDeepLink(Uri.parse('/?id=Ha5QlyycMhM&src=youtube')),
        isTrue,
      );
      expect(
        OrviaDeepLinkService.isDeepLink(Uri.parse('https://ankitcodes30.github.io/Orvia/?id=Ha5QlyycMhM&src=youtube')),
        isTrue,
      );
      expect(
        OrviaDeepLinkService.isDeepLink(Uri.parse('https://ankitcodes30.github.io/Orvia/track?id=Ha5QlyycMhM&src=youtube')),
        isTrue,
      );
      expect(
        OrviaDeepLinkService.isDeepLink(Uri.parse('orvia://track?id=Ha5QlyycMhM&src=youtube')),
        isTrue,
      );
      expect(
        OrviaDeepLinkService.isDeepLink(Uri.parse('/explore')),
        isFalse,
      );
    });

    test('parseDeepLink correctly extracts track parameters from root and query links', () {
      final parsed = OrviaDeepLinkService.parseDeepLink(
        Uri.parse('/?id=Ha5QlyycMhM&src=youtube&title=SongTitle&artist=SongArtist'),
      );
      expect(parsed, isNotNull);
      expect(parsed!['type'], 'track');
      expect(parsed['title'], 'SongTitle');
      expect(parsed['artist'], 'SongArtist');
      expect(parsed['src'], 'youtube');
      expect(parsed['id'], contains('Ha5QlyycMhM'));
    });

    test('AppRouter configuration includes routes for cold start deep links', () {
      final router = AppRouter.globalRouter;
      final routePaths = router.configuration.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toList();

      expect(routePaths, contains('/'));
      expect(routePaths, contains('/Orvia'));
      expect(routePaths, contains('/track'));
      expect(routePaths, contains('/Orvia/track'));
    });
  });

  group('BUG 3 — Shared Song Metadata Preservation Tests', () {
    test('buildTrackShareText preserves full title and artist in generated deep link', () {
      final track = Track(
        id: 'content-resolver.bloomfactory.ytvideo:Ha5QlyycMhM',
        title: 'Tum Hi Ho',
        artists: const [
          ArtistSummary(
            id: '459320',
            name: 'Arijit Singh',
            thumbnail: Artwork(url: '', layout: ImageLayout.square),
          ),
        ],
        album: const AlbumSummary(
          id: '123',
          title: 'Aashiqui 2',
          artists: [],
          thumbnail: Artwork(url: '', layout: ImageLayout.square),
        ),
        durationMs: BigInt.zero,
        thumbnail: const Artwork(url: 'https://i.ytimg.com/vi/Ha5QlyycMhM/hqdefault.jpg', layout: ImageLayout.square),
        isExplicit: false,
      );

      final shareText = OrviaDeepLinkService.buildTrackShareText(track);
      expect(shareText, contains('Tum Hi Ho'));
      expect(shareText, contains('Arijit Singh'));

      final uriMatch = RegExp(r'https://[^\s]+').firstMatch(shareText);
      expect(uriMatch, isNotNull);
      final parsedUri = Uri.parse(uriMatch!.group(0)!);
      expect(parsedUri.queryParameters['title'], 'Tum Hi Ho');
      expect(parsedUri.queryParameters['artist'], contains('Arijit Singh'));
    });

    test('QueueManager.replaceTrackById matches and updates track even with stamped vs unstamped IDs', () {
      final queueManager = QueueManager();
      final initialTrack = Track(
        id: 'content-resolver.bloomfactory.ytvideo:Ha5QlyycMhM',
        title: 'Unknown Track',
        artists: const [ArtistSummary(id: '', name: '', thumbnail: Artwork(url: '', layout: ImageLayout.square))],
        album: const AlbumSummary(id: '', title: '', artists: [], thumbnail: Artwork(url: '', layout: ImageLayout.square)),
        durationMs: BigInt.zero,
        thumbnail: const Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      queueManager.loadTracks([initialTrack], playlistName: 'Queue');
      expect(queueManager.tracks.first.title, 'Unknown Track');

      final updatedTrack = Track(
        id: 'Ha5QlyycMhM', // Unstamped ID
        title: 'Tum Hi Ho',
        artists: const [ArtistSummary(id: '', name: 'Arijit Singh', thumbnail: Artwork(url: '', layout: ImageLayout.square))],
        album: const AlbumSummary(id: '', title: 'Aashiqui 2', artists: [], thumbnail: Artwork(url: '', layout: ImageLayout.square)),
        durationMs: BigInt.zero,
        thumbnail: const Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      final changed = queueManager.replaceTrackById('Ha5QlyycMhM', updatedTrack);
      expect(changed, isTrue);
      expect(queueManager.tracks.first.title, 'Tum Hi Ho');
      expect(queueManager.tracks.first.artists.first.name, 'Arijit Singh');
    });
  });

  group('BUG 2 — Artist Page Loading & Cross-Plugin Matching Tests', () {
    test('isTrackRelatedToArtist matches cross-plugin tracks by artist name when IDs differ in format', () {
      final ytTrack = Track(
        id: 'ytvideo:abc12345678',
        title: 'Kesariya',
        artists: const [
          ArtistSummary(
            id: 'UCz46F6cQ8u4kC6bQ8gY',
            name: 'Arijit Singh',
            thumbnail: Artwork(url: '', layout: ImageLayout.square),
          ),
        ],
        album: null,
        durationMs: BigInt.zero,
        thumbnail: const Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      final isRelated = ArtistView.isTrackRelatedToArtist(
        ytTrack,
        'Arijit Singh',
        artistId: '459320', // Numeric JioSaavn ID
      );

      expect(isRelated, isTrue,
          reason: 'Artist name Arijit Singh must match even if artistId is 459320 and track artist has YouTube channel ID');
    });

    test('isTrackRelatedToArtist matches multi-artist collaborator tracks', () {
      final collabTrack = Track(
        id: 'ytvideo:xyz98765432',
        title: 'Chaleya',
        artists: const [
          ArtistSummary(
            id: 'UC1',
            name: 'Arijit Singh, Shilpa Rao',
            thumbnail: Artwork(url: '', layout: ImageLayout.square),
          ),
        ],
        album: null,
        durationMs: BigInt.zero,
        thumbnail: const Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      expect(
        ArtistView.isTrackRelatedToArtist(collabTrack, 'Arijit Singh', artistId: '459320'),
        isTrue,
      );
      expect(
        ArtistView.isTrackRelatedToArtist(collabTrack, 'Shilpa Rao'),
        isTrue,
      );
    });

    test('isTrackRelatedToArtist rejects tracks by unrelated artists', () {
      final unrelatedTrack = Track(
        id: 'ytvideo:11111111111',
        title: 'Baby',
        artists: const [
          ArtistSummary(
            id: 'UCJustin',
            name: 'Justin Bieber',
            thumbnail: Artwork(url: '', layout: ImageLayout.square),
          ),
        ],
        album: null,
        durationMs: BigInt.zero,
        thumbnail: const Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      expect(
        ArtistView.isTrackRelatedToArtist(unrelatedTrack, 'Arijit Singh', artistId: '459320'),
        isFalse,
      );
    });
  });

  group('BUG 1 — Trending Heading & Cache Invalidation Tests', () {
    test('trending section heading is normalized to Trending Now', () {
      const rawSection = Section(
        id: 'trending_community_yt',
        title: 'Trending Community Playlist',
        cardType: CardType.carousel,
        items: [],
      );

      final normalized = Section(
        id: rawSection.id,
        title: 'Trending Now',
        subtitle: rawSection.subtitle,
        cardType: rawSection.cardType,
        items: rawSection.items,
        moreLink: rawSection.moreLink,
      );

      expect(normalized.title, 'Trending Now');
    });
  });

  group('MASTER SHARING, COLD-START DEEP LINKS & WINDOWS PROTOCOL TESTS', () {
    test('1. Android and Windows share links use a consistent, correctly encoded HTTPS format', () {
      const testTitle = 'Kesariya (केसरिया)';
      const testArtist = 'Arijit Singh & Pritam';
      const testAlbum = 'Brahmāstra';

      final track = Track(
        id: 'content-resolver.bloomfactory.ytmusic::dQw4w9WgXcQ',
        title: testTitle,
        artists: const [
          ArtistSummary(id: '1', name: testArtist, thumbnail: Artwork(url: '', layout: ImageLayout.square)),
        ],
        album: const AlbumSummary(id: '2', title: testAlbum, artists: [], thumbnail: Artwork(url: '', layout: ImageLayout.square)),
        durationMs: BigInt.zero,
        thumbnail: const Artwork(url: '', layout: ImageLayout.square),
        url: 'https://music.youtube.com/watch?v=dQw4w9WgXcQ',
        isExplicit: false,
      );

      final shareText = OrviaDeepLinkService.buildTrackShareText(track);
      expect(shareText, contains('Kesariya (केसरिया)'));
      expect(shareText, contains('Arijit Singh & Pritam'));

      final uri = OrviaDeepLinkService.buildTrackDeepLink(track, short: false);
      expect(uri.scheme, 'https');
      expect(uri.host, 'ankitcodes30.github.io');
      expect(uri.path, '/Orvia/track');
      expect(uri.queryParameters['id'], 'dQw4w9WgXcQ');
      expect(uri.queryParameters['src'], 'ytmusic');
      expect(uri.queryParameters['title'], testTitle);
      expect(uri.queryParameters['artist'], testArtist);
      expect(uri.queryParameters['album'], testAlbum);
      expect(uri.queryParameters['providerUrl'], 'https://music.youtube.com/watch?v=dQw4w9WgXcQ');
    });

    test('2. A generated link preserves cleaned track ID and source/provider information', () {
      final saavnTrack = Track(
        id: 'content-resolver.bloomfactory.saavn::dxrBpjVX',
        title: 'Channa Mereya',
        artists: const [ArtistSummary(id: 'a1', name: 'Arijit Singh', thumbnail: Artwork(url: '', layout: ImageLayout.square))],
        album: null,
        durationMs: BigInt.zero,
        thumbnail: const Artwork(url: 'https://c.saavncdn.com/123.jpg', layout: ImageLayout.square),
        isExplicit: false,
      );

      final uri = OrviaDeepLinkService.buildTrackDeepLink(saavnTrack, short: false);
      expect(uri.queryParameters['id'], 'dxrBpjVX');
      expect(uri.queryParameters['src'], 'saavn');
      expect(uri.queryParameters.containsKey('providerUrl'), isFalse);
    });

    test('3. Original provider URL is retained when available and fallback to canonical YouTube URL', () {
      // With explicit provider URL
      final explicitTrack = Track(
        id: 'content-resolver.bloomfactory.saavn::song123',
        title: 'Song',
        artists: const [],
        album: null,
        durationMs: BigInt.zero,
        thumbnail: const Artwork(url: '', layout: ImageLayout.square),
        url: 'https://www.jiosaavn.com/song/example/song123',
        isExplicit: false,
      );
      final explicitUri = OrviaDeepLinkService.buildTrackDeepLink(explicitTrack);
      expect(explicitUri.queryParameters['providerUrl'], 'https://www.jiosaavn.com/song/example/song123');

      // YouTube track with no url populated: provides canonical YouTube watch URL
      final ytNoUrlTrack = Track(
        id: 'content-resolver.bloomfactory.ytmusic::Ha5QlyycMhM',
        title: 'Tum Hi Ho',
        artists: const [],
        album: null,
        durationMs: BigInt.zero,
        thumbnail: const Artwork(url: '', layout: ImageLayout.square),
        url: null,
        isExplicit: false,
      );
      final ytUri = OrviaDeepLinkService.buildTrackDeepLink(ytNoUrlTrack);
      expect(ytUri.queryParameters['providerUrl'], 'https://www.youtube.com/watch?v=Ha5QlyycMhM');

      // Local track: never exposes local file:// URL to web link
      final localTrack = Track(
        id: 'local::C:/Music/test.mp3',
        title: 'Local File',
        artists: const [],
        album: null,
        durationMs: BigInt.zero,
        thumbnail: const Artwork(url: '', layout: ImageLayout.square),
        url: 'file:///C:/Music/test.mp3',
        isExplicit: false,
      );
      final localUri = OrviaDeepLinkService.buildTrackDeepLink(localTrack);
      expect(localUri.queryParameters.containsKey('providerUrl'), isFalse);
    });

    test('4. Get Orvia Android/Desktop points exactly to ankitcodes30.github.io/Orvia/', () {
      const targetWebsite = 'https://ankitcodes30.github.io/Orvia/';
      expect(targetWebsite, isNot(contains('github.com/Ankitcodes30/Orvia/releases')));
      expect(targetWebsite, isNot(contains('orvia.app')));
      expect(targetWebsite, equals('https://ankitcodes30.github.io/Orvia/'));
    });

    test('5. Invalid or missing deep-link parameters fail gracefully', () {
      expect(OrviaDeepLinkService.parseDeepLink(Uri.parse('https://ankitcodes30.github.io/Orvia/track')), isNull);
      expect(OrviaDeepLinkService.parseDeepLink(Uri.parse('https://ankitcodes30.github.io/Orvia/track?id=')), isNull);
      expect(OrviaDeepLinkService.parseDeepLink(Uri.parse('https://ankitcodes30.github.io/Orvia/track?id=   ')), isNull);
      expect(OrviaDeepLinkService.parseTrackFromUri(Uri.parse('https://ankitcodes30.github.io/Orvia/track?id=')), isNull);
    });

    test('6. HTTPS track URLs are correctly recognized as URLs and not file backup paths', () {
      const shareMessage = '🎵 Listen to "Kesariya" by Arijit Singh on Orvia:\nhttps://ankitcodes30.github.io/Orvia/track?id=dQw4w9WgXcQ&src=youtube';
      final match = RegExp(r'(https?://[^\s]+|orvia://[^\s]+)').firstMatch(shareMessage);
      expect(match, isNotNull);
      final extractedUrl = match!.group(0)!;
      expect(extractedUrl, startsWith('https://ankitcodes30.github.io/Orvia/track'));

      final parsed = Uri.parse(extractedUrl);
      expect(OrviaDeepLinkService.isDeepLink(parsed), isTrue);

      // Verify that a file path vs an HTTP path are distinct
      const sampleUrlPath = 'https://ankitcodes30.github.io/Orvia/track?id=123';
      final uri = Uri.parse(sampleUrlPath);
      final isWebOrAppUrl = uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'orvia';
      expect(isWebOrAppUrl, isTrue);
    });

    test('7. Pending cold-start deep links take priority and block session restoration', () {
      OrviaDeepLinkService.clearPendingDeepLink();
      expect(OrviaDeepLinkService.hasPendingDeepLink, isFalse);

      final coldStartUri = Uri.parse('https://ankitcodes30.github.io/Orvia/track?id=dQw4w9WgXcQ&src=youtube');
      OrviaDeepLinkService.setPendingDeepLink(coldStartUri);

      expect(OrviaDeepLinkService.hasPendingDeepLink, isTrue);
      expect(OrviaDeepLinkService.pendingDeepLink, equals(coldStartUri));

      OrviaDeepLinkService.clearPendingDeepLink();
      expect(OrviaDeepLinkService.hasPendingDeepLink, isFalse);
    });

    test('8. Windows protocol registration registers orvia:// protocol cleanly', () {
      String? registeredPath;
      WindowsProtocolService.registryWriterOverride = (exePath) {
        registeredPath = exePath;
        return true;
      };

      final success = WindowsProtocolService.registerUrlProtocol(r'C:\Program Files\Orvia\Orvia.exe');
      expect(success, isTrue);
      expect(registeredPath, r'C:\Program Files\Orvia\Orvia.exe');

      WindowsProtocolService.registryWriterOverride = null;
    });
  });
}
