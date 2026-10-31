import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/screens/screen/common_views/artist_view.dart';
import 'package:Orvia/screens/widgets/navratri_special_card.dart';
import 'package:Orvia/screens/widgets/bhakti_section.dart';
import 'package:Orvia/services/banner/smart_banner_service.dart';
import 'package:Orvia/services/account/account_service.dart';
import 'package:Orvia/services/catalogue/curated_playlists_service.dart';
import 'package:Orvia/services/share/orvia_deep_link_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2 & Master Audit Enhancements Tests', () {
    test(
        '1. ArtistView.isTrackRelatedToArtist matches channel handle and track titles',
        () {
      const track1 = Track(
        id: 'content-resolver.bloomfactory.ytvideo::Ha5QlyycMhM',
        title: 'Har Shambhu song on piano || हर हर शंभू || A.K. MUSIC WORLD',
        artists: [
          ArtistSummary(id: '@a.k.musicworld199', name: 'A.K. MUSIC WORLD')
        ],
        durationMs: null,
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      final matchesName = ArtistView.isTrackRelatedToArtist(
        track1,
        'A.K. MUSIC WORLD',
        artistId: '@a.k.musicworld199',
      );
      expect(matchesName, isTrue);

      final matchesHandle = ArtistView.isTrackRelatedToArtist(
        track1,
        '@a.k.musicworld199',
        artistId: '@a.k.musicworld199',
      );
      expect(matchesHandle, isTrue);

      final kgfTrack = CuratedPlaylistsService.getAkMusicWorldTracks()
          .firstWhere((track) => track.id.contains('N5PRDOKqSUs'));
      expect(
        ArtistView.isTrackRelatedToArtist(
          kgfTrack,
          'A.K. MUSIC WORLD',
          artistId:
              'content-resolver.bloomfactory.ytvideo::UC55Gz5tT6m3_rWd3l1_PjXw',
        ),
        isTrue,
      );
    });

    test('2. buildTrackDeepLink outputs video thumbnail and not channel avatar',
        () {
      const ytTrack = Track(
        id: 'content-resolver.bloomfactory.ytvideo::macdUAgZTpY',
        title: 'Bigdi Meri Bana De',
        artists: [ArtistSummary(id: '', name: 'Lakhbir Singh Lakkha')],
        thumbnail: Artwork(
          url: 'https://yt3.ggpht.com/channel_avatar_123.jpg',
          urlHigh: 'https://yt3.ggpht.com/channel_avatar_123.jpg',
          layout: ImageLayout.square,
        ),
        isExplicit: false,
      );

      final uri = OrviaDeepLinkService.buildTrackDeepLink(ytTrack);
      expect(uri.queryParameters['thumb'],
          contains('i.ytimg.com/vi/macdUAgZTpY/hqdefault.jpg'));
    });

    test(
        '2a. buildTrackDeepLink prefers track artwork over a channel-avatar high-res URL',
        () {
      const ytTrack = Track(
        id: 'content-resolver.bloomfactory.ytvideo::abc12345678',
        title: 'Track with distinct artwork',
        artists: [ArtistSummary(id: '', name: 'Artist')],
        thumbnail: Artwork(
          url: 'https://cdn.example.com/track-artwork.jpg',
          urlHigh: 'https://yt3.ggpht.com/channel_avatar.jpg',
          urlLow: 'https://cdn.example.com/track-artwork-small.jpg',
          layout: ImageLayout.square,
        ),
        isExplicit: false,
      );

      final uri = OrviaDeepLinkService.buildTrackDeepLink(ytTrack);
      expect(
        uri.queryParameters['thumb'],
        equals('https://cdn.example.com/track-artwork.jpg'),
      );
    });

    test(
        '3. kVerifiedNavratriTracks contains verified devotional tracks with active URLs',
        () {
      final titles =
          kVerifiedNavratriTracks.map((item) => item.track.title).toList();
      expect(titles, contains('Dulhaniya Re'));
      expect(titles, contains('Aalha Ki Dhwaja Nahin Aayi'));
      expect(titles, contains('Bigdi Meri Bana De Oo Sherawali Maiya'));
      expect(titles, contains('Nach Rahi Hai Kali Angana Mein'));
      expect(titles, contains('Angna Padharo Maharani'));

      final dulhaniya = kVerifiedNavratriTracks
          .firstWhere((t) => t.track.title == 'Dulhaniya Re');
      expect(dulhaniya.track.thumbnail.url,
          contains('580/Dulhaniya-Re-Hindi-2023-20250511164359-500x500.jpg'));
    });

    test('4. kVerifiedBhaktiTracks contains verified active 500x500 URLs', () {
      final pyara = kVerifiedBhaktiTracks
          .firstWhere((t) => t.title == 'Pyara Saja Hai Tera Dwar');
      expect(
          pyara.thumbnail.url,
          contains(
              '150/Pyara-Saja-Hai-Tera-Dwar-Bhawani-Hindi-1997-20230807154137-500x500.jpg'));

      final maiya = kVerifiedBhaktiTracks
          .firstWhere((t) => t.title == 'Maiya Ka Chola Hai Rangla');
      expect(
          maiya.thumbnail.url,
          contains(
              '094/Maiya-Ka-Chola-Hai-Rangla-Hindi-1996-20250707161916-500x500.jpg'));
    });

    test(
        '5. SmartBannerService provides time-aware banners according to local hour and excludes Night Calm',
        () {
      // 23:00 (11 PM) -> Night Calm must be completely absent.
      final nightBanners = SmartBannerService.getActiveBanners(
        testTime: DateTime(2026, 10, 21, 23, 0),
      );
      expect(nightBanners.any((b) => b.id == 'night_calm'), isFalse);

      // 06:00 (6 AM) -> Morning Bhakti should be active
      final morningBanners = SmartBannerService.getActiveBanners(
        testTime: DateTime(2026, 10, 21, 6, 0),
      );
      expect(morningBanners.any((b) => b.id == 'morning_bhakti'), isTrue);

      // 18:00 (6 PM) -> Gym Energy should be active
      final gymBanners = SmartBannerService.getActiveBanners(
        testTime: DateTime(2026, 10, 21, 18, 0),
      );
      expect(gymBanners.any((b) => b.id == 'gym_energy'), isTrue);
    });

    test(
        '6. AccountService keeps guest mode when no authentication backend exists',
        () async {
      final service = AccountService.instance;
      expect(service.isGuest, isTrue);
      expect(service.currentUser.value.displayName, equals('Guest Listener'));

      await expectLater(
        service.signInWithEmail('testuser@orvia.app', 'password123'),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        service.signInWithGoogle(),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        service.backupToCloud(),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        service.restoreFromCloud(),
        throwsA(isA<UnsupportedError>()),
      );
      expect(service.isGuest, isTrue);

      await service.signOut();
      expect(service.isGuest, isTrue);
    });

    test(
        '7. Night Calm is absent, Morning Bhakti has Hanuman Chalisa, Gym Energy has source tracks',
        () {
      final allBanners = SmartBannerService.getActiveBanners(
        testTime: DateTime(2026, 10, 21, 23, 0),
      );
      expect(allBanners.any((b) => b.id == 'night_calm'), isFalse);

      final morning = SmartBannerService.getActiveBanners(
        testTime: DateTime(2026, 10, 21, 6, 0),
      ).firstWhere((b) => b.id == 'morning_bhakti');
      expect(morning.tracks.any((t) => t.title.contains('Hanuman Chalisa')),
          isTrue);

      final gym = SmartBannerService.getActiveBanners(
        testTime: DateTime(2026, 10, 21, 18, 0),
      ).firstWhere((b) => b.id == 'gym_energy');
      expect(gym.tracks.any((t) => t.title.contains('Bollywood Workout Mix')), isTrue);
      expect(gym.tracks.any((t) => t.title.contains('Dope Shope')), isTrue);
    });

    test(
        '8. Festival banner automatically activates during window and expires after endDate',
        () {
      final festiveBanner = SmartBannerItem(
        id: 'navratri_test',
        title: 'Navratri Special',
        subtitle: 'Dandiya Raas',
        badge: 'FESTIVE',
        imageUrl:
            'https://c.saavncdn.com/401/Loveyatri-A-Journey-Of-Love-Hindi-2018-20181003-500x500.jpg',
        gradientColors: [Colors.purple, Colors.black],
        tracks: const [],
        activeHours: const [20, 21, 22],
        priority: 99,
        startDate: DateTime(2026, 9, 25),
        endDate: DateTime(2026, 10, 6, 23, 59, 59),
      );

      // Active during festival on Oct 1 at 20:00
      expect(
          festiveBanner.isEligibleAt(20, DateTime(2026, 10, 1, 20, 0)), isTrue);

      // Inactive before festival on Sept 20 at 20:00
      expect(festiveBanner.isEligibleAt(20, DateTime(2026, 9, 20, 20, 0)),
          isFalse);

      // Expired after festival on Oct 7 at 20:00
      expect(festiveBanner.isEligibleAt(20, DateTime(2026, 10, 7, 20, 0)),
          isFalse);
    });

    test('9. SmartBannerItem.fromJson parses JSON payload accurately', () {
      final json = {
        'id': 'remote_test',
        'title': 'Remote Title',
        'subtitle': 'Remote Sub',
        'badge': 'NEW',
        'imageUrl': 'https://c.saavncdn.com/test.jpg',
        'gradientColors': ['#FF0000', '#0000FF'],
        'activeHours': [10, 11, 12],
        'priority': 75,
        'tracks': [
          {
            'rawId': '123',
            'title': 'Remote Track',
            'artist': 'Remote Artist',
            'album': 'Remote Album',
            'durationSec': 180,
            'imageUrl': 'https://c.saavncdn.com/thumb.jpg',
          }
        ]
      };

      final parsed = SmartBannerItem.fromJson(json);
      expect(parsed.id, equals('remote_test'));
      expect(parsed.title, equals('Remote Title'));
      expect(parsed.tracks.length, equals(1));
      expect(parsed.tracks.first.title, equals('Remote Track'));
      expect(parsed.activeHours, contains(11));
    });
  });
}
