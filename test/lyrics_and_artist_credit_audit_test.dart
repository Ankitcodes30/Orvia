import 'package:flutter_test/flutter_test.dart';
import 'package:Orvia/core/models/exported.dart' hide Lyrics;
import 'package:Orvia/core/models/lyrics_models.dart';
import 'package:Orvia/screens/screen/common_views/artist_view.dart';
import 'package:Orvia/services/lyrics/lrclib_lyrics_service.dart';

void main() {
  group('1. Lyrics Engine & LRC Synchronized Parser Audit', () {
    test('Correctly parses LRCLIB format without spaces after timestamps', () {
      const rawLrc = '[00:11.20]Hum tere bin ab reh nahi sakte\n'
          '[00:18.50]Tere bina kya wajood mera\n'
          '[01:05.120]Tujhse juda agar ho jayenge';

      final parsed = ParsedLyrics(syncedLyrics: rawLrc, duration: '240');
      expect(parsed.lyrics.length, 3);

      expect(parsed.lyrics[0].start.inMilliseconds, 11200);
      expect(parsed.lyrics[0].text, 'Hum tere bin ab reh nahi sakte');

      expect(parsed.lyrics[1].start.inMilliseconds, 18500);
      expect(parsed.lyrics[1].text, 'Tere bina kya wajood mera');

      // 3-digit millisecond parsing
      expect(parsed.lyrics[2].start.inMilliseconds, 65120);
      expect(parsed.lyrics[2].text, 'Tujhse juda agar ho jayenge');
    });

    test('Correctly parses standard LRC format with spaces', () {
      const rawLrc = '[00:05.10] Line with space\n'
          '[00:10.00] Second line with space';

      final parsed = ParsedLyrics(syncedLyrics: rawLrc, duration: '60');
      expect(parsed.lyrics.length, 2);
      expect(parsed.lyrics[0].start.inMilliseconds, 5100);
      expect(parsed.lyrics[0].text, 'Line with space');
      expect(parsed.lyrics[1].start.inMilliseconds, 10000);
      expect(parsed.lyrics[1].text, 'Second line with space');
    });

    test('Ignores metadata headers and sorts out-of-order timestamps', () {
      const rawLrc = '[ar:Arijit Singh]\n'
          '[ti:Tum Hi Ho]\n'
          '[00:20.00]Later line\n'
          '[00:05.00]Earlier line\n'
          '[al:Aashiqui 2]';

      final parsed = ParsedLyrics(syncedLyrics: rawLrc, duration: '120');
      expect(parsed.lyrics.length, 2);
      expect(parsed.lyrics[0].start.inMilliseconds, 5000);
      expect(parsed.lyrics[0].text, 'Earlier line');
      expect(parsed.lyrics[1].start.inMilliseconds, 20000);
      expect(parsed.lyrics[1].text, 'Later line');
    });

    test('Lyrics constructor safely preserves plain lyrics when synced is empty or invalid', () {
      final lyrics = Lyrics(
        id: 'track1',
        title: 'Instrumental Song',
        artist: 'Artist',
        lyricsPlain: 'Plain text lyrics only without timestamps',
        lyricsSynced: '[ar:MetadataOnlyHeader]',
        provider: LyricsProvider.plugin,
      );

      expect(lyrics.parsedLyrics, isNull);
      expect(lyrics.lyricsPlain, 'Plain text lyrics only without timestamps');
    });

    test('LrclibLyricsService sanitizes song titles for high query precision', () {
      expect(
        LrclibLyricsService.sanitizeTitle(
            'Tum Hi Ho (From "Aashiqui 2") [Official Video]'),
        'Tum Hi Ho',
      );
      expect(
        LrclibLyricsService.sanitizeTitle(
            'Chura Liya Hai Tumne Jo Dil Ko (Remastered 2022)'),
        'Chura Liya Hai Tumne Jo Dil Ko',
      );
    });
  });

  group('2. Artist Credit Accuracy & Role Separation Audit', () {
    test('Matches authentic singer credit for primary and featured artists', () {
      const track = Track(
        id: 'saavn::JLGhq6Do',
        title: 'Chura Liya Hai Tumne Jo Dil Ko',
        artists: [
          ArtistSummary(id: '455166', name: 'Asha Bhosle'),
          ArtistSummary(id: '505312', name: 'Mohammed Rafi'),
        ],
        album: AlbumSummary(id: 'alb1', title: 'Yaadon Ki Baaraat', artists: []),
        thumbnail: Artwork(url: 'https://saavn.com/art.jpg', layout: ImageLayout.square),
        isExplicit: false,
      );

      // Both genuine singers match
      expect(ArtistView.isTrackRelatedToArtist(track, 'Asha Bhosle'), isTrue);
      expect(ArtistView.isTrackRelatedToArtist(track, 'Mohammed Rafi'), isTrue);

      // Uncredited artist is rejected
      expect(ArtistView.isTrackRelatedToArtist(track, 'Lata Mangeshkar'), isFalse);
    });

    test('Rejects non-vocal-only contributor roles (composer, lyricist, producer)', () {
      const track = Track(
        id: 'saavn::track_credits',
        title: 'Kabhie Kabhie Mere Dil Mein',
        artists: [
          ArtistSummary(id: '1', name: 'Mukesh'),
          ArtistSummary(id: '2', name: 'Sahir Ludhianvi (Lyricist)'),
          ArtistSummary(id: '3', name: 'Khayyam (Music Director)'),
        ],
        album: AlbumSummary(id: 'alb_kabhie', title: 'Kabhi Kabhie', artists: []),
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      // Mukesh (performer/singer) matches
      expect(ArtistView.isTrackRelatedToArtist(track, 'Mukesh'), isTrue);

      // Pure lyricist and music director are rejected from singer songs list
      expect(ArtistView.isTrackRelatedToArtist(track, 'Sahir Ludhianvi'), isFalse);
      expect(ArtistView.isTrackRelatedToArtist(track, 'Khayyam'), isFalse);
    });

    test('Permits dual-role contributors who also perform vocal roles', () {
      const track = Track(
        id: 'saavn::dual_role',
        title: 'Maa Tujhe Salaam',
        artists: [
          ArtistSummary(id: '456269', name: 'A. R. Rahman (Singer & Composer)'),
        ],
        album: AlbumSummary(id: 'alb_vande', title: 'Vande Mataram', artists: []),
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      expect(ArtistView.isTrackRelatedToArtist(track, 'A. R. Rahman'), isTrue);
      expect(ArtistView.isTrackRelatedToArtist(track, 'AR Rahman'), isTrue);
    });

    test('Generic Asha Bhosle audit: Rejects "Run Down The City" without hardcoded guards', () {
      // In "Monica, O My Darling", the song "Run Down The City" is sung by Mikey McCleary,
      // composed by Achint. Asha Bhosle is NOT a singer on this track.
      const runDownTheCityTrack = Track(
        id: 'saavn::rdtc_99',
        title: 'Run Down The City',
        artists: [
          ArtistSummary(id: 'achint_1', name: 'Achint'),
          ArtistSummary(id: 'mikey_1', name: 'Mikey McCleary'),
        ],
        album: AlbumSummary(
          id: 'alb_monica',
          title: 'Monica, O My Darling (Original Soundtrack)',
          artists: [
            ArtistSummary(id: 'achint_1', name: 'Achint'),
          ],
        ),
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      // Must be rejected for Asha Bhosle generically
      expect(
        ArtistView.isTrackRelatedToArtist(
          runDownTheCityTrack,
          'Asha Bhosle',
          artistId: '455166',
        ),
        isFalse,
      );

      // Authentic Asha Bhosle song from the same era
      const piyaTuTrack = Track(
        id: 'saavn::piya_tu',
        title: 'Piya Tu Ab To Aaja',
        artists: [
          ArtistSummary(id: '455166', name: 'Asha Bhosle'),
          ArtistSummary(id: 'rd_burman', name: 'R. D. Burman'),
        ],
        album: AlbumSummary(id: 'alb_caravan', title: 'Caravan', artists: []),
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      expect(
        ArtistView.isTrackRelatedToArtist(
          piyaTuTrack,
          'Asha Bhosle',
          artistId: '455166',
        ),
        isTrue,
      );
    });

    test('Compilation album metadata isolation prevents false positive attribution', () {
      const compilationTrack = Track(
        id: 'saavn::comp_01',
        title: 'Unrelated Romantic Song',
        artists: [
          ArtistSummary(id: 'singer_x', name: 'Solo Independent Artist'),
        ],
        album: AlbumSummary(
          id: 'comp_alb',
          title: 'Best of 70s Compilation & Hits of Kishore Kumar',
          artists: [
            ArtistSummary(id: 'kishore_id', name: 'Kishore Kumar'),
          ],
        ),
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      // Because it is a compilation album, Kishore Kumar in album.artists must NOT be inherited!
      expect(
        ArtistView.isTrackRelatedToArtist(
          compilationTrack,
          'Kishore Kumar',
          artistId: 'kishore_id',
        ),
        isFalse,
      );
    });

    test('Title-matching fallback is disabled for regular singers but active for channel creators', () {
      // Third-party tribute song with singer in title
      const tributeTrack = Track(
        id: 'yt::tribute_1',
        title: 'Tribute to Lata Mangeshkar - Live Acoustic',
        artists: [
          ArtistSummary(id: 'random_yt', name: 'College Band'),
        ],
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      // Rejects Lata Mangeshkar because singer profile disables title-matching fallback
      expect(
        ArtistView.isTrackRelatedToArtist(tributeTrack, 'Lata Mangeshkar'),
        isFalse,
      );

      // YouTube Creator Channel: A.K. MUSIC WORLD with channel branding in title
      const akTrack = Track(
        id: 'yt::ak_01',
        title: 'Har Har Shambhu Shiv Mahadeva | A.K. MUSIC WORLD Piano',
        artists: [
          ArtistSummary(id: 'ak_channel', name: 'A.K. MUSIC WORLD'),
        ],
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      expect(
        ArtistView.isTrackRelatedToArtist(akTrack, 'A.K. MUSIC WORLD'),
        isTrue,
      );
      expect(
        ArtistView.isTrackRelatedToArtist(akTrack, '@a.k.musicworld199'),
        isTrue,
      );
    });
  });
}
