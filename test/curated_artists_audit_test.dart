import 'package:flutter_test/flutter_test.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/utils/track_identity.dart';
import 'package:Orvia/screens/screen/common_views/artist_view.dart';
import 'package:Orvia/screens/widgets/featured_artists_section.dart';
import 'package:Orvia/services/banner/smart_banner_service.dart';
import 'package:Orvia/services/catalogue/creators_choice_service.dart';
import 'package:Orvia/services/catalogue/curated_artists_service.dart';

void main() {
  group('Iconic Indian Artists Curated Catalogue Audit', () {
    test('Audit all curated artists for duplicate tracks and validity', () {
      final artists = [
        ('Mohammed Rafi', '505312', CuratedArtistsService.getMohammedRafiTracks()),
        ('Diljit Dosanjh', '468245', CuratedArtistsService.getDiljitDosanjhTracks()),
        ('Mukesh', '455867', CuratedArtistsService.getMukeshTracks()),
        ('Udit Narayan', '455127', CuratedArtistsService.getUditNarayanTracks()),
        ('Asha Bhosle', '455166', CuratedArtistsService.getAshaBhosleTracks()),
        ('Alka Yagnik', '455120', CuratedArtistsService.getAlkaYagnikTracks()),
        ('Falguni Pathak', '467616', CuratedArtistsService.getFalguniPathakTracks()),
      ];

      for (final (name, _, tracks) in artists) {
        expect(tracks, isNotEmpty, reason: '$name has empty curated tracks');

        // Check raw IDs
        final seenRawIds = <String>{};
        for (final t in tracks) {
          final isNew = seenRawIds.add(t.id);
          expect(isNew, isTrue, reason: 'Duplicate ID ${t.id} ("${t.title}") found in $name tracks');
        }

        // Check semantic keys
        final seenSemantic = <String>{};
        for (final t in tracks) {
          final semKey = TrackIdentity.computeSemanticKey(t);
          final isNewSem = seenSemantic.add(semKey);
          expect(isNewSem, isTrue, reason: 'Duplicate semantic song "$semKey" found in $name tracks');
        }

        // Check artwork
        for (final t in tracks) {
          expect(TrackIdentity.isValidArtworkUrl(t.thumbnail.url), isTrue,
              reason: 'Track "${t.title}" in $name has invalid artwork URL: ${t.thumbnail.url}');
        }
      }
    });

    test('All 17 featured Indian artists are present and valid in kFeaturedIndianArtists', () {
      expect(kFeaturedIndianArtists.length, equals(17));
      final ids = kFeaturedIndianArtists.map((a) => a.id).toSet();
      expect(ids.length, equals(17), reason: 'Duplicate artist IDs in kFeaturedIndianArtists');

      for (final a in kFeaturedIndianArtists) {
        expect(a.name, isNotEmpty);
        expect(a.id, isNotEmpty);
        expect(TrackIdentity.isValidArtworkUrl(a.imageUrl), isTrue,
            reason: 'Artist ${a.name} has invalid image: ${a.imageUrl}');
      }
    });

    test('Issue 1: Creator\'s Choice sliding banner uses exact custom asset image and 70 tracks', () {
      final banner = SmartBannerService.defaultCreatorsChoiceBanner;
      expect(banner.id, equals('creators_choice'));
      expect(banner.imageUrl, equals('assets/images/creators_choice_banner.webp'));
      expect(banner.destination, equals('creators_choice'));
      expect(banner.tracks.length, equals(70));
      expect(banner.priority, equals(95));
      expect(CreatorsChoiceService.getVerifiedTracks().length, equals(70));
    });

    test('Issue 2: Asha Bhosle profile filters out Run Down The City - Monica and preserves authentic tracks', () {
      // 1. Irrelevant tracks from Monica, O My Darling (2022) sung by other artists
      final runDownTrack = Track(
        id: 'saavn::run_down_1',
        title: 'Run Down The City',
        artists: [const ArtistSummary(id: 'achint_1', name: 'Achint, Mikey McCleary')],
        album: const AlbumSummary(id: 'monica_album', title: 'Monica, O My Darling', artists: []),
        durationMs: BigInt.from(180000),
        thumbnail: const Artwork(url: 'https://example.com/art.jpg', layout: ImageLayout.square),
        isExplicit: false,
      );

      final irrelevantMonicaTrack = Track(
        id: 'saavn::monica_theme_1',
        title: 'Monica, O My Darling (Theme)',
        artists: [const ArtistSummary(id: 'other_artist', name: 'Mikey McCleary')],
        album: const AlbumSummary(id: 'monica_album', title: 'Monica, O My Darling', artists: []),
        durationMs: BigInt.from(150000),
        thumbnail: const Artwork(url: 'https://example.com/art.jpg', layout: ImageLayout.square),
        isExplicit: false,
      );

      // 2. Authentic Asha Bhosle classic Piya Tu Ab To Aaja (Monica, O My Darling from Caravan 1971)
      final genuinePiyaTuTrack = Track(
        id: 'saavn::6hz_bMKx',
        title: 'Piya Tu Ab To Aaja',
        artists: [const ArtistSummary(id: '455166', name: 'Asha Bhosle, R.D. Burman')],
        album: const AlbumSummary(id: 'caravan_1', title: 'Caravan', artists: []),
        durationMs: BigInt.from(327000),
        thumbnail: const Artwork(url: 'https://example.com/art.jpg', layout: ImageLayout.square),
        isExplicit: false,
      );

      expect(
        ArtistView.isTrackRelatedToArtist(runDownTrack, 'Asha Bhosle', artistId: '455166'),
        isFalse,
        reason: 'Run Down The City must be rejected from Asha Bhosle profile',
      );
      expect(
        ArtistView.isTrackRelatedToArtist(irrelevantMonicaTrack, 'Asha Bhosle', artistId: '455166'),
        isFalse,
        reason: 'Irrelevant Monica track not performed by Asha Bhosle must be rejected',
      );
      expect(
        ArtistView.isTrackRelatedToArtist(genuinePiyaTuTrack, 'Asha Bhosle', artistId: '455166'),
        isTrue,
        reason: 'Authentic classic Piya Tu Ab To Aaja must be preserved',
      );
    });

    test('Issue 3: Duplicate songs with identical canonical identity are deduplicated while version variants are preserved', () {
      final trackOriginal = Track(
        id: 'saavn::original_1',
        title: 'Tum Hi Ho',
        artists: [const ArtistSummary(id: 'arijit_1', name: 'Arijit Singh')],
        album: const AlbumSummary(id: 'aashiqui2', title: 'Aashiqui 2', artists: []),
        durationMs: BigInt.from(262000),
        thumbnail: const Artwork(url: 'https://example.com/art1.jpg', layout: ImageLayout.square),
        isExplicit: false,
      );

      // Duplicate upload with different video / source ID
      final trackDuplicateUpload = Track(
        id: 'yt::different_video_id',
        title: 'Tum Hi Ho [Official Video]',
        artists: [const ArtistSummary(id: 'arijit_1', name: 'Arijit Singh')],
        album: const AlbumSummary(id: 'aashiqui2', title: 'Aashiqui 2', artists: []),
        durationMs: BigInt.from(262000),
        thumbnail: const Artwork(url: 'https://example.com/art2.jpg', layout: ImageLayout.square),
        isExplicit: false,
      );

      // Distinct version (Unplugged / Remix)
      final trackRemix = Track(
        id: 'saavn::remix_1',
        title: 'Tum Hi Ho (Remix)',
        artists: [const ArtistSummary(id: 'arijit_1', name: 'Arijit Singh')],
        album: const AlbumSummary(id: 'aashiqui2_remix', title: 'Aashiqui 2 Remixes', artists: []),
        durationMs: BigInt.from(240000),
        thumbnail: const Artwork(url: 'https://example.com/art3.jpg', layout: ImageLayout.square),
        isExplicit: false,
      );

      final deduplicated = TrackIdentity.deduplicateTracksSemantically([
        trackOriginal,
        trackDuplicateUpload,
        trackRemix,
      ]);

      expect(deduplicated.length, equals(2));
      expect(deduplicated[0].id, equals('saavn::original_1'));
      expect(deduplicated[1].id, equals('saavn::remix_1'));
    });
  });
}
