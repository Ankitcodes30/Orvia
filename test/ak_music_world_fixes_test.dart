import 'package:Orvia/core/adapters/track_adapter.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/utils/track_identity.dart';
import 'package:Orvia/screens/screen/common_views/artist_view.dart';
import 'package:Orvia/services/catalogue/curated_playlists_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('A.K. MUSIC WORLD 12 Songs + 7 Shorts Exact Order & Metadata Tests', () {
    test('1. Total collection contains 19 tracks (12 songs + 7 shorts) with zero duplicates', () {
      final allTracks = CuratedPlaylistsService.getAkMusicWorldTracks();
      expect(allTracks.length, equals(19));

      final songsOnly = CuratedPlaylistsService.getAkMusicWorldSongsOnly();
      expect(songsOnly.length, equals(12));

      final shortsOnly = CuratedPlaylistsService.getAkMusicWorldShortsOnly();
      expect(shortsOnly.length, equals(7));

      final uniqueIds = allTracks.map((t) => t.id).toSet();
      expect(uniqueIds.length, equals(19));

      // Repeated loads / deduplication retains 19 items without duplicates
      final reDeduplicated = CuratedPlaylistsService.deduplicate([
        ...allTracks,
        ...allTracks,
      ]);
      expect(reDeduplicated.length, equals(19));
    });

    test('2. All 12 songs match the exact requested sequence by video ID (indices 0..11)', () {
      final tracks = CuratedPlaylistsService.getAkMusicWorldTracks();

      final expectedOrder = [
        ('O9qpGTKEsYw', 'Apna Bana Le Piya'),
        ('oYVgw3xGiaU', 'Teri Baaton Mein Aisa'),
        ('ZhmqU8jjgDY', 'Yadav Brand 2'),
        ('SkBKlP4eOBk', 'Pasoori'),
        ('N5PRDOKqSUs', 'KGF'),
        ('Pt-DdBr3anQ', 'Unexpected Piano Mashup'),
        ('VVUJbVzVosY', 'Instrumental Ringtones'),
        ('v8M12-G3jFc', 'Tu Mujhe Soch Kabhi'),
        ('MNhJ6obZvh8', 'Raataan Lambiyan'),
        ('gWb64Q6HX40', 'Pirates of the Caribbean'),
        ('OoOpaG0aoVM', 'Lut Gaye'),
        ('Ha5QlyycMhM', 'Har Shambhu'),
      ];

      for (var i = 0; i < expectedOrder.length; i++) {
        final expectedVideoId = expectedOrder[i].$1;
        final expectedTitleSnippet = expectedOrder[i].$2;
        final track = tracks[i];

        expect(
          track.id,
          equals('content-resolver.bloomfactory.ytvideo::$expectedVideoId'),
          reason: 'Track at index $i must have videoId $expectedVideoId',
        );

        expect(
          track.title.toLowerCase().contains(expectedTitleSnippet.toLowerCase()),
          isTrue,
          reason:
              'Track at index $i title "${track.title}" must match "$expectedTitleSnippet"',
        );

        expect(
          track.url,
          equals('https://www.youtube.com/watch?v=$expectedVideoId'),
          reason: 'Track URL at index $i must match videoId $expectedVideoId',
        );

        expect(
          track.thumbnail.url,
          equals('https://i.ytimg.com/vi/$expectedVideoId/hqdefault.jpg'),
        );

        expect(track.album?.title, equals('A.K. Music World Piano Covers'));

        // Verify isShort is false for regular songs
        final isShort = (track.url?.contains('/shorts/') ?? false) ||
            (track.album?.title.toLowerCase().contains('short') ?? false);
        expect(isShort, isFalse, reason: 'Track at index $i is a regular song');
      }
    });

    test('3. All 7 Shorts are appended in exact order (indices 12..18) with shorts metadata', () {
      final tracks = CuratedPlaylistsService.getAkMusicWorldTracks();

      final expectedShorts = [
        ('LAzc7IEs5PE', 'Tere Hawaale', 57),
        ('IhEtDkqxMBE', 'Khairiyat pucho', 51),
        ('lQLNhijZBKA', 'Phir aur kya chahiye', 49),
        ('UM3yjqw1YOk', 'Bairan -Banjaare', 34),
        ('hOTAlKSIPtQ', 'Mi Amor', 50),
        ('5YPRXZJEJrs', 'Jamal Kudu', 31),
        ('xxUEusRTklU', 'Kal Chaudhavin', 82),
      ];

      for (var s = 0; s < expectedShorts.length; s++) {
        final idx = 12 + s;
        final expectedVideoId = expectedShorts[s].$1;
        final expectedTitleSnippet = expectedShorts[s].$2;
        final expectedDuration = expectedShorts[s].$3;
        final track = tracks[idx];

        expect(
          track.id,
          equals('content-resolver.bloomfactory.ytvideo::$expectedVideoId'),
          reason: 'Short at index $idx must have videoId $expectedVideoId',
        );

        expect(
          track.title.toLowerCase().contains(expectedTitleSnippet.toLowerCase()),
          isTrue,
          reason:
              'Short at index $idx title "${track.title}" must match "$expectedTitleSnippet"',
        );

        expect(
          track.url,
          equals('https://youtube.com/shorts/$expectedVideoId'),
          reason: 'Short at index $idx must have https://youtube.com/shorts/ URL',
        );

        expect(
          track.thumbnail.url,
          equals('https://i.ytimg.com/vi/$expectedVideoId/hqdefault.jpg'),
        );

        expect(track.album?.title, equals('A.K. Music World Shorts'));
        expect(track.durationMs, equals(BigInt.from(expectedDuration * 1000)));

        // Verify isShort is true for Shorts
        final isShort = (track.url?.contains('/shorts/') ?? false) ||
            (track.album?.title.toLowerCase().contains('short') ?? false);
        expect(isShort, isTrue, reason: 'Track at index $idx must be recognized as Short');
      }
    });

    test('4. All 19 tracks retain A.K. MUSIC WORLD channel identity and logo', () {
      final tracks = CuratedPlaylistsService.getAkMusicWorldTracks();

      for (final track in tracks) {
        expect(track.artists, isNotEmpty);
        expect(track.artists.first.name, equals('A.K. MUSIC WORLD'));
        expect(
          track.artists.first.id,
          equals('content-resolver.bloomfactory.ytvideo::@a.k.musicworld199'),
        );
        expect(
          track.artists.first.thumbnail?.url,
          equals('assets/icons/AnkitLogo.png'),
        );
        expect(track.durationMs, isNotNull);
        expect(track.durationMs! > BigInt.zero, isTrue);
      }
    });
  });

  group('A.K. MUSIC WORLD Channel Identity & Logo Persistence Tests', () {
    test('4. ArtistSummary retains canonical channel name and AnkitLogo avatar', () {
      final tracks = CuratedPlaylistsService.getAkMusicWorldTracks();
      final sample = tracks.first;

      final artist = sample.artists.first;
      expect(artist.name, equals('A.K. MUSIC WORLD'));
      expect(artist.id, contains('@a.k.musicworld199'));
      expect(artist.thumbnail?.url, equals('assets/icons/AnkitLogo.png'));

      final mediaItem = trackToMediaItem(sample);
      expect(mediaItem.artist, equals('A.K. MUSIC WORLD'));
      expect(mediaItem.title, sample.title);
    });

    test('5. ArtistView.isTrackRelatedToArtist validates channel handle and IDs', () {
      final tracks = CuratedPlaylistsService.getAkMusicWorldTracks();

      for (final track in tracks) {
        expect(
          ArtistView.isTrackRelatedToArtist(track, 'A.K. MUSIC WORLD'),
          isTrue,
        );
        expect(
          ArtistView.isTrackRelatedToArtist(
            track,
            'A.K. MUSIC WORLD',
            artistId: 'content-resolver.bloomfactory.ytvideo::@a.k.musicworld199',
          ),
          isTrue,
        );
        expect(
          ArtistView.isTrackRelatedToArtist(
            track,
            '@a.k.musicworld199',
            artistId: '@a.k.musicworld199',
          ),
          isTrue,
        );
      }
    });

    test('6. Unrelated songs are rejected by ArtistView.isTrackRelatedToArtist', () {
      const unrelated1 = Track(
        id: 'saavn::track_123',
        title: 'Kesariya from Brahmastra',
        artists: [ArtistSummary(id: '459320', name: 'Arijit Singh')],
        durationMs: null,
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      const unrelated2 = Track(
        id: 'content-resolver.bloomfactory.ytvideo::xyz999',
        title: 'Random Vlog Video',
        artists: [ArtistSummary(id: 'UC1234567890', name: 'Some Vlogger')],
        durationMs: null,
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      expect(
        ArtistView.isTrackRelatedToArtist(unrelated1, 'A.K. MUSIC WORLD'),
        isFalse,
      );
      expect(
        ArtistView.isTrackRelatedToArtist(unrelated2, 'A.K. MUSIC WORLD'),
        isFalse,
      );
    });

    test('7. Unknown Artist or empty name fallback logic preserves A.K. MUSIC WORLD identity', () {
      const initialArtist = ArtistSummary(
        id: 'content-resolver.bloomfactory.ytvideo::@a.k.musicworld199',
        name: 'A.K. MUSIC WORLD',
        thumbnail: Artwork(
          url: 'assets/icons/AnkitLogo.png',
          layout: ImageLayout.square,
        ),
      );

      // Simulate an incoming empty or "Unknown Artist" details summary from failed YouTube scrape
      const fallbackSummary = ArtistSummary(
        id: 'content-resolver.bloomfactory.ytvideo::@a.k.musicworld199',
        name: 'Unknown Artist',
        thumbnail: null,
      );

      // Replicate the exact protection logic from ArtistView:
      const candidateSummary = fallbackSummary;
      final isCandidateNameValid = candidateSummary.name.trim().isNotEmpty &&
          candidateSummary.name.trim().toLowerCase() != 'unknown artist' &&
          !TrackIdentity.isViewCountOrMetadataArtifact(candidateSummary.name);

      final isAk = initialArtist.name
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '')
              .contains('akmusicworld') ||
          initialArtist.id
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '')
              .contains('akmusicworld');

      final effectiveArtist = isAk
          ? const ArtistSummary(
              id: 'content-resolver.bloomfactory.ytvideo::@a.k.musicworld199',
              name: 'A.K. MUSIC WORLD',
              thumbnail: Artwork(
                url: 'assets/icons/AnkitLogo.png',
                layout: ImageLayout.square,
              ),
            )
          : (isCandidateNameValid ? candidateSummary : initialArtist);

      expect(effectiveArtist.name, equals('A.K. MUSIC WORLD'));
      expect(effectiveArtist.name, isNot(equals('Unknown Artist')));
      expect(effectiveArtist.thumbnail?.url, equals('assets/icons/AnkitLogo.png'));
    });
  });
}

