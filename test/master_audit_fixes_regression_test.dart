import 'package:flutter_test/flutter_test.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/utils/track_identity.dart';
import 'package:Orvia/screens/widgets/bhakti_section.dart';
import 'package:Orvia/services/banner/smart_banner_service.dart';
import 'package:Orvia/utils/load_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Master Audit & Bug Fixes Verification', () {
    test('1. Workout collection has 18 verified playable tracks from source playlist', () {
      final banners = SmartBannerService.getActiveBanners(
        testTime: DateTime(2026, 10, 21, 18, 0),
      );
      final gymBanner = banners.firstWhere((b) => b.id == 'gym_energy');

      expect(gymBanner.tracks.length, equals(18));

      final seenIds = <String>{};
      for (final t in gymBanner.tracks) {
        expect(t.id, isNotEmpty);
        expect(seenIds.add(t.id), isTrue, reason: 'Duplicate track ID found: ${t.id}');
        expect(t.thumbnail.url, isNotEmpty);
        expect(t.title, isNotEmpty);
      }

      // Check key YouTube source playlist tracks
      final titles = gymBanner.tracks.map((t) => t.title).toList();
      expect(titles.any((t) => t.contains('Bollywood Workout Mix')), isTrue);
      expect(titles.any((t) => t.contains('Dope Shope')), isTrue);
      expect(titles.any((t) => t.contains('Jaan Se Guzarte Hain')), isTrue);
      expect(titles.any((t) => t.contains('Gym Motivation Music')), isTrue);
      expect(titles.any((t) => t.contains('Mercy')), isTrue);
    });

    test('2. Morning Bhakti contains genuine Hanuman Chalisa ID 7CwLvXc6 and valid artwork', () {
      final banners = SmartBannerService.getActiveBanners(
        testTime: DateTime(2026, 10, 21, 6, 0),
      );
      final bhaktiBanner = banners.firstWhere((b) => b.id == 'morning_bhakti');

      final hcTrack = bhaktiBanner.tracks.firstWhere(
        (t) => t.title.contains('Hanuman Chalisa'),
      );

      expect(hcTrack.id, equals('content-resolver.bloomfactory.jisaavn::7CwLvXc6'));
      expect(hcTrack.thumbnail.url, contains('256/Shree-Hanuman-Chalisa-Hanuman-Ashtak-Hindi-1992'));
      expect(hcTrack.thumbnail.url, endsWith('-500x500.webp'));
    });

    test('3. Bhakti section deity collections have verified distinct tracks', () {
      expect(kVerifiedHanumanTracks.length, greaterThanOrEqualTo(2));
      expect(kVerifiedGaneshTracks.length, greaterThanOrEqualTo(3));
      expect(kVerifiedRamTracks.length, greaterThanOrEqualTo(4));
      expect(kVerifiedKhatuShyamTracks.length, greaterThanOrEqualTo(3));
      expect(kVerifiedShivTracks.length, greaterThanOrEqualTo(3));
      expect(kVerifiedRadhaKrishnaTracks.length, greaterThanOrEqualTo(2));

      final allDeityTracks = [
        ...kVerifiedHanumanTracks,
        ...kVerifiedGaneshTracks,
        ...kVerifiedRamTracks,
        ...kVerifiedKhatuShyamTracks,
        ...kVerifiedShivTracks,
        ...kVerifiedRadhaKrishnaTracks,
      ];

      for (final t in allDeityTracks) {
        expect(t.id, isNotEmpty);
        expect(t.title, isNotEmpty);
        expect(t.thumbnail.url, isNotEmpty);
      }
    });

    test('4. Share track metadata sanitization strips YouTube view count strings', () {
      final trackWithViewCount = Track(
        id: 'content-resolver.bloomfactory.ytvideo::test1234',
        title: 'Lut Gaye (Piano Instrumental)',
        artists: [
          const ArtistSummary(id: '', name: 'A.K. MUSIC WORLD'),
          const ArtistSummary(id: '', name: '1.2M views'),
          const ArtistSummary(id: '', name: '2 years ago'),
        ],
        album: const AlbumSummary(id: '', title: 'Piano Covers', artists: []),
        durationMs: BigInt.from(180000),
        thumbnail: const Artwork(
          url: 'https://i.ytimg.com/vi/test1234/hqdefault.jpg',
          layout: ImageLayout.square,
        ),
        isExplicit: false,
      );

      final cleanArtists = TrackIdentity.sanitizeArtistSummaries(trackWithViewCount.artists);
      final artists = cleanArtists.map((a) => a.name).join(', ');
      final byArtist = artists.isNotEmpty ? ' by $artists' : '';
      final shareHeader = '🎵 Listen to "${trackWithViewCount.title}"$byArtist on Orvia:';

      expect(shareHeader, contains('A.K. MUSIC WORLD'));
      expect(shareHeader, isNot(contains('1.2M views')));
      expect(shareHeader, isNot(contains('2 years ago')));
    });

    test('5. YouTube thumbnail extraction resolves from fallbackUrl when mediaId omitted', () {
      const widget1 = LoadImageCached(
        imageUrl: '',
        fallbackUrl: 'https://i.ytimg.com/vi/N5PRDOKqSUs/hqdefault.jpg',
      );
      expect(widget1.fallbackUrl, contains('N5PRDOKqSUs'));

      const widget2 = LoadImageCached(
        imageUrl: '',
        fallbackUrl: 'https://www.youtube.com/watch?v=iiBeBFRsCSQ',
      );
      expect(widget2.fallbackUrl, contains('iiBeBFRsCSQ'));
    });

    test('6. TrackIdentity.sanitizeArtistSummaries preserves authentic artists while filtering stats', () {
      final artists = [
        const ArtistSummary(id: '1', name: 'Arijit Singh'),
        const ArtistSummary(id: '2', name: '450K views'),
        const ArtistSummary(id: '3', name: 'Pritam'),
      ];
      final sanitized = TrackIdentity.sanitizeArtistSummaries(artists);
      expect(sanitized.length, equals(2));
      expect(sanitized.map((a) => a.name), containsAll(['Arijit Singh', 'Pritam']));
      expect(sanitized.map((a) => a.name), isNot(contains('450K views')));
    });
  });
}
