import 'package:flutter_test/flutter_test.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/plugins/utils/media_id.dart';
import 'package:Orvia/plugins/utils/plugin_error_sanitizer.dart';
import 'package:Orvia/services/banner/smart_banner_service.dart';
import 'package:Orvia/services/catalogue/curated_artists_service.dart';
import 'package:Orvia/services/player/player_error_handler.dart';
import 'package:Orvia/blocs/library/cubit/library_items_cubit.dart';

void main() {
  group('Target 1 & 3: Iconic Indian Artists Catalog & Artwork Audit', () {
    test('All 7 expanded artists have exactly 15 curated tracks with valid metadata', () {
      final artists = [
        'Mohammed Rafi',
        'Diljit Dosanjh',
        'Mukesh',
        'Udit Narayan',
        'Asha Bhosle',
        'Alka Yagnik',
        'Falguni Pathak',
      ];

      for (final artistName in artists) {
        final tracks = CuratedArtistsService.getCuratedTracksForArtist(artistName);
        expect(tracks, isNotNull);
        expect(tracks!.length, equals(15), reason: '$artistName should have 15 tracks');

        for (final t in tracks) {
          expect(t.id, startsWith('$kDefaultSaavnPluginId::'));
          expect(t.title, isNotEmpty);
          expect(t.album?.title, isNotEmpty);
          expect(t.artists, isNotEmpty);
          expect(t.durationMs, isNotNull);
          expect((t.durationMs! > BigInt.zero), isTrue);
          expect(t.thumbnail.url, startsWith('https://c.saavncdn.com/'));
          expect(t.thumbnail.url.endsWith('.jpg') || t.thumbnail.url.endsWith('.webp'), isTrue);
        }
      }
    });

    test('Target 2 & Asha Bhosle: Yeh Vaada Raha exact recording, album, duration, and credits', () {
      final ashaTracks = CuratedArtistsService.getAshaBhosleTracks();
      final yehVaada = ashaTracks.firstWhere((t) => t.title == 'Yeh Vaada Raha');

      expect(yehVaada.id, equals('$kDefaultSaavnPluginId::3QkaGn1G'));
      expect(yehVaada.album?.title, equals('Yeh Vaada Raha'));
      expect(yehVaada.artists.first.name, contains('Asha Bhosle'));
      expect(yehVaada.artists.first.name, contains('Kishore Kumar'));
      expect(yehVaada.durationMs, equals(BigInt.from(409 * 1000))); // 409 seconds
      expect(yehVaada.thumbnail.url, equals('https://c.saavncdn.com/328/Yeh-Vaada-Raha-Hindi-1982-20200430061849-500x500.jpg'));
    });
  });

  group('Target 2: Plugin Error Sanitization & Display Branding', () {
    test('formatUserFriendlyPluginName maps technical identifiers to clean branding', () {
      expect(formatUserFriendlyPluginName('content-resolver.bloomfactory.jisaavn'), equals('JioSaavn'));
      expect(formatUserFriendlyPluginName('jisaavn'), equals('JioSaavn'));
      expect(formatUserFriendlyPluginName('content-resolver.bloomfactory.ytmusic'), equals('YouTube Music'));
      expect(formatUserFriendlyPluginName('ytmusic'), equals('YouTube Music'));
      expect(formatUserFriendlyPluginName('chart-provider.bloomfactory.billboard'), equals('Billboard'));
      expect(formatUserFriendlyPluginName(null), equals('Content Provider'));
    });

    test('WASM runtime errors are NOT falsely reported as offline network failure', () {
      final errorMsg = formatUserFriendlyPluginError('Wasm execution error: unreachable code executed');
      expect(errorMsg.toLowerCase().contains("offline"), isFalse);

      final handler = PlayerErrorHandler();
      final errorType = handler.categorizeError('Wasm execution error in plugin');
      expect(errorType, equals(PlayerErrorType.sourceError));
      expect(errorType, isNot(equals(PlayerErrorType.networkDropped)));
    });
  });

  group('Target 7: Diwali Festive Feature Cancellation Audit', () {
    test('Diwali banner is permanently excluded and never active at any date', () {
      // Nov 4 2026 23:59:00 IST -> UTC: Nov 4 18:29:00
      final beforeDate = DateTime.utc(2026, 11, 4, 18, 29);
      final beforeBanners = SmartBannerService.getActiveBanners(testTime: beforeDate);
      expect(beforeBanners.any((b) => b.id == 'diwali_festive_2026'), isFalse);

      // Nov 5 2026 12:00:00 IST -> UTC: Nov 5 06:30:00
      final activeDate = DateTime.utc(2026, 11, 5, 6, 30);
      final activeBanners = SmartBannerService.getActiveBanners(testTime: activeDate);
      expect(activeBanners.any((b) => b.id == 'diwali_festive_2026'), isFalse);

      // Nov 11 2026 23:00:00 IST -> UTC: Nov 11 17:30:00
      final lastDayDate = DateTime.utc(2026, 11, 11, 17, 30);
      final lastDayBanners = SmartBannerService.getActiveBanners(testTime: lastDayDate);
      expect(lastDayBanners.any((b) => b.id == 'diwali_festive_2026'), isFalse);

      // Nov 12 2026 00:01:00 IST -> UTC: Nov 11 18:31:00
      final afterDate = DateTime.utc(2026, 11, 11, 18, 31);
      final afterBanners = SmartBannerService.getActiveBanners(testTime: afterDate);
      expect(afterBanners.any((b) => b.id == 'diwali_festive_2026'), isFalse);
    });
  });

  group('Target 10: Library Favourite Artists State', () {
    test('LibraryItemsState maintains favouriteArtists list and copyWith behaves correctly', () {
      const state = LibraryItemsLoaded(playlists: []);
      expect(state.favouriteArtists, isEmpty);

      final dummyArtist = ArtistSummary(
        id: '455166',
        name: 'Asha Bhosle',
        thumbnail: const Artwork(url: 'https://c.saavncdn.com/artists/Asha_Bhosle.jpg', layout: ImageLayout.square),
      );

      final updated = state.copyWith(favouriteArtists: [dummyArtist]);
      expect(updated.favouriteArtists.length, equals(1));
      expect(updated.favouriteArtists.first.name, equals('Asha Bhosle'));
    });
  });
}
