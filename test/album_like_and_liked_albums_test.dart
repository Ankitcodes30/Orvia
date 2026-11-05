@Timeout(Duration(minutes: 3))
library album_like_and_liked_albums_test;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:Orvia/blocs/library/cubit/library_items_cubit.dart';
import 'package:Orvia/blocs/library/search_cubit/library_search_cubit.dart';
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
  late LibraryItemsCubit libraryCubit;

  setUp(() async {
    await Isar.initializeIsarCore(download: false);
    tempRoot = await Directory.systemTemp
        .createTemp('orvia_album_like_test_${DateTime.now().microsecondsSinceEpoch}_');

    isar = await Isar.open(
      [
        PlaylistDBSchema,
        PlaylistEntryDBSchema,
        TrackDBSchema,
        DownloadDBSchema,
      ],
      name: 'test_db_${DateTime.now().microsecondsSinceEpoch}',
      directory: tempRoot.path,
      inspector: false,
    );

    trackDAO = TrackDAO(Future.value(isar));
    playlistDAO = PlaylistDAO(Future.value(isar), trackDAO);
    libraryDAO = LibraryDAO(Future.value(isar));
    libraryCubit = LibraryItemsCubit(
      playlistDao: playlistDAO,
      libraryDao: libraryDAO,
    );
  });

  tearDown(() async {
    try {
      await libraryCubit.close();
    } catch (_) {}
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

  const mangalRangAlbum = AlbumSummary(
    id: 'content-resolver.bloomfactory.jisaavn::album_mangal_rang_492810',
    title: 'Mangal Rang',
    artists: [
      ArtistSummary(id: 'artist_1', name: 'Various Artists'),
    ],
    thumbnail: Artwork(
      url: 'https://c.saavncdn.com/album/mangal_rang.jpg',
      layout: ImageLayout.square,
    ),
    year: 2024,
    url: 'https://www.jiosaavn.com/album/mangal-rang/492810',
  );

  group('Album Like & Liked Albums Regression Suite', () {
    test('1 & 2: Mangal Rang persistence after save and Library state reflection', () async {
      await libraryCubit.initFuture;

      // Save Mangal Rang
      await libraryCubit.saveRemoteAlbum(
        album: mangalRangAlbum,
        sourceName: 'JioSaavn',
        pluginId: kDefaultSaavnPluginId,
        showSnackbar: false,
      );

      // Verify persistence in LibraryDAO
      final savedAlbums = await libraryDAO.getSavedAlbums();
      expect(savedAlbums.length, 1);
      expect(savedAlbums.first.title, 'Mangal Rang');
      expect(savedAlbums.first.id, mangalRangAlbum.id);

      // Verify presence in LibraryItemsCubit state
      expect(libraryCubit.state.likedAlbums.length, 1);
      expect(libraryCubit.state.likedAlbums.first.title, 'Mangal Rang');

      // Verify Liked albums collection entry in playlists view model
      final likedAlbumsItem = libraryCubit.state.playlists
          .where((p) => p.playlistName == 'Liked albums' || p.storageKey == 'liked_albums_collection')
          .firstOrNull;
      expect(likedAlbumsItem, isNotNull);
      expect(likedAlbumsItem!.subTitle, '1 album');
      expect(likedAlbumsItem.coverImgUrl, mangalRangAlbum.thumbnail?.url);
    });

    test('3: Liked albums collection is styled as normal playlist item without promo/hero', () async {
      await libraryCubit.initFuture;
      await libraryCubit.saveRemoteAlbum(
        album: mangalRangAlbum,
        sourceName: 'JioSaavn',
        showSnackbar: false,
      );

      final likedAlbumsItem = libraryCubit.state.playlists
          .firstWhere((p) => p.storageKey == 'liked_albums_collection');

      // Normal playlist item properties
      expect(likedAlbumsItem.type, PlaylistType.album);
      expect(likedAlbumsItem.playlistName, 'Liked albums');
      expect(likedAlbumsItem.isPinned, true);
    });

    test('4: Liked albums are resolvable and provide track/detail navigation target', () async {
      await libraryCubit.initFuture;
      await libraryCubit.saveRemoteAlbum(
        album: mangalRangAlbum,
        sourceName: 'JioSaavn',
        showSnackbar: false,
      );

      final isSaved = await libraryCubit.isRemoteSaved(mangalRangAlbum.id, PlaylistType.album);
      expect(isSaved, isTrue);

      final resolved = await libraryDAO.resolveByStorageKey(mangalRangAlbum.id);
      expect(resolved, isNotNull);
      expect(resolved!.title, 'Mangal Rang');
      expect(resolved.album?.id, mangalRangAlbum.id);
    });

    test('5: Unliking an album removes it immediately from Liked albums', () async {
      await libraryCubit.initFuture;
      await libraryCubit.saveRemoteAlbum(
        album: mangalRangAlbum,
        sourceName: 'JioSaavn',
        showSnackbar: false,
      );
      expect(libraryCubit.state.likedAlbums.length, 1);

      // Unlike
      await libraryCubit.removeRemoteSaved(mangalRangAlbum.id, PlaylistType.album);

      // Verify immediate removal
      expect(libraryCubit.state.likedAlbums.isEmpty, isTrue);
      final isSaved = await libraryCubit.isRemoteSaved(mangalRangAlbum.id, PlaylistType.album);
      expect(isSaved, isFalse);

      final likedAlbumsItem = libraryCubit.state.playlists
          .firstWhere((p) => p.storageKey == 'liked_albums_collection');
      expect(likedAlbumsItem.subTitle, '0 albums');
    });

    test('6: Saving an album does not introduce duplicates', () async {
      await libraryCubit.initFuture;

      // Save twice
      await libraryCubit.saveRemoteAlbum(
        album: mangalRangAlbum,
        sourceName: 'JioSaavn',
        showSnackbar: false,
      );
      await libraryCubit.saveRemoteAlbum(
        album: mangalRangAlbum,
        sourceName: 'JioSaavn',
        showSnackbar: false,
      );

      final saved = await libraryDAO.getSavedAlbums();
      expect(saved.length, 1);
      expect(libraryCubit.state.likedAlbums.length, 1);
    });

    test('7: Liked albums persist across app restart / new Cubit instance', () async {
      await libraryCubit.initFuture;
      await libraryCubit.saveRemoteAlbum(
        album: mangalRangAlbum,
        sourceName: 'JioSaavn',
        showSnackbar: false,
      );

      // Simulate app restart: close existing cubit, open fresh cubit over same DB
      await libraryCubit.close();
      final restartedCubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: libraryDAO,
      );
      await restartedCubit.initFuture;

      expect(restartedCubit.state.likedAlbums.length, 1);
      expect(restartedCubit.state.likedAlbums.first.title, 'Mangal Rang');
      expect(
        restartedCubit.state.playlists.any((p) => p.storageKey == 'liked_albums_collection'),
        isTrue,
      );
      await restartedCubit.close();
    });

    test('8: Existing liked songs remain intact under "Liked songs" collection', timeout: const Timeout(Duration(minutes: 2)), () async {
      // Create legacy "Liked" playlist with a song before setup
      final legacyLikedId = await playlistDAO.ensurePlaylist('Liked');
      const song1 = Track(
        id: 'content-resolver.bloomfactory.jisaavn::song_apna_bana_le',
        title: 'Apna Bana Le',
        artists: [ArtistSummary(id: 'arijit', name: 'Arijit Singh')],
        thumbnail: Artwork(
          url: 'https://c.saavncdn.com/apna_bana_le.jpg',
          layout: ImageLayout.square,
        ),
        isExplicit: false,
      );
      await playlistDAO.addTrackToPlaylist(legacyLikedId, song1);

      // Verify legacy count is 1
      final preCount = await playlistDAO.getPlaylistTrackCount(legacyLikedId);
      expect(preCount, 1);

      // Setup Library: should migrate 'Liked' to 'Liked songs' without duplicating or dropping tracks
      await libraryCubit.initFuture;

      final likedSongsItem = libraryCubit.state.playlists
          .firstWhere((p) => p.playlistName == 'Liked songs');
      expect(likedSongsItem, isNotNull);

      // Verify song is still liked and in Liked songs
      final isLiked = await playlistDAO.isTrackLiked(song1.id);
      expect(isLiked, isTrue);

      final tracks = await libraryCubit.getPlaylistTracks('Liked songs');
      expect(tracks, isNotNull);
      expect(tracks!.length, 1);
      expect(tracks.first.title, 'Apna Bana Le');
    });

    test('9: Song heart sync operates seamlessly with Liked songs', timeout: const Timeout(Duration(minutes: 2)), () async {
      await libraryCubit.initFuture;
      const testTrack = Track(
        id: 'content-resolver.bloomfactory.jisaavn::song_kesariya',
        title: 'Kesariya',
        artists: [ArtistSummary(id: 'arijit', name: 'Arijit Singh')],
        thumbnail: Artwork(
          url: 'https://c.saavncdn.com/kesariya.jpg',
          layout: ImageLayout.square,
        ),
        isExplicit: false,
      );

      // Like track
      await libraryCubit.setTrackLiked(testTrack, true);
      expect(await libraryCubit.isTrackLiked(testTrack), isTrue);

      // Check tracks in Liked songs
      var likedTracks = await libraryCubit.getPlaylistTracks('Liked songs');
      expect(likedTracks!.any((t) => t.id == testTrack.id), isTrue);

      // Unlike track
      await libraryCubit.setTrackLiked(testTrack, false);
      expect(await libraryCubit.isTrackLiked(testTrack), isFalse);

      likedTracks = await libraryCubit.getPlaylistTracks('Liked songs');
      expect(likedTracks!.any((t) => t.id == testTrack.id), isFalse);
    });

    test('10 & 11: ID collision protection & provider distinction', timeout: const Timeout(Duration(minutes: 2)), () async {
      await libraryCubit.initFuture;

      // Same raw local album ID under two different plugins
      const saavnAlbum = AlbumSummary(
        id: 'content-resolver.bloomfactory.jisaavn::album_123',
        title: 'Album Saavn',
        artists: [],
      );
      const ytAlbum = AlbumSummary(
        id: 'youtube::album_123',
        title: 'Album YouTube',
        artists: [],
      );

      await libraryCubit.saveRemoteAlbum(
        album: saavnAlbum,
        sourceName: 'JioSaavn',
        showSnackbar: false,
      );
      await libraryCubit.saveRemoteAlbum(
        album: ytAlbum,
        sourceName: 'YouTube Music',
        showSnackbar: false,
      );

      final saved = await libraryDAO.getSavedAlbums();
      expect(saved.length, 2);
      expect(saved.any((a) => a.id == saavnAlbum.id), isTrue);
      expect(saved.any((a) => a.id == ytAlbum.id), isTrue);
    });

    test('12: No playlist regressions (creation, deletion, rename, search)', timeout: const Timeout(Duration(minutes: 2)), () async {
      await libraryCubit.initFuture;

      // Create user playlist
      await libraryCubit.createPlaylist('My Roadtrip Mix');
      expect(
        libraryCubit.state.playlists.any((p) => p.playlistName == 'My Roadtrip Mix'),
        isTrue,
      );

      // Rename user playlist
      final userPlaylist = libraryCubit.state.playlists
          .firstWhere((p) => p.playlistName == 'My Roadtrip Mix');
      final renamed = await libraryCubit.renamePlaylist(userPlaylist.playlistId, 'My Chill Mix');
      expect(renamed, isTrue);

      // Cannot rename or delete protected Liked songs / Liked albums
      final cannotRenameLikedSongs = await libraryCubit.renamePlaylistByName('Liked songs', 'Hacked');
      expect(cannotRenameLikedSongs, isFalse);

      await libraryCubit.removePlaylistByName('Liked songs');
      expect(
        libraryCubit.state.playlists.any((p) => p.playlistName == 'Liked songs'),
        isTrue,
      );

      // Library search finds both playlists and liked albums
      await libraryCubit.saveRemoteAlbum(
        album: mangalRangAlbum,
        sourceName: 'JioSaavn',
        showSnackbar: false,
      );

      final searchCubit = LibrarySearchCubit(searchTracks: libraryCubit.searchTracks);
      searchCubit.search('Mangal', libraryCubit.state);
      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(searchCubit.state, isA<LibrarySearchSuccess>());
      final success = searchCubit.state as LibrarySearchSuccess;
      expect(
        success.filteredPlaylists.any((p) => p.playlistName == 'Mangal Rang'),
        isTrue,
      );
      await searchCubit.close();
    });
  });
}
