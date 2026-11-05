@Timeout(Duration(minutes: 3))
library like_and_favourite_sync_test;

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
    tempRoot = await Directory.systemTemp.createTemp('orvia_like_sync_test_');

    isar = await Isar.open(
      [
        PlaylistDBSchema,
        PlaylistEntryDBSchema,
        TrackDBSchema,
        DownloadDBSchema,
      ],
      name: 'test_like_db_${DateTime.now().microsecondsSinceEpoch}',
      directory: tempRoot.path,
      inspector: false,
    );

    trackDAO = TrackDAO(Future.value(isar));
    playlistDAO = PlaylistDAO(Future.value(isar), trackDAO);
    libraryDAO = LibraryDAO(Future.value(isar));
  });

  tearDown(() async {
    try {
      if (isar.isOpen) {
        await isar.close(deleteFromDisk: true);
      }
    } catch (_) {}
    try {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Album & Remote Playlist Like-to-Library Persistence Tests', () {
    const sampleAlbum = AlbumSummary(
      id: 'content-resolver.bloomfactory.jisaavn::album_1001',
      title: 'Aashiqui 2',
      artists: [
        ArtistSummary(id: 'mithoon', name: 'Mithoon'),
        ArtistSummary(id: 'ankit', name: 'Ankit Tiwari'),
      ],
      thumbnail: Artwork(
        url: 'https://c.saavncdn.com/album/aashiqui_2.jpg',
        layout: ImageLayout.square,
      ),
      year: 2013,
      url: 'https://www.jiosaavn.com/album/aashiqui-2/1001',
    );

    const samplePlaylist = PlaylistSummary(
      id: 'content-resolver.bloomfactory.jisaavn::playlist_2002',
      title: 'Trending Bollywood Hits',
      thumbnail: Artwork(
        url: 'https://c.saavncdn.com/playlist/trending_hindi.jpg',
        layout: ImageLayout.square,
      ),
      owner: 'JioSaavn Editors',
      url: 'https://www.jiosaavn.com/featured/trending-hindi/2002',
    );

    test('1. Liking an Album persists to DB and updates Liked albums collection', timeout: const Timeout(Duration(minutes: 2)), () async {
      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: libraryDAO,
      );
      await cubit.initFuture;

      expect(cubit.state.playlists.any((p) => p.playlistName == 'Aashiqui 2'), isFalse);

      await cubit.saveRemoteAlbum(
        album: sampleAlbum,
        sourceName: 'JioSaavn',
        showSnackbar: false,
      );

      // Verify it does NOT appear as an individual playlist in the general list
      expect(cubit.state.playlists.any((p) => p.playlistName == 'Aashiqui 2'), isFalse);

      // Verify it updates the dedicated 'Liked albums' collection row
      final likedAlbumsRow = cubit.state.playlists.firstWhere(
        (p) => p.playlistName == 'Liked albums',
        orElse: () => throw StateError('Liked albums collection not found'),
      );
      expect(likedAlbumsRow.subTitle, contains('1 album'));
      expect(likedAlbumsRow.coverImgUrl, equals('https://c.saavncdn.com/album/aashiqui_2.jpg'));

      // Verify DAO check
      final isSaved = await cubit.isRemoteSaved(sampleAlbum.id, PlaylistType.album);
      expect(isSaved, isTrue);

      final savedAlbums = await libraryDAO.getSavedAlbums();
      expect(savedAlbums.any((a) => a.title == 'Aashiqui 2'), isTrue);

      // Verify resolution by storage key for navigation
      final resolved = await cubit.resolveLibraryItem(sampleAlbum.id);
      expect(resolved, isNotNull);
      expect(resolved!.title, equals('Aashiqui 2'));

      await cubit.close();
    });

    test('2. Liking a Remote Playlist persists to DB and immediately appears in Library state', timeout: const Timeout(Duration(minutes: 2)), () async {
      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: libraryDAO,
      );
      await cubit.initFuture;

      expect(cubit.state.playlists.any((p) => p.playlistName == 'Trending Bollywood Hits'), isFalse);

      await cubit.saveRemotePlaylist(
        playlist: samplePlaylist,
        sourceName: 'JioSaavn',
        showSnackbar: false,
      );

      // Verify immediate appearance in cubit state
      final savedPlaylistItem = cubit.state.playlists.firstWhere(
        (p) => p.playlistName == 'Trending Bollywood Hits',
        orElse: () => throw StateError('Playlist not found in Library state'),
      );
      expect(savedPlaylistItem.type, equals(PlaylistType.remotePlaylist));
      expect(savedPlaylistItem.subTitle, equals('Playlist • JioSaavn'));
      expect(savedPlaylistItem.coverImgUrl, equals('https://c.saavncdn.com/playlist/trending_hindi.jpg'));
      expect(savedPlaylistItem.storageKey, equals(samplePlaylist.id));

      // Verify DAO check
      final isSaved = await cubit.isRemoteSaved(samplePlaylist.id, PlaylistType.remotePlaylist);
      expect(isSaved, isTrue);

      // Verify resolution by storage key for navigation
      final resolved = await cubit.resolveLibraryItem(savedPlaylistItem.storageKey);
      expect(resolved, isNotNull);
      expect(resolved!.type, equals(PlaylistType.remotePlaylist));
      expect(resolved.title, equals('Trending Bollywood Hits'));

      await cubit.close();
    });

    test('3. Unliking Album and Playlist immediately removes them from Library state and DB', timeout: const Timeout(Duration(minutes: 2)), () async {
      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: libraryDAO,
      );
      await cubit.initFuture;

      await cubit.saveRemoteAlbum(album: sampleAlbum, sourceName: 'JioSaavn', showSnackbar: false);
      await cubit.saveRemotePlaylist(playlist: samplePlaylist, sourceName: 'JioSaavn', showSnackbar: false);

      expect(cubit.state.playlists.any((p) => p.playlistName == 'Aashiqui 2'), isFalse);
      expect(cubit.state.playlists.any((p) => p.playlistName == 'Trending Bollywood Hits'), isTrue);
      expect(await cubit.isRemoteSaved(sampleAlbum.id, PlaylistType.album), isTrue);

      // Remove album
      await cubit.removeRemoteSaved(sampleAlbum.id, PlaylistType.album);
      expect(cubit.state.playlists.any((p) => p.playlistName == 'Aashiqui 2'), isFalse);
      expect(await cubit.isRemoteSaved(sampleAlbum.id, PlaylistType.album), isFalse);
      final remainingAlbums = await libraryDAO.getSavedAlbums();
      expect(remainingAlbums.any((a) => a.id == sampleAlbum.id), isFalse);

      // Remove playlist
      await cubit.removeRemoteSaved(samplePlaylist.id, PlaylistType.remotePlaylist);
      expect(cubit.state.playlists.any((p) => p.playlistName == 'Trending Bollywood Hits'), isFalse);
      expect(await cubit.isRemoteSaved(samplePlaylist.id, PlaylistType.remotePlaylist), isFalse);

      await cubit.close();
    });

    test('4. Repeated Like does not create duplicate entries in DB or Library state', timeout: const Timeout(Duration(minutes: 2)), () async {
      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: libraryDAO,
      );
      await cubit.initFuture;

      // Save album 3 times
      await cubit.saveRemoteAlbum(album: sampleAlbum, sourceName: 'JioSaavn', showSnackbar: false);
      await cubit.saveRemoteAlbum(album: sampleAlbum, sourceName: 'JioSaavn', showSnackbar: false);
      await cubit.saveRemoteAlbum(album: sampleAlbum, sourceName: 'JioSaavn', showSnackbar: false);

      final matchingAlbums = cubit.state.playlists.where((p) => p.playlistName == 'Aashiqui 2').toList();
      expect(matchingAlbums.isEmpty, isTrue);

      final savedAlbums = await libraryDAO.getSavedAlbums();
      expect(savedAlbums.where((a) => a.title == 'Aashiqui 2').length, equals(1));

      // Save playlist 3 times
      await cubit.saveRemotePlaylist(playlist: samplePlaylist, sourceName: 'JioSaavn', showSnackbar: false);
      await cubit.saveRemotePlaylist(playlist: samplePlaylist, sourceName: 'JioSaavn', showSnackbar: false);
      await cubit.saveRemotePlaylist(playlist: samplePlaylist, sourceName: 'JioSaavn', showSnackbar: false);

      final matchingPlaylists =
          cubit.state.playlists.where((p) => p.playlistName == 'Trending Bollywood Hits').toList();
      expect(matchingPlaylists.length, equals(1));

      // Verify Isar DB count
      final dbAlbums = await isar.playlistDBs
          .filter()
          .typeIndexEqualTo(PlaylistTypeDB.album.index)
          .findAll();
      expect(dbAlbums.length, equals(1));

      final dbPlaylists = await isar.playlistDBs
          .filter()
          .typeIndexEqualTo(PlaylistTypeDB.remotePlaylist.index)
          .findAll();
      expect(dbPlaylists.length, equals(1));

      await cubit.close();
    });

    test('5. Saved Albums & Remote Playlists persist across simulated app restart', timeout: const Timeout(Duration(minutes: 2)), () async {
      // Session 1: Save items
      final cubit1 = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: libraryDAO,
      );
      await cubit1.initFuture;
      await cubit1.saveRemoteAlbum(album: sampleAlbum, sourceName: 'JioSaavn', showSnackbar: false);
      await cubit1.saveRemotePlaylist(playlist: samplePlaylist, sourceName: 'JioSaavn', showSnackbar: false);
      await cubit1.close();

      // Session 2: Fresh Cubit simulates app restart
      final cubit2 = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: libraryDAO,
      );
      await cubit2.initFuture;

      expect(cubit2.state.playlists.any((p) => p.playlistName == 'Aashiqui 2'), isFalse);
      expect(cubit2.state.playlists.any((p) => p.playlistName == 'Liked albums'), isTrue);
      final albums = await libraryDAO.getSavedAlbums();
      expect(albums.any((a) => a.title == 'Aashiqui 2'), isTrue);
      expect(cubit2.state.playlists.any((p) => p.playlistName == 'Trending Bollywood Hits'), isTrue);

      await cubit2.close();
    });
  });

  group('Song Favourite State & Real-Time Sync Tests', () {
    final sampleTrack = Track(
      id: 'content-resolver.bloomfactory.jisaavn::tum_hi_ho_123',
      title: 'Tum Hi Ho',
      artists: const [ArtistSummary(id: 'arijit', name: 'Arijit Singh')],
      album: const AlbumSummary(id: 'aashiqui2', title: 'Aashiqui 2', artists: []),
      thumbnail: const Artwork(url: 'https://c.saavncdn.com/art.jpg', layout: ImageLayout.square),
      durationMs: BigInt.from(262000),
      isExplicit: false,
    );

    test('1. setTrackLiked(true) emits reactive event on trackLikedStream and updates DB', timeout: const Timeout(Duration(minutes: 2)), () async {
      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: libraryDAO,
      );
      await cubit.initFuture;

      final events = <({String trackId, bool isLiked})>[];
      final sub = cubit.trackLikedStream.listen(events.add);

      expect(await cubit.isTrackLiked(sampleTrack), isFalse);

      await cubit.setTrackLiked(sampleTrack, true);
      await pumpEventQueue();

      // Verify reactive stream event
      expect(events.length, equals(1));
      expect(events.first.trackId, equals(sampleTrack.id));
      expect(events.first.isLiked, isTrue);

      // Verify DB authoritative state
      expect(await cubit.isTrackLiked(sampleTrack), isTrue);

      // Verify flexible matching by localId
      expect(await playlistDAO.isTrackLiked('tum_hi_ho_123'), isTrue);

      await sub.cancel();
      await cubit.close();
    });

    test('2. setTrackLiked(false) emits unliked event and removes track from Liked playlist', timeout: const Timeout(Duration(minutes: 2)), () async {
      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: libraryDAO,
      );
      await cubit.initFuture;

      final events = <({String trackId, bool isLiked})>[];
      final sub = cubit.trackLikedStream.listen(events.add);

      await cubit.setTrackLiked(sampleTrack, true);
      await pumpEventQueue();
      expect(await cubit.isTrackLiked(sampleTrack), isTrue);

      await cubit.setTrackLiked(sampleTrack, false);
      await pumpEventQueue();

      expect(events.length, equals(2));
      expect(events.last.trackId, equals(sampleTrack.id));
      expect(events.last.isLiked, isFalse);

      expect(await cubit.isTrackLiked(sampleTrack), isFalse);
      expect(await playlistDAO.isTrackLiked('tum_hi_ho_123'), isFalse);

      await sub.cancel();
      await cubit.close();
    });

    test('3. Repeated like on a song does not create duplicate entries in Liked playlist', timeout: const Timeout(Duration(minutes: 2)), () async {
      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: libraryDAO,
      );
      await cubit.initFuture;

      await cubit.setTrackLiked(sampleTrack, true);
      await cubit.setTrackLiked(sampleTrack, true);
      await cubit.setTrackLiked(sampleTrack, true);

      final likedPlaylistDb = await isar.playlistDBs.filter().nameEqualTo('Liked songs').findFirst() ??
          await isar.playlistDBs.filter().nameEqualTo('Liked').findFirst();
      expect(likedPlaylistDb, isNotNull);

      final entries = await isar.playlistEntryDBs
          .filter()
          .playlistIdEqualTo(likedPlaylistDb!.id)
          .findAll();
      expect(entries.length, equals(1));

      await cubit.close();
    });

    test('4. Cross-component track ID matching handles composite vs local IDs seamlessly', () {
      expect(isMatchingTrackId(
        'content-resolver.bloomfactory.jisaavn::tum_hi_ho_123',
        'content-resolver.bloomfactory.jisaavn::tum_hi_ho_123',
      ), isTrue);

      expect(isMatchingTrackId(
        'content-resolver.bloomfactory.jisaavn::tum_hi_ho_123',
        'tum_hi_ho_123',
      ), isTrue);

      expect(isMatchingTrackId(
        'tum_hi_ho_123',
        'content-resolver.bloomfactory.jisaavn::tum_hi_ho_123',
      ), isTrue);

      expect(isMatchingTrackId(
        'content-resolver.bloomfactory.jisaavn::different_track',
        'tum_hi_ho_123',
      ), isFalse);
    });

    test('5. Removing saved album via context menu (deletePlaylist) removes row and refreshes Library', timeout: const Timeout(Duration(minutes: 2)), () async {
      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: libraryDAO,
      );
      await cubit.initFuture;

      const testAlbum = AlbumSummary(
        id: 'saavn::alb_999',
        title: 'Rockstar',
        artists: [],
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
      );

      await cubit.saveRemoteAlbum(album: testAlbum, sourceName: 'Saavn', showSnackbar: false);
      expect(cubit.state.playlists.any((p) => p.playlistName == 'Rockstar'), isFalse);
      expect(await cubit.isRemoteSaved(testAlbum.id, PlaylistType.album), isTrue);
      final savedAlbums = await libraryDAO.getSavedAlbums();
      expect(savedAlbums.any((a) => a.id == testAlbum.id), isTrue);

      await cubit.removeRemoteSaved(testAlbum.id, PlaylistType.album);

      expect(cubit.state.playlists.any((p) => p.playlistName == 'Rockstar'), isFalse);
      expect(await cubit.isRemoteSaved(testAlbum.id, PlaylistType.album), isFalse);
      final remainingAlbums = await libraryDAO.getSavedAlbums();
      expect(remainingAlbums.any((a) => a.id == testAlbum.id), isFalse);

      await cubit.close();
    });

    test('6. Cross-plugin ID safety: Identical local IDs from DIFFERENT plugins never cross-match', () {
      expect(isMatchingTrackId(
        'content-resolver.bloomfactory.jisaavn::track_123',
        'content-resolver.youtube.music::track_123',
      ), isFalse);

      expect(isMatchingTrackId(
        'saavn::track_123',
        'spotify::track_123',
      ), isFalse);
    });

    test('7. Rapid alternating like/unlike actions maintain DB and reactive stream integrity', timeout: const Timeout(Duration(minutes: 2)), () async {
      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: libraryDAO,
      );
      await cubit.initFuture;

      final events = <({String trackId, bool isLiked})>[];
      final sub = cubit.trackLikedStream.listen(events.add);

      // Rapidly toggle 6 times: true, false, true, false, true, false
      for (int i = 0; i < 6; i++) {
        await cubit.setTrackLiked(sampleTrack, i % 2 == 0);
      }
      await pumpEventQueue();

      expect(events.length, equals(6));
      expect(events.last.isLiked, isFalse);
      expect(await cubit.isTrackLiked(sampleTrack), isFalse);

      await sub.cancel();
      await cubit.close();
    });

    test('8. Simultaneous like calls from multiple components do not create duplicate DB entries', timeout: const Timeout(Duration(minutes: 2)), () async {
      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: libraryDAO,
      );
      await cubit.initFuture;

      // Simulate 3 components (heart button, 3-dot menu, keyboard shortcut) triggering like concurrently
      await Future.wait([
        cubit.setTrackLiked(sampleTrack, true),
        cubit.setTrackLiked(sampleTrack, true),
        cubit.setTrackLiked(sampleTrack, true),
      ]);
      await pumpEventQueue();

      expect(await cubit.isTrackLiked(sampleTrack), isTrue);

      final likedPlaylistDb = await isar.playlistDBs.filter().nameEqualTo('Liked songs').findFirst() ??
          await isar.playlistDBs.filter().nameEqualTo('Liked').findFirst();
      expect(likedPlaylistDb, isNotNull);

      final entries = await isar.playlistEntryDBs
          .filter()
          .playlistIdEqualTo(likedPlaylistDb!.id)
          .findAll();
      expect(entries.length, equals(1));

      await cubit.close();
    });

    test('9. Queue track transition does not contaminate new track with prior track favourite state', timeout: const Timeout(Duration(minutes: 2)), () async {
      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: libraryDAO,
      );
      await cubit.initFuture;

      const trackA = Track(
        id: 'saavn::track_a',
        title: 'Track A',
        artists: [],
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );
      const trackB = Track(
        id: 'saavn::track_b',
        title: 'Track B',
        artists: [],
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      // Track A is liked, Track B is not liked
      await cubit.setTrackLiked(trackA, true);

      expect(await cubit.isTrackLiked(trackA), isTrue);
      expect(await cubit.isTrackLiked(trackB), isFalse);

      await cubit.close();
    });
  });
}
