import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:Orvia/screens/widgets/bhakti_section.dart';
import 'package:Orvia/screens/widgets/diwali_special_card.dart';
import 'package:Orvia/screens/screen/offline_screen.dart';
import 'package:Orvia/services/catalogue/creators_choice_service.dart';
import 'package:Orvia/services/festival/festival_service.dart';
import 'package:Orvia/services/banner/smart_banner_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task 1: India Songs Exclusion from Carousel', () {
    test('SmartBanner disallowed IDs strictly block all india-songs variations', () {
      const disallowed = SmartBannerService.kDisallowedBannerIds;
      expect(disallowed.contains('india_songs'), isTrue);
      expect(disallowed.contains('india-songs'), isTrue);
      expect(disallowed.contains('india_songs_hotw'), isTrue);
      expect(disallowed.contains('india-songs-hotw'), isTrue);
    });

    test('Active smart banners pool strictly excludes India Songs banner', () {
      final banners = SmartBannerService.getActiveBanners();
      for (final b in banners) {
        final id = b.id.toLowerCase();
        final title = b.title.toLowerCase();
        expect(id.contains('india_songs'), isFalse);
        expect(id.contains('india-songs'), isFalse);
        expect(title, isNot(equals('india songs')));
      }
    });
  });

  group('Task 2: Diwali 2026 One-Time Window & Expiry Boundaries', () {
    // IST = UTC + 5:30
    // 5 Nov 2026 00:00:00 IST = 4 Nov 2026 18:30:00 UTC
    // 10 Nov 2026 23:59:59 IST = 10 Nov 2026 18:29:59 UTC
    // 11 Nov 2026 00:00:00 IST = 10 Nov 2026 18:30:00 UTC
    // 12 Nov 2026 12:00:00 IST = 12 Nov 2026 06:30:00 UTC
    // 5 Nov 2027 00:00:00 IST = 4 Nov 2027 18:30:00 UTC

    test('Active precisely at start moment: 5 Nov 2026 00:00:00 IST', () {
      final atStart = DateTime.utc(2026, 11, 4, 18, 30, 0);
      final active = FestivalService.getActiveOrUpcomingFestival(testTime: atStart);
      expect(active, isNotNull);
      expect(active!.id, equals('diwali_2026'));
      expect(active.isPromotedAt(atStart), isTrue);
      expect(active.isOngoingAt(atStart), isTrue);
    });

    test('Active at final moment: 10 Nov 2026 23:59:59 IST', () {
      final atEndMoment = DateTime.utc(2026, 11, 10, 18, 29, 59);
      final active = FestivalService.getActiveOrUpcomingFestival(testTime: atEndMoment);
      expect(active, isNotNull);
      expect(active!.id, equals('diwali_2026'));
      expect(active.isPromotedAt(atEndMoment), isTrue);
    });

    test('Expired at cutoff: 11 Nov 2026 00:00:00 IST', () {
      final atExpiry = DateTime.utc(2026, 11, 10, 18, 30, 0);
      final active = FestivalService.getActiveOrUpcomingFestival(testTime: atExpiry);
      expect(active?.id, isNot(equals('diwali_2026')),
          reason: 'Diwali banner must expire at 11 Nov 2026 00:00 IST');
    });

    test('Expired after cutoff: 12 Nov 2026 12:00:00 IST', () {
      final afterExpiry = DateTime.utc(2026, 11, 12, 6, 30, 0);
      final active = FestivalService.getActiveOrUpcomingFestival(testTime: afterExpiry);
      expect(active?.id, isNot(equals('diwali_2026')));
    });

    test('Does not recur in 2027: 5 Nov 2027 00:00:00 IST', () {
      final in2027 = DateTime.utc(2027, 11, 4, 18, 30, 0);
      final active = FestivalService.getActiveOrUpcomingFestival(testTime: in2027);
      expect(active?.id, isNot(equals('diwali_2026')),
          reason: 'Diwali 2026 is a one-time promotion that must never recur in 2027');
    });

    test('Diwali 19 curated tracks remain intact post-expiry', () {
      final tracks = FestivalService.getDiwaliTracks();
      expect(tracks.length, equals(19),
          reason: 'Collection tracks must remain preserved even after banner expires');
    });
  });

  group('Task 3: Diwali Festive Special Banner Artwork & 19 YouTube Tracks', () {
    test('Diwali banner assets exist in project assets with genuine files', () {
      final webpFile = File('assets/images/diwali_festive_banner.webp');
      final pngFile = File('assets/images/diwali_festive_banner.png');
      expect(webpFile.existsSync(), isTrue, reason: 'diwali_festive_banner.webp must exist');
      expect(pngFile.existsSync(), isTrue, reason: 'diwali_festive_banner.png must exist');
      expect(webpFile.lengthSync(), greaterThan(100000));
      expect(pngFile.lengthSync(), greaterThan(1000000));
    });

    test('Diwali Festive Special contains exact 19 tracks in verified order', () {
      const expectedIds = [
        'yWNPxS0sXnE',
        'z_e1d5_VVfw',
        '5k_2d_15f6Y',
        'nxRf-p8KWdM',
        'OgE62AQv5iA',
        '22bLNq6iCjU',
        '3TylP-ux8W0',
        'q5PmN7SuUkY',
        'wEU8mWwAcv0',
        'UuLkjyBKQE4',
        '6fQzvZpBzj8',
        'wVrz52oz_T8',
        'Ekymhpz8oUM',
        'txXXRMfp12w',
        'leVoi6kkp3o',
        'yFyP0dMx5cw',
        'H2r9M66CQPk',
        'oec7CXRAfeE',
        'dxVa3AaPvy8',
      ];

      expect(kVerifiedDiwaliTracks.length, equals(19));
      expect(FestivalService.getDiwaliTracks().length, equals(19));

      for (var i = 0; i < 19; i++) {
        final item = kVerifiedDiwaliTracks[i];
        final expectedVid = expectedIds[i];

        expect(item.track.id, equals('content-resolver.bloomfactory.ytvideo::$expectedVid'));
        expect(item.track.title.trim(), isNotEmpty);
        expect(item.track.artists, isNotEmpty);
        expect(item.track.durationMs, isNotNull);
        expect(item.track.durationMs! > BigInt.zero, isTrue);
        expect(item.track.thumbnail.url, startsWith('https://i.ytimg.com/vi/$expectedVid/'));
        expect(item.track.url, equals('https://www.youtube.com/watch?v=$expectedVid'));
      }
    });
  });

  group('Task 4: Morning Bhakti Expanded Catalogue (26 Tracks)', () {
    const expectedMorningBhaktiIds = [
      'content-resolver.bloomfactory.jisaavn::7CwLvXc6',
      'content-resolver.bloomfactory.jisaavn::Br3sv0l4',
      'content-resolver.bloomfactory.jisaavn::__MfaQW6',
      'content-resolver.bloomfactory.jisaavn::r5yioR-M',
      'content-resolver.bloomfactory.jisaavn::6o2XH_yQ',
      'content-resolver.bloomfactory.jisaavn::Ft5IeMlT',
      'content-resolver.bloomfactory.ytvideo::Ha5QlyycMhM',
      'content-resolver.bloomfactory.ytvideo::SMv8gp3I4Ao',
      'content-resolver.bloomfactory.ytvideo::bd8I6Ss5GNA',
      'content-resolver.bloomfactory.ytvideo::G_4b9m6boTw',
      'content-resolver.bloomfactory.ytvideo::kj7L8eEOTZE',
      'content-resolver.bloomfactory.ytvideo::9w9SVujBfxo',
      'content-resolver.bloomfactory.ytvideo::30YNd5fEGMo',
      'content-resolver.bloomfactory.ytvideo::Njyx5ZuwEHI',
      'content-resolver.bloomfactory.ytvideo::4CKpFcQdJXk',
      'content-resolver.bloomfactory.ytvideo::VAdQcL_Xgoc',
      'content-resolver.bloomfactory.ytvideo::eL-iQ3VHxwA',
      'content-resolver.bloomfactory.ytvideo::4DkNCgUXbig',
      'content-resolver.bloomfactory.ytvideo::Tl4bQBfOtbg',
      'content-resolver.bloomfactory.ytvideo::ne3Mjg1M-Uo',
      'content-resolver.bloomfactory.ytvideo::gdKm1fZzMgI',
      'content-resolver.bloomfactory.ytvideo::2yhvCgpNJiA',
      'content-resolver.bloomfactory.ytvideo::mXNudXlAEjw',
      'content-resolver.bloomfactory.ytvideo::GePN4-Cajvk',
      'content-resolver.bloomfactory.ytvideo::JX1_7HZGfeA',
      'content-resolver.bloomfactory.ytvideo::GEVvyIrQZnA',
    ];

    test('SmartBannerService exposes all 26 Morning Bhakti tracks in exact order', () {
      final tracks = SmartBannerService.morningBhaktiTracks;
      expect(tracks.length, equals(26));

      for (var i = 0; i < 26; i++) {
        expect(tracks[i].id, equals(expectedMorningBhaktiIds[i]));
        expect(tracks[i].title.trim(), isNotEmpty);
        expect(tracks[i].artists, isNotEmpty);
        expect(tracks[i].durationMs! > BigInt.zero, isTrue);
        expect(tracks[i].thumbnail.url, isNotEmpty);
      }

      // Confirm no duplicates
      final uniqueIds = tracks.map((t) => t.id).toSet();
      expect(uniqueIds.length, equals(26));
    });

    test('BhaktiSection kMorningBhaktiTracks contains matching 26 tracks', () {
      expect(kMorningBhaktiTracks.length, equals(26));
      for (var i = 0; i < 26; i++) {
        expect(kMorningBhaktiTracks[i].id, equals(expectedMorningBhaktiIds[i]));
      }
    });

    test('Morning Bhakti banner during 6:00-10:30 window serves all 26 tracks', () {
      final banners = SmartBannerService.getActiveBanners(
        testTime: DateTime(2026, 10, 21, 7, 0),
      );
      final morningBanner = banners.firstWhere((b) => b.id == 'morning_bhakti');
      expect(morningBanner.tracks.length, equals(26));
    });
  });

  group('Task 5: Offline Multi-Select Reset Across Tabs', () {
    test('OfflineScreen exposes clearSelectionIfActive static API safely', () {
      expect(() => OfflineScreen.clearSelectionIfActive(), returnsNormally);
    });
  });

  group('Task 6: Creator\'s Choice Catalogue Expansion to 70 Tracks', () {
    test('Creator\'s Choice contains exactly 70 verified tracks with 2 newly added YouTube tracks', () {
      final tracks = CreatorsChoiceService.getVerifiedTracks();
      expect(tracks.length, equals(70));
      expect(CreatorsChoiceService.playlistDescription, contains('70 curated melodies'));
      expect(CreatorsChoiceService.playlistDescription, contains('38 verified classic selections and 32 exclusive YouTube tracks'));

      // Check the 2 new tracks at indices 68 and 69 (last two tracks)
      final track69 = tracks[68];
      final track70 = tracks[69];

      expect(track69.id, equals('content-resolver.bloomfactory.ytvideo::cQq6iLF66Gc'));
      expect(track69.title, contains('Alfaaz'));
      expect(track69.artists.first.name, equals('Hamza Malik, Zain Zohaib'));

      expect(track70.id, equals('content-resolver.bloomfactory.ytvideo::LMnJp_dSdnw'));
      expect(track70.title, contains('DARKHAAST'));
      expect(track70.artists.first.name, equals('Arijit Singh, Sunidhi Chauhan, Mithoon'));

      // Ensure no duplicates exist in entire catalogue
      final ids = tracks.map((t) => t.id).toSet();
      expect(ids.length, equals(70));
    });
  });
}
