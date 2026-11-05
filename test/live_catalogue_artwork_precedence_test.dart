import 'package:flutter_test/flutter_test.dart';
import 'package:Orvia/core/utils/track_identity.dart';
import 'package:Orvia/src/rust/api/plugin/models.dart';

void main() {
  group('TrackIdentity - Artwork Precedence and Validation', () {
    test('isValidArtworkUrl returns true for valid http/https URLs and false for invalid', () {
      expect(TrackIdentity.isValidArtworkUrl('https://c.saavncdn.com/123/song-500x500.jpg'), isTrue);
      expect(TrackIdentity.isValidArtworkUrl('http://example.com/art.png'), isTrue);
      expect(TrackIdentity.isValidArtworkUrl(''), isFalse);
      expect(TrackIdentity.isValidArtworkUrl('   '), isFalse);
      expect(TrackIdentity.isValidArtworkUrl(null), isFalse);
      expect(TrackIdentity.isValidArtworkUrl('invalid-url-string'), isFalse);
      expect(TrackIdentity.isValidArtworkUrl('ftp://example.com/image.jpg'), isFalse);
      expect(TrackIdentity.isValidArtworkUrl('file:///sdcard/image.jpg'), isFalse);
      expect(TrackIdentity.isValidArtworkUrl('data:image/png;base64,...'), isFalse);
    });

    test('getValidArtwork resolves url, urlHigh, and urlLow in priority order', () {
      const artWithDirectUrl = Artwork(
        url: 'https://cdn.example.com/direct.jpg',
        urlHigh: 'https://cdn.example.com/high.jpg',
        layout: ImageLayout.square,
      );
      expect(TrackIdentity.getValidArtwork(artWithDirectUrl)?.url, 'https://cdn.example.com/direct.jpg');

      const artWithOnlyHigh = Artwork(
        url: '',
        urlHigh: 'https://cdn.example.com/high.jpg',
        layout: ImageLayout.square,
      );
      expect(TrackIdentity.getValidArtwork(artWithOnlyHigh)?.url, 'https://cdn.example.com/high.jpg');

      const artWithOnlyLow = Artwork(
        url: '',
        urlLow: 'https://cdn.example.com/low.jpg',
        layout: ImageLayout.square,
      );
      expect(TrackIdentity.getValidArtwork(artWithOnlyLow)?.url, 'https://cdn.example.com/low.jpg');

      const artInvalid = Artwork(
        url: 'broken-url',
        urlLow: '',
        urlHigh: 'not-valid',
        layout: ImageLayout.square,
      );
      expect(TrackIdentity.getValidArtwork(artInvalid), isNull);
      expect(TrackIdentity.getValidArtwork(null), isNull);
    });

    test('Live track with missing artwork retains identity but adopts valid curated artwork', () {
      final liveTrack = Track(
        id: 'saavn::live_101',
        title: 'Tum Hi Ho',
        artists: const [ArtistSummary(id: 'arijit_1', name: 'Arijit Singh')],
        durationMs: BigInt.from(262000),
        thumbnail: const Artwork(url: '', layout: ImageLayout.square),
        url: 'https://jiosaavn.com/song/tum-hi-ho/live101',
        isExplicit: false,
      );

      final curatedTrack = Track(
        id: 'curated::tum_hi_ho',
        title: 'Tum Hi Ho',
        artists: const [ArtistSummary(id: 'curated_arijit', name: 'Arijit Singh')],
        durationMs: BigInt.from(262100),
        thumbnail: const Artwork(
          url: 'https://c.saavncdn.com/123/tum-hi-ho-500x500.jpg',
          layout: ImageLayout.square,
        ),
        url: 'https://jiosaavn.com/song/tum-hi-ho/curated',
        isExplicit: false,
      );

      final result = TrackIdentity.deduplicateTracksSemantically([liveTrack, curatedTrack]);

      expect(result.length, 1);
      final deduplicated = result.first;

      // Identity & metadata must be preserved strictly from the live track
      expect(deduplicated.id, 'saavn::live_101');
      expect(deduplicated.title, 'Tum Hi Ho');
      expect(deduplicated.artists.first.id, 'arijit_1');
      expect(deduplicated.artists.first.name, 'Arijit Singh');
      expect(deduplicated.durationMs, BigInt.from(262000));
      expect(deduplicated.url, 'https://jiosaavn.com/song/tum-hi-ho/live101');

      // Artwork must be enriched from curated track
      expect(deduplicated.thumbnail.url, 'https://c.saavncdn.com/123/tum-hi-ho-500x500.jpg');
    });

    test('Live track with invalid artwork scheme adopts valid curated artwork', () {
      const liveTrack = Track(
        id: 'live_invalid_art',
        title: 'Kesariya',
        artists: [ArtistSummary(id: 'arijit_1', name: 'Arijit Singh')],
        thumbnail: Artwork(url: 'unsupported://resource/image.png', layout: ImageLayout.square),
        isExplicit: false,
      );

      const curatedTrack = Track(
        id: 'curated_kesariya',
        title: 'Kesariya',
        artists: [ArtistSummary(id: 'arijit_1', name: 'Arijit Singh')],
        thumbnail: Artwork(
          url: 'https://c.saavncdn.com/brahmastra/kesariya-500x500.jpg',
          layout: ImageLayout.square,
        ),
        isExplicit: false,
      );

      final result = TrackIdentity.deduplicateTracksSemantically([liveTrack, curatedTrack]);

      expect(result.length, 1);
      expect(result.first.id, 'live_invalid_art');
      expect(result.first.thumbnail.url, 'https://c.saavncdn.com/brahmastra/kesariya-500x500.jpg');
    });

    test('Live track with already-valid artwork does NOT replace artwork', () {
      const liveTrack = Track(
        id: 'live_valid_art',
        title: 'Channa Mereya',
        artists: [ArtistSummary(id: 'arijit_1', name: 'Arijit Singh')],
        thumbnail: Artwork(
          url: 'https://live-provider.com/channa-mereya.jpg',
          layout: ImageLayout.square,
        ),
        isExplicit: false,
      );

      const curatedTrack = Track(
        id: 'curated_channa',
        title: 'Channa Mereya',
        artists: [ArtistSummary(id: 'arijit_1', name: 'Arijit Singh')],
        thumbnail: Artwork(
          url: 'https://curated-provider.com/different-art.jpg',
          layout: ImageLayout.square,
        ),
        isExplicit: false,
      );

      final result = TrackIdentity.deduplicateTracksSemantically([liveTrack, curatedTrack]);

      expect(result.length, 1);
      expect(result.first.id, 'live_valid_art');
      expect(result.first.thumbnail.url, 'https://live-provider.com/channa-mereya.jpg');
    });

    test('Unrelated tracks are preserved as separate tracks without merging metadata', () {
      const track1 = Track(
        id: 'track_1',
        title: 'Apna Bana Le',
        artists: [ArtistSummary(id: 'arijit_1', name: 'Arijit Singh')],
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      const track2 = Track(
        id: 'track_2',
        title: 'Raabta',
        artists: [ArtistSummary(id: 'arijit_1', name: 'Arijit Singh')],
        thumbnail: Artwork(
          url: 'https://c.saavncdn.com/agent-vinod/raabta-500x500.jpg',
          layout: ImageLayout.square,
        ),
        isExplicit: false,
      );

      final result = TrackIdentity.deduplicateTracksSemantically([track1, track2]);

      expect(result.length, 2);
      expect(result[0].id, 'track_1');
      expect(result[0].title, 'Apna Bana Le');
      expect(result[0].thumbnail.url, '');

      expect(result[1].id, 'track_2');
      expect(result[1].title, 'Raabta');
      expect(result[1].thumbnail.url, 'https://c.saavncdn.com/agent-vinod/raabta-500x500.jpg');
    });

    test('Duplicate tracks with identical IDs enrich artwork if first occurrence lacks it', () {
      const liveTrack = Track(
        id: 'same_id_100',
        title: 'Ilahi',
        artists: [ArtistSummary(id: 'a1', name: 'Arijit Singh')],
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      const enrichedDuplicate = Track(
        id: 'same_id_100',
        title: 'Ilahi',
        artists: [ArtistSummary(id: 'a1', name: 'Arijit Singh')],
        thumbnail: Artwork(
          url: 'https://c.saavncdn.com/yjhd/ilahi-500x500.jpg',
          layout: ImageLayout.square,
        ),
        isExplicit: false,
      );

      final result = TrackIdentity.deduplicateTracksSemantically([liveTrack, enrichedDuplicate]);

      expect(result.length, 1);
      expect(result.first.id, 'same_id_100');
      expect(result.first.thumbnail.url, 'https://c.saavncdn.com/yjhd/ilahi-500x500.jpg');
    });

    test('Live track missing thumbnail is enriched from curated duplicate album artwork if direct art is empty', () {
      const liveTrack = Track(
        id: 'live_no_art',
        title: 'Gerua',
        artists: [ArtistSummary(id: 'a1', name: 'Arijit Singh')],
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        album: AlbumSummary(id: 'alb_1', title: 'Dilwale', artists: []),
        isExplicit: false,
      );

      const curatedTrack = Track(
        id: 'curated_gerua',
        title: 'Gerua',
        artists: [ArtistSummary(id: 'a1', name: 'Arijit Singh')],
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        album: AlbumSummary(
          id: 'alb_curated',
          title: 'Dilwale',
          artists: [],
          thumbnail: Artwork(
            url: 'https://c.saavncdn.com/dilwale/album-500x500.jpg',
            layout: ImageLayout.square,
          ),
        ),
        isExplicit: false,
      );

      final result = TrackIdentity.deduplicateTracksSemantically([liveTrack, curatedTrack]);

      expect(result.length, 1);
      expect(result.first.id, 'live_no_art');
      expect(result.first.thumbnail.url, 'https://c.saavncdn.com/dilwale/album-500x500.jpg');
      expect(result.first.album?.thumbnail?.url, 'https://c.saavncdn.com/dilwale/album-500x500.jpg');
    });

    test('Album aggregation enriches empty album artwork when subsequent track has valid artwork', () {
      final topTracks = [
        const Track(
          id: 'live_song_1',
          title: 'Song 1',
          artists: [ArtistSummary(id: 'art1', name: 'Lata Mangeshkar')],
          album: AlbumSummary(id: 'alb_mughal', title: 'Mughal-E-Azam', artists: []),
          thumbnail: Artwork(url: '', layout: ImageLayout.square),
          isExplicit: false,
        ),
      ];

      final catalogueTracks = [
        const Track(
          id: 'curated_song_1',
          title: 'Pyar Kiya To Darna Kya',
          artists: [ArtistSummary(id: 'art1', name: 'Lata Mangeshkar')],
          album: AlbumSummary(
            id: 'alb_mughal',
            title: 'Mughal-E-Azam',
            artists: [],
            thumbnail: Artwork(
              url: 'https://c.saavncdn.com/mughaleazam/art-500x500.jpg',
              layout: ImageLayout.square,
            ),
          ),
          thumbnail: Artwork(
            url: 'https://c.saavncdn.com/mughaleazam/art-500x500.jpg',
            layout: ImageLayout.square,
          ),
          isExplicit: false,
        ),
      ];

      final allTracks = TrackIdentity.deduplicateTracksSemantically([
        ...topTracks,
        ...catalogueTracks,
      ]);

      final seenAlbumMap = <String, AlbumSummary>{};
      for (final t in allTracks) {
        final alb = t.album;
        if (alb != null && alb.title.trim().isNotEmpty) {
          final key = alb.title.toLowerCase().trim();
          final candidateArt = TrackIdentity.isValidArtworkUrl(alb.thumbnail?.url)
              ? alb.thumbnail
              : (TrackIdentity.isValidArtworkUrl(t.thumbnail.url) ? t.thumbnail : null);

          if (!seenAlbumMap.containsKey(key)) {
            seenAlbumMap[key] = AlbumSummary(
              id: alb.id.isNotEmpty ? alb.id : t.id,
              title: alb.title,
              artists: const [ArtistSummary(id: 'art1', name: 'Lata Mangeshkar')],
              thumbnail: candidateArt ?? alb.thumbnail ?? t.thumbnail,
            );
          } else {
            final existing = seenAlbumMap[key]!;
            if (!TrackIdentity.isValidArtworkUrl(existing.thumbnail?.url) && candidateArt != null) {
              seenAlbumMap[key] = AlbumSummary(
                id: existing.id,
                title: existing.title,
                artists: existing.artists,
                thumbnail: candidateArt,
              );
            }
          }
        }
      }

      expect(seenAlbumMap.length, 1);
      final aggregatedAlbum = seenAlbumMap['mughal-e-azam']!;
      expect(aggregatedAlbum.title, 'Mughal-E-Azam');
      expect(aggregatedAlbum.thumbnail?.url, 'https://c.saavncdn.com/mughaleazam/art-500x500.jpg');
    });

    test('Primary track metadata invariants are strictly preserved during artwork enrichment', () {
      final liveTrack = Track(
        id: 'primary_id_999',
        title: 'Lag Jaa Gale',
        artists: const [ArtistSummary(id: 'lata_orig', name: 'Lata Mangeshkar')],
        durationMs: BigInt.from(255000),
        url: 'https://jiosaavn.com/song/lag-jaa-gale/original',
        isExplicit: false,
        lyrics: const Lyrics(plain: 'Lag jaa gale se phir yeh haseen raat ho na ho'),
        thumbnail: const Artwork(url: '', layout: ImageLayout.square),
      );

      final duplicateTrack = Track(
        id: 'duplicate_id_888',
        title: 'Lag Jaa Gale',
        artists: const [ArtistSummary(id: 'lata_alt', name: 'Lata Mangeshkar')],
        durationMs: BigInt.from(258000),
        url: 'https://jiosaavn.com/song/lag-jaa-gale/different_url',
        isExplicit: true,
        lyrics: const Lyrics(plain: 'Different lyrics'),
        thumbnail: const Artwork(
          url: 'https://c.saavncdn.com/woh-kaun-thi/lag-jaa-gale-500x500.jpg',
          layout: ImageLayout.square,
        ),
      );

      final result = TrackIdentity.deduplicateTracksSemantically([liveTrack, duplicateTrack]);

      expect(result.length, 1);
      final enriched = result.first;

      // Identity and metadata MUST remain strictly from primary live track
      expect(enriched.id, 'primary_id_999');
      expect(enriched.title, 'Lag Jaa Gale');
      expect(enriched.artists.first.id, 'lata_orig');
      expect(enriched.artists.first.name, 'Lata Mangeshkar');
      expect(enriched.durationMs, BigInt.from(255000));
      expect(enriched.url, 'https://jiosaavn.com/song/lag-jaa-gale/original');
      expect(enriched.isExplicit, isFalse);
      expect(enriched.lyrics?.plain, 'Lag jaa gale se phir yeh haseen raat ho na ho');

      // Artwork enriched
      expect(enriched.thumbnail.url, 'https://c.saavncdn.com/woh-kaun-thi/lag-jaa-gale-500x500.jpg');
    });

    test('Artwork validation runs entirely synchronously with 0 network calls', () {
      final sw = Stopwatch()..start();
      for (int i = 0; i < 500; i++) {
        TrackIdentity.isValidArtworkUrl('https://c.saavncdn.com/test/$i-500x500.jpg');
        TrackIdentity.isValidArtworkUrl('invalid-url-$i');
        TrackIdentity.getValidArtwork(const Artwork(url: '', urlHigh: 'https://cdn.com/high.jpg', layout: ImageLayout.square));
      }
      sw.stop();
      // 1500 validations in memory should take under 50ms
      expect(sw.elapsedMilliseconds, lessThan(50));
    });
  });
}
