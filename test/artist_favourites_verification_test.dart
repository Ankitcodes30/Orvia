import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:Orvia/blocs/library/cubit/library_items_cubit.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/plugins/utils/media_id.dart';
import 'package:Orvia/services/db/dao/library_dao.dart';
import 'package:Orvia/services/db/dao/playlist_dao.dart';
import 'package:Orvia/services/db/dao/track_dao.dart';
import 'package:Orvia/services/db/global_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late Isar isar;
  late TrackDAO trackDAO;
  late PlaylistDAO playlistDAO;
  late LibraryDAO libraryDAO;

  setUp(() async {
    await Isar.initializeIsarCore(download: false);
    tempRoot = await Directory.systemTemp.createTemp('orvia_artist_fav_test_');

    isar = await Isar.open(
      [
        PlaylistDBSchema,
        PlaylistEntryDBSchema,
        TrackDBSchema,
        DownloadDBSchema,
      ],
      directory: tempRoot.path,
      inspector: false,
    );

    trackDAO = TrackDAO(Future.value(isar));
    playlistDAO = PlaylistDAO(Future.value(isar), trackDAO);
    libraryDAO = LibraryDAO(Future.value(isar));
  });

  tearDown(() async {
    if (isar.isOpen) {
      await isar.close(deleteFromDisk: true);
    }
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  group('Artist Favourites: End-to-End Verification Tests', () {
    final arijitSingh = ArtistSummary(
      id: '459320',
      name: 'Arijit Singh',
      subtitle: 'Playback Singer',
      thumbnail: Artwork(
        url: 'https://c.saavncdn.com/artists/Arijit_Singh_500x500.jpg',
        layout: ImageLayout.square,
      ),
    );

    final ytArtist = ArtistSummary(
      id: 'content-resolver.youtube::UCb2HGwORbAyo_Z648MV51tw',
      name: 'Anuv Jain',
      subtitle: 'Indie Artist',
      thumbnail: Artwork(
        url: 'https://lh3.googleusercontent.com/anuv_jain.jpg',
        layout: ImageLayout.square,
      ),
    );

    test('1. Favourite artist immediately reflects in LibraryItemsCubit state without delay', () async {
      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: libraryDAO,
      );
      await cubit.initFuture;

      expect(cubit.state.favouriteArtists, isEmpty);

      // Save artist
      await cubit.saveRemoteArtist(
        artist: arijitSingh,
        sourceName: 'JioSaavn',
        showSnackbar: false,
      );

      // Immediate state reflection
      expect(cubit.state.favouriteArtists.length, equals(1));
      expect(cubit.state.favouriteArtists.first.id, equals('459320'));
      expect(cubit.state.favouriteArtists.first.name, equals('Arijit Singh'));

      await cubit.close();
    });

    test('2. Unfavourite artist immediately removes from LibraryItemsCubit state without delay', () async {
      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: libraryDAO,
      );
      await cubit.initFuture;

      // Save initial artist
      await cubit.saveRemoteArtist(
        artist: arijitSingh,
        sourceName: 'JioSaavn',
        showSnackbar: false,
      );
      expect(cubit.state.favouriteArtists.length, equals(1));

      // Remove artist
      await cubit.removeRemoteSaved('459320', PlaylistType.artist);

      // Immediate state reflection
      expect(cubit.state.favouriteArtists, isEmpty);

      await cubit.close();
    });

    test('3. Favourite state persists across database closing and reopening', () async {
      // Session 1: Save artist to DB
      await libraryDAO.saveArtist(arijitSingh, sourceName: 'JioSaavn');
      final savedInSession1 = await libraryDAO.getSavedArtists();
      expect(savedInSession1.length, equals(1));
      expect(savedInSession1.first.name, equals('Arijit Singh'));

      // Close session 1 Isar
      await isar.close();

      // Session 2: Reopen same database directory
      final isar2 = await Isar.open(
        [
          PlaylistDBSchema,
          PlaylistEntryDBSchema,
          TrackDBSchema,
          DownloadDBSchema,
        ],
        directory: tempRoot.path,
        inspector: false,
      );
      final libraryDAO2 = LibraryDAO(Future.value(isar2));
      final trackDAO2 = TrackDAO(Future.value(isar2));
      final playlistDAO2 = PlaylistDAO(Future.value(isar2), trackDAO2);

      final cubit2 = LibraryItemsCubit(
        playlistDao: playlistDAO2,
        libraryDao: libraryDAO2,
      );
      await cubit2.initFuture;

      // Verified persistence
      expect(cubit2.state.favouriteArtists.length, equals(1));
      expect(cubit2.state.favouriteArtists.first.id, equals('459320'));
      expect(cubit2.state.favouriteArtists.first.name, equals('Arijit Singh'));

      await cubit2.close();
      await isar2.close();

      // Re-open isar for tearDown
      isar = await Isar.open(
        [
          PlaylistDBSchema,
          PlaylistEntryDBSchema,
          TrackDBSchema,
          DownloadDBSchema,
        ],
        directory: tempRoot.path,
        inspector: false,
      );
    });

    test('4. Duplicate favourites remain prevented upon multiple saves', () async {
      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: libraryDAO,
      );
      await cubit.initFuture;

      await cubit.saveRemoteArtist(
        artist: arijitSingh,
        sourceName: 'JioSaavn',
        showSnackbar: false,
      );
      expect(cubit.state.favouriteArtists.length, equals(1));

      // Attempt duplicate save
      await cubit.saveRemoteArtist(
        artist: arijitSingh,
        sourceName: 'JioSaavn',
        showSnackbar: false,
      );
      expect(cubit.state.favouriteArtists.length, equals(1));

      final allDbRecords = await isar.playlistDBs
          .filter()
          .typeIndexEqualTo(PlaylistTypeDB.artist.index)
          .findAll();
      expect(allDbRecords.length, equals(1));

      await cubit.close();
    });

    test('5. Saved artists from different providers resolve to correct plugin ID', () {
      // YouTube Music artist
      final ytResolved = pluginIdOf(ytArtist.id);
      final effectiveYtPluginId = (ytResolved != null && ytResolved.isNotEmpty)
          ? ytResolved
          : kDefaultSaavnPluginId;
      expect(effectiveYtPluginId, equals('content-resolver.youtube'));

      // Stamped JioSaavn artist
      final saavnArtist = ArtistSummary(
        id: 'content-resolver.bloomfactory.jisaavn::459320',
        name: 'Arijit Singh',
      );
      final saavnResolved = pluginIdOf(saavnArtist.id);
      final effectiveSaavnPluginId = (saavnResolved != null && saavnResolved.isNotEmpty)
          ? saavnResolved
          : kDefaultSaavnPluginId;
      expect(effectiveSaavnPluginId, equals('content-resolver.bloomfactory.jisaavn'));
    });

    test('6. Legacy and unresolved artist IDs safely fall back to kDefaultSaavnPluginId', () {
      // Unstamped numeric legacy ID
      final legacyResolved = pluginIdOf(arijitSingh.id);
      expect(legacyResolved, isNull);

      final effectiveLegacyPluginId = (legacyResolved != null && legacyResolved.isNotEmpty)
          ? legacyResolved
          : kDefaultSaavnPluginId;
      expect(effectiveLegacyPluginId, equals(kDefaultSaavnPluginId));

      // Empty string ID fallback
      final emptyResolved = pluginIdOf('');
      expect(emptyResolved, isNull);

      final effectiveEmptyPluginId = (emptyResolved != null && emptyResolved.isNotEmpty)
          ? emptyResolved
          : kDefaultSaavnPluginId;
      expect(effectiveEmptyPluginId, equals(kDefaultSaavnPluginId));
    });
  });
}

