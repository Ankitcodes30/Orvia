import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/plugins/utils/media_id.dart';
import 'package:Orvia/services/banner/smart_banner_service.dart';
import 'package:Orvia/services/catalogue/creators_choice_service.dart';
import 'package:Orvia/services/catalogue/curated_playlists_service.dart';
import 'package:Orvia/services/db/dao/playlist_dao.dart';
import 'package:Orvia/services/db/dao/track_dao.dart';
import 'package:Orvia/services/db/global_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("Creator's Choice Playlist Content & 9 Removed Tracks Verification", () {
    test("1. All 9 specified songs are strictly absent from Creator's Choice", () {
      final tracks = CreatorsChoiceService.getVerifiedTracks();
      final allRawIds = tracks.map((t) => localIdOf(t.id) ?? t.id).toSet();

      for (final removedId in CreatorsChoiceService.kRemovedTrackRawIds) {
        expect(allRawIds.contains(removedId), isFalse,
            reason: 'Raw ID $removedId must not be present in Creator\'s Choice');
      }

      // Explicit title & artist checks
      expect(tracks.any((t) => t.title.contains("I'm Done") && t.artists.any((a) => a.name.contains('Maan Panu'))), isFalse);
      expect(tracks.any((t) => t.title == 'Baarish' && t.artists.any((a) => a.name.contains('Ash King'))), isFalse);
      expect(tracks.any((t) => t.title.contains('Jubin Nautiyal Romantic Mashup 2022')), isFalse);
      expect(tracks.any((t) => t.title == 'Sohnea' && t.artists.any((a) => a.name.contains('Miss Pooja'))), isFalse);
      expect(tracks.any((t) => t.title.contains('Drive') && t.artists.any((a) => a.name.contains('Ed Sheeran'))), isFalse);
      expect(tracks.any((t) => t.title == 'Baatein Kuch Ankahee' && t.artists.any((a) => a.name.contains('Pritam'))), isFalse);
      expect(tracks.any((t) => t.title.contains('Anjali Anjali')), isFalse);
      expect(tracks.any((t) => t.title == 'Pehli Dafa' && t.artists.any((a) => a.name.contains('Satyajeet Jena'))), isFalse);
      expect(tracks.any((t) => t.title.contains('Navratri Garba Mashup 2021')), isFalse);
    });

    test("2. Exact 38 preserved classic tracks remain intact with original ordering and Pritam master Tu Jaane Na", () {
      final tracks = CreatorsChoiceService.getVerifiedTracks();
      expect(tracks.length, equals(70)); // 38 preserved classic + 32 YouTube tracks

      // Check first track and boundary tracks of the preserved set
      expect(tracks[0].title, equals('Naino Ne Baandhi'));
      expect(tracks[0].id, equals('$kDefaultSaavnPluginId::GQlvs79S'));
      expect(tracks[1].title, equals('Sab Tera'));

      // Index 14 is the original Pritam / Atif Aslam master of Tu Jaane Na
      expect(tracks[14].title, equals('Tu Jaane Na'));
      expect(tracks[14].id, equals('content-resolver.bloomfactory.ytvideo::P8PWN1OmZOA'));
      expect(tracks[14].artists.first.name, equals('Pritam, Atif Aslam'));
      expect(tracks[14].album?.title, equals('Ajab Prem Ki Ghazab Kahani'));

      // 38th track is Saanware
      expect(tracks[37].title, equals('Saanware'));
      expect(tracks[37].id, equals('$kDefaultSaavnPluginId::10rKWWH_'));
    });

    test("3. All 32 YouTube selections are present in exact supplied order with no duplicates", () {
      final tracks = CreatorsChoiceService.getVerifiedTracks();
      const expectedYtOrder = [
        '09fnyp7aAPk', 'JTA3bfDSuCw', 'cC0Pn37Z2eo', 'BVnIWAuCv7M', '1pAB0wrQTLE',
        'eXgtMnhGrmc', 'hWpD_fs8M2A', 'k6BnSIs3XUQ', 'TVbI55pDdaI', 'OtR5WTTyRjI',
        '_mwqXnTEHSc', 'FGTv9-oQhIg', '9Bmh6vaQt0s', 'qNSv9I0Flac', 'DK_UsATwoxI',
        'Gigpglm3XNw', 'E_SbwSe15y0', 'BcSejVIxB0E', '6d5SS0gS5bU', 'h1Fxjmg_KL4',
        'gbcFwOZ6uJI', 'qfdShSZZxlg', '0Iu5kQi8lns', 'V7LwfY5U5WI', 'VAdGW7QDJiU',
        '7SEFsalTzHQ', 'MVpAAJzPEds', 'MJyKN-8UncM', 'kw4tT7SCmaY', 'byitAI7kkOM',
        'cQq6iLF66Gc', 'LMnJp_dSdnw'
      ];

      final ytSubList = tracks.sublist(38);
      expect(ytSubList.length, equals(32));

      for (var i = 0; i < 32; i++) {
        final expectedVid = expectedYtOrder[i];
        final track = ytSubList[i];
        expect(track.id, equals('${CreatorsChoiceService.ytPluginId}::$expectedVid'));
        expect(localIdOf(track.id), equals(expectedVid));
        expect(track.title.trim(), isNotEmpty);
        expect(track.artists, isNotEmpty);
        expect(track.durationMs, isNotNull);
        expect(track.durationMs! > BigInt.zero, isTrue);
        expect(track.thumbnail.url, startsWith('https://i.ytimg.com/vi/$expectedVid/'));
        expect(track.url, equals('https://www.youtube.com/watch?v=$expectedVid'));
      }
    });

    test("4. No duplicate track IDs exist across Creator's Choice", () {
      final tracks = CreatorsChoiceService.getVerifiedTracks();
      final seenIds = <String>{};
      for (final t in tracks) {
        expect(seenIds.add(t.id), isTrue, reason: 'Duplicate track ID found: ${t.id}');
      }
    });

    test("5. Seeding existing playlist in-place removes only 9 tracks and adds 25 YouTube tracks without recreating playlist", () async {
      await Isar.initializeIsarCore(download: false);
      final tempRoot = await Directory.systemTemp.createTemp('orvia_cc_banner_test_');
      final isar = await Isar.open(
        [
          PlaylistDBSchema,
          PlaylistEntryDBSchema,
          TrackDBSchema,
          DownloadDBSchema,
        ],
        name: 'cc_banner_test_db',
        directory: tempRoot.path,
        inspector: false,
      );

      try {
        final trackDAO = TrackDAO(Future.value(isar));
        final playlistDAO = PlaylistDAO(Future.value(isar), trackDAO);

        final thumb = ArtworkDB()..url = 'https://example.com/art.jpg';
        final pId = await playlistDAO.createPlaylist(
          CreatorsChoiceService.playlistName,
          description: 'Original description',
          thumbnail: thumb,
        );
        expect(pId, isNotNull);

        final trackToRemove = Track(
          id: '$kDefaultSaavnPluginId::CmnN3kEf',
          title: "I'm Done (Reply Version)",
          artists: const [ArtistSummary(id: '', name: 'Maan Panu, Shuddhi')],
          album: const AlbumSummary(id: '', title: "I'm Done (Reply Version)", artists: []),
          durationMs: BigInt.from(156000),
          thumbnail: const Artwork(url: 'https://example.com/imdone.jpg', layout: ImageLayout.square),
          isExplicit: false,
        );
        final preservedTrack = Track(
          id: '$kDefaultSaavnPluginId::GQlvs79S',
          title: 'Naino Ne Baandhi',
          artists: const [ArtistSummary(id: '', name: 'Yasser Desai, Arko')],
          album: const AlbumSummary(id: '', title: 'Gold', artists: []),
          durationMs: BigInt.from(241000),
          thumbnail: const Artwork(url: 'https://example.com/naino.jpg', layout: ImageLayout.square),
          isExplicit: false,
        );

        await playlistDAO.addTracksToPlaylist(pId!, [trackToRemove, preservedTrack], allowSystem: true);

        var tracksBefore = await playlistDAO.getPlaylistTracks(pId);
        expect(tracksBefore.length, equals(2));

        await CreatorsChoiceService.ensurePlaylistExists(playlistDAO);

        final pAfter = await playlistDAO.getPlaylistByName(CreatorsChoiceService.playlistName);
        expect(pAfter!.id, equals(pId));

        final tracksAfter = await playlistDAO.getPlaylistTracks(pId);
        expect(tracksAfter.length, equals(70));
        expect(tracksAfter.any((t) => t.mediaId.contains('CmnN3kEf')), isFalse);
        expect(tracksAfter.first.mediaId, equals('$kDefaultSaavnPluginId::GQlvs79S'));
      } finally {
        if (isar.isOpen) {
          await isar.close(deleteFromDisk: true);
        }
        if (tempRoot.existsSync()) {
          try {
            tempRoot.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group("Lofi & Chill Track Addition Tests", () {
    test("6. Lofi & Chill verified track has exact YouTube ID ZGMr4kmKt5Q and genuine metadata", () {
      final t = CuratedPlaylistsService.getVerifiedLofiTrack();
      expect(t.id, equals('content-resolver.bloomfactory.ytvideo::ZGMr4kmKt5Q'));
      expect(t.title, contains('Na Tum Jano Na Hum'));
      expect(t.artists.first.name, equals('Saregama Music'));
      expect(t.durationMs, equals(BigInt.from(268 * 1000)));
      expect(t.thumbnail.url, equals('https://i.ytimg.com/vi/ZGMr4kmKt5Q/hqdefault.jpg'));
    }, timeout: const Timeout(Duration(seconds: 15)));
  });

  group("Top Sliding Banner & Creator's Choice Promotion Tests", () {
    test("7. India Songs is absent and disallowed from top banners", () {
      for (final id in ['india_songs', 'india-songs', 'india_songs_hotw', 'india-songs-hotw']) {
        expect(SmartBannerService.kDisallowedBannerIds.contains(id), isTrue);
      }
      final banners = SmartBannerService.getActiveBanners();
      expect(banners.any((b) => b.id.contains('india_song') || b.title.toLowerCase().contains('india song')), isFalse);
    }, timeout: const Timeout(Duration(seconds: 15)));

    test("8. Creator's Choice banner is present in active banners and configured properly", () {
      final banners = SmartBannerService.getActiveBanners();
      final ccBanner = banners.firstWhere((b) => b.id == 'creators_choice');

      expect(ccBanner.title, equals("Creator's Choice"));
      expect(ccBanner.subtitle, anyOf(equals("Where Melodies Meet Memories."), equals("Love, memories & melodies that stay.")));
      expect(ccBanner.badge, equals("CREATOR'S CHOICE"));
      expect(ccBanner.destination, equals('creators_choice'));
      expect(ccBanner.imageUrl, equals('assets/images/creators_choice_banner.webp'));
      expect(ccBanner.tracks.length, equals(70));
      expect(ccBanner.priority, equals(95));
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}
