// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:developer';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/constants/setting_keys.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/services/db/dao/library_dao.dart';
import 'package:Orvia/services/db/global_db.dart';
import 'package:Orvia/services/db/mappers/collection_mapper.dart';
import 'package:Orvia/services/db/mappers/media_item_mapper.dart';
import 'package:Orvia/services/db/mappers/playlist_mapper.dart';
import 'package:equatable/equatable.dart';
import 'package:Orvia/screens/widgets/snackbar.dart';
import 'package:Orvia/services/catalogue/creators_choice_service.dart';
import 'package:Orvia/services/db/dao/playlist_dao.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
part 'library_items_state.dart';

/// Manages the user's library: local playlists and saved remote collections.
///
/// Combines data from [PlaylistDAO] (user playlists) and [LibraryDAO] (saved
/// remote collections). Emits view-model state using only domain types — no
/// DB types leak into the state layer.
class LibraryItemsCubit extends Cubit<LibraryItemsState> {
  StreamSubscription? _playlistWatcher;
  StreamSubscription? _savedCollectionsWatcher;
  final _trackLikedController =
      StreamController<({String trackId, bool isLiked})>.broadcast();
  Stream<({String trackId, bool isLiked})> get trackLikedStream =>
      _trackLikedController.stream;
  final PlaylistDAO _playlistDao;
  final LibraryDAO _libraryDao;

  LibraryItemsCubit({
    required PlaylistDAO playlistDao,
    required LibraryDAO libraryDao,
  })  : _playlistDao = playlistDao,
        _libraryDao = libraryDao,
        super(LibraryItemsLoading()) {
    _initFuture = _initialize();
  }

  Future<void>? _initFuture;
  Future<void>? get initFuture => _initFuture;

  @override
  Future<void> close() async {
    _playlistWatcher?.cancel();
    _playlistWatcher = null;
    _savedCollectionsWatcher?.cancel();
    _savedCollectionsWatcher = null;
    _trackLikedController.close();
    try {
      await _initFuture;
    } catch (_) {}
    return super.close();
  }

  Future<void> _initialize() async {
    try {
      if (isClosed) return;
      await _playlistDao.purgeBrokenPlaylistEntries();
      if (isClosed) return;
      await CreatorsChoiceService.ensurePlaylistExists(_playlistDao);
      if (isClosed) return;
      await _fetchPlaylists();
      if (isClosed) return;
      await _setupWatchers();
    } catch (e) {
      log('Error during LibraryItemsCubit initialization: $e',
          name: 'LibraryItemsCubit');
    }
  }

  Future<void> _setupWatchers() async {
    if (isClosed) return;
    try {
      _playlistWatcher = (await _playlistDao.watchAllPlaylists()).listen((_) {
        if (!isClosed) {
          _fetchPlaylists();
        }
      });
      _savedCollectionsWatcher =
          (await _libraryDao.watchSavedCollections()).listen((_) {
        if (!isClosed) {
          _fetchPlaylists();
        }
      });
    } catch (_) {}
  }

  static const _systemPlaylists = {
    SettingKeys.recentlyPlayedPlaylist,
    SettingKeys.downloadPlaylist,
    SettingKeys.localMusicPlaylist,
  };

  /// Playlists explicitly excluded from the Library view listing only.
  /// DB records, tracks, and Discovery categories remain completely intact.
  static const _excludedFromLibraryOnly = {
    'Bollywood Dance Hits',
    'Marathi Superhits',
    'Instrumental Classics & Covers',
    'Dammn',
  };

  /// Fetch all playlists (user + remote collections) and emit as domain items.
  Future<void> _fetchPlaylists() async {
    try {
      await _playlistDao.ensureLikedSongsPlaylist();
      final allPlaylists = await _playlistDao.getAllPlaylists();
      allPlaylists.removeWhere((p) => _systemPlaylists.contains(p.name));
      allPlaylists.removeWhere((p) => _excludedFromLibraryOnly.contains(p.name));
      // Guard against orphan rows with an empty name or internal provider IDs.
      allPlaylists.removeWhere((p) {
        if (p.type == PlaylistTypeDB.artist) {
          return true; // Artists live in favouriteArtists section
        }
        if (p.type == PlaylistTypeDB.album) {
          return true; // Liked albums live exclusively in the dedicated 'Liked albums' collection
        }
        if (p.type == PlaylistTypeDB.userPlaylist) {
          return p.name.trim().isEmpty ||
              p.name.startsWith('content-resolver.') ||
              p.name.contains('::');
        }
        // For remotePlaylist, ensure display title is non-empty
        final title = playlistDBDisplayName(p).trim();
        return title.isEmpty;
      });
      final items = await _toItemProperties(allPlaylists);

      // Ensure 'Liked' playlist row is titled 'Liked songs'
      for (int i = 0; i < items.length; i++) {
        if (items[i].playlistName == PlaylistDAO.likedPlaylist ||
            items[i].storageKey == PlaylistDAO.likedPlaylist) {
          items[i] = PlaylistItemProperties(
            playlistName: PlaylistDAO.likedSongsPlaylist,
            storageKey: items[i].storageKey,
            coverImgUrl: items[i].coverImgUrl,
            subTitle: items[i].subTitle,
            type: items[i].type,
            isPinned: items[i].isPinned,
            sortOrder: items[i].sortOrder,
            playlistId: items[i].playlistId,
          );
        }
      }

      final savedArtists = await _libraryDao.getSavedArtists();
      final savedAlbums = await _libraryDao.getSavedAlbums();

      // Inject Liked albums collection row directly under Liked songs
      final likedAlbumsCover = savedAlbums.isNotEmpty
          ? savedAlbums.first.thumbnail?.url
          : null;
      final albumCount = savedAlbums.length;
      final albumSubtitle =
          '$albumCount ${albumCount == 1 ? 'album' : 'albums'}';

      final likedAlbumsItem = PlaylistItemProperties(
        playlistName: 'Liked albums',
        storageKey: 'liked_albums_collection',
        coverImgUrl: likedAlbumsCover,
        subTitle: albumSubtitle,
        type: PlaylistType.album,
        isPinned: true,
        sortOrder: -1,
        playlistId: -999,
      );

      final likedSongsIndex = items.indexWhere((p) =>
          p.playlistName == PlaylistDAO.likedSongsPlaylist ||
          p.playlistName == PlaylistDAO.likedPlaylist ||
          p.storageKey == PlaylistDAO.likedSongsPlaylist ||
          p.storageKey == PlaylistDAO.likedPlaylist);

      if (likedSongsIndex >= 0) {
        items.insert(likedSongsIndex + 1, likedAlbumsItem);
      } else {
        items.insert(0, likedAlbumsItem);
      }

      if (isClosed) return;
      emit(state.copyWith(
        playlists: items,
        favouriteArtists: savedArtists,
        likedAlbums: savedAlbums,
      ));
    } catch (e) {
      log('Error fetching playlists: $e', name: 'LibraryItemsCubit');
      if (isClosed) return;
      emit(const LibraryItemsError('Failed to load your playlists.'));
    }
  }

  /// Convert DB rows to view-model items using only domain types.
  Future<List<PlaylistItemProperties>> _toItemProperties(
      List<PlaylistDB> dbs) async {
    final items = <PlaylistItemProperties>[];

    for (final p in dbs) {
      // Map using the playlist mapper to get a domain Playlist.
      final domainPlaylist = playlistDBToPlaylist(p);

      String? subtitle;
      if (domainPlaylist.subtitle != null &&
          domainPlaylist.subtitle!.trim().isNotEmpty) {
        subtitle = domainPlaylist.subtitle!.trim();
      } else if (domainPlaylist.type == PlaylistType.userPlaylist) {
        final trackCount = await _playlistDao.getPlaylistTrackCount(p.id);
        subtitle = '$trackCount ${trackCount == 1 ? 'track' : 'tracks'}';
      }

      final coverUrl = await _resolveCoverUrl(p);

      items.add(
        PlaylistItemProperties(
          playlistName: domainPlaylist.title,
          storageKey: p.name,
          subTitle: subtitle,
          coverImgUrl: coverUrl,
          type: domainPlaylist.type,
          isPinned: p.isPinned,
          sortOrder: p.sortOrder,
          playlistId: p.id,
        ),
      );
    }

    return items;
  }

  /// Resolve a cover image URL: direct thumbnail for remote, first track for user.
  Future<String?> _resolveCoverUrl(PlaylistDB playlist) async {
    // Try direct thumbnail first (works for all types).
    final thumb = playlist.thumbnail;
    if (thumb != null && thumb.url.isNotEmpty) {
      return thumb.url;
    }

    // For albums, try embedded album thumbnail.
    if (playlist.type == PlaylistTypeDB.album &&
        playlist.album?.thumbnail != null &&
        playlist.album!.thumbnail!.url.isNotEmpty) {
      return playlist.album!.thumbnail!.url;
    }

    // For remote playlists, try embedded remotePlaylist thumbnail.
    if (playlist.type == PlaylistTypeDB.remotePlaylist &&
        playlist.remotePlaylist?.thumbnail != null &&
        playlist.remotePlaylist!.thumbnail!.url.isNotEmpty) {
      return playlist.remotePlaylist!.thumbnail!.url;
    }

    // For artists, try embedded artist thumbnail.
    if (playlist.type == PlaylistTypeDB.artist &&
        playlist.artists != null &&
        playlist.artists!.isNotEmpty) {
      final artistThumb = playlist.artists!.first.thumbnail;
      if (artistThumb != null && artistThumb.url.isNotEmpty) {
        return artistThumb.url;
      }
    }

    // For user playlists, use first track's artwork.
    if (playlist.type == PlaylistTypeDB.userPlaylist) {
      final tracks = await _playlistDao.getPlaylistTracks(playlist.id);
      if (tracks.isNotEmpty) {
        final trackUrl = tracks.first.thumbnail?.url;
        if (trackUrl != null && trackUrl.isNotEmpty) return trackUrl;
      }
    }

    return null;
  }

  // ── Playlist CRUD ──────────────────────────────────────────────────────────

  /// Create a new empty playlist.
  Future<void> createPlaylist(String name) async {
    await _playlistDao.createPlaylist(name);
    await _fetchPlaylists();
    SnackbarService.showMessage("Playlist '$name' created!");
  }

  bool _isProtectedPlaylist(String name) {
    return CreatorsChoiceService.isCreatorsChoice(name) ||
        name == PlaylistDAO.likedSongsPlaylist ||
        name == PlaylistDAO.likedPlaylist ||
        name == 'Liked albums';
  }

  /// Delete a playlist by its Isar id.
  Future<void> removePlaylistById(int playlistId) async {
    final playlist = await _playlistDao.getPlaylistById(playlistId);
    if (playlist != null && _isProtectedPlaylist(playlist.name)) {
      log('Cannot remove protected playlist "${playlist.name}"', name: 'LibraryItemsCubit');
      return;
    }
    await _playlistDao.deletePlaylist(playlistId);
    await _fetchPlaylists();
    SnackbarService.showMessage('Playlist removed');
  }

  /// Delete a playlist by name.
  Future<void> removePlaylistByName(String name) async {
    if (_isProtectedPlaylist(name)) {
      log('Cannot remove protected playlist "$name"', name: 'LibraryItemsCubit');
      return;
    }
    if (name.isNotEmpty && name != 'Null') {
      await _playlistDao.deletePlaylistByName(name);
      await _fetchPlaylists();
      SnackbarService.showMessage('Playlist "$name" removed');
    }
  }

  /// Rename an existing playlist.
  Future<bool> renamePlaylist(int playlistId, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return false;
    try {
      final playlist = await _playlistDao.getPlaylistById(playlistId);
      if (playlist != null && _isProtectedPlaylist(playlist.name)) {
        log('Cannot rename protected playlist "${playlist.name}"', name: 'LibraryItemsCubit');
        return false;
      }
      if (_isProtectedPlaylist(trimmed)) {
        SnackbarService.showMessage('Cannot rename to "$trimmed"');
        return false;
      }
      final existing = await _playlistDao.getPlaylistByName(trimmed);
      if (existing != null && existing.id != playlistId) {
        SnackbarService.showMessage('A playlist named "$trimmed" already exists');
        return false;
      }
      await _playlistDao.updatePlaylistMeta(playlistId, name: trimmed);
      SnackbarService.showMessage('Playlist renamed to "$trimmed"');
      await _fetchPlaylists();
      return true;
    } catch (e, stack) {
      log('Error renaming playlist: $e\n$stack', name: 'LibraryItemsCubit');
      SnackbarService.showMessage('Failed to rename playlist: $e');
      return false;
    }
  }

  /// Rename an existing playlist by name.
  Future<bool> renamePlaylistByName(String oldName, String newName) async {
    if (CreatorsChoiceService.isCreatorsChoice(oldName)) {
      log('Cannot rename protected playlist "$oldName"', name: 'LibraryItemsCubit');
      return false;
    }
    final playlist = await _playlistDao.getPlaylistByName(oldName);
    if (playlist == null) return false;
    return renamePlaylist(playlist.id, newName);
  }

  // ── Track management ───────────────────────────────────────────────────────

  /// Add a [Track] to a named playlist.
  Future<void> addToPlaylist(Track track, String playlistName,
      {bool showSnackbar = true}) async {
    if (playlistName == 'Null' || playlistName.isEmpty) return;
    try {
      await _playlistDao.addTrackToPlaylistByName(playlistName, track);
      if (showSnackbar) {
        SnackbarService.showMessage('${track.title} added to $playlistName');
      }
    } catch (e) {
      log('Failed to add "${track.title}" to "$playlistName": $e',
          name: 'LibraryItemsCubit');
      if (showSnackbar) {
        SnackbarService.showMessage(
            'Failed to add to playlist: ${e.toString().split('\n').first}');
      }
    }
  }

  /// Add multiple [Track]s to a named playlist.
  Future<void> addTracksToPlaylist(List<Track> tracks, String playlistName,
      {bool showSnackbar = true}) async {
    if (playlistName.isEmpty || CreatorsChoiceService.isCreatorsChoice(playlistName)) return;
    try {
      final playlist = await _playlistDao.getPlaylistByName(playlistName);
      if (playlist == null) return;
      await _playlistDao.addTracksToPlaylist(playlist.id, tracks);
      if (showSnackbar) {
        SnackbarService.showMessage('${tracks.length} songs added to $playlistName');
      }
    } catch (e) {
      log('Failed to add tracks to "$playlistName": $e', name: 'LibraryItemsCubit');
      if (showSnackbar) {
        SnackbarService.showMessage('Failed to add to playlist: $e');
      }
    }
  }

  /// Add multiple tracks to Liked songs.
  Future<void> likeTracks(List<Track> tracks, {bool showSnackbar = true}) async {
    if (tracks.isEmpty) return;
    try {
      for (final t in tracks) {
        await setTrackLiked(t, true);
      }
      if (showSnackbar) {
        SnackbarService.showMessage('Added ${tracks.length} song${tracks.length == 1 ? '' : 's'} to Liked songs');
      }
    } catch (e) {
      log('Failed to like tracks: $e', name: 'LibraryItemsCubit');
    }
  }

  /// Remove a [Track] from a named playlist.
  Future<void> removeFromPlaylist(Track track, String playlistName,
      {bool showSnackbar = true}) async {
    if (playlistName == 'Null' || playlistName.isEmpty) return;
    final playlist = await _playlistDao.getPlaylistByName(playlistName);
    if (playlist == null) return;
    await _playlistDao.removeTrackFromPlaylist(playlist.id, track.id);
    if (showSnackbar) {
      SnackbarService.showMessage('${track.title} removed from $playlistName');
    }
  }

  /// Get all tracks in a named playlist.
  Future<List<Track>?> getPlaylistTracks(String playlistName) async {
    try {
      final playlist = await _playlistDao.getPlaylistByName(playlistName);
      if (playlist == null) return null;
      final trackDBs = await _playlistDao.getPlaylistTracks(playlist.id);
      return trackDBs.map(trackDBToTrack).toList();
    } catch (e) {
      log('Error getting playlist: $e', name: 'LibraryItemsCubit');
      return null;
    }
  }

  // ── Like helpers ───────────────────────────────────────────────────────────

  /// Check if a track is in the "Liked" playlist.
  Future<bool> isTrackLiked(Track track) async {
    return _playlistDao.isTrackLiked(track.id);
  }

  /// Like or unlike a track.
  Future<void> setTrackLiked(Track track, bool liked) async {
    try {
      await _playlistDao.setTrackLiked(track, liked);
      if (!_trackLikedController.isClosed) {
        _trackLikedController.add((trackId: track.id, isLiked: liked));
      }
    } catch (e, stack) {
      log('Error setting track liked (${track.id}): $e\n$stack',
          name: 'LibraryItemsCubit');
      rethrow;
    }
  }

  /// Get all playlist names containing a given track.
  Future<Set<String>> getPlaylistsContainingTrack(String mediaId) async {
    final names = await _playlistDao.getPlaylistsContainingTrack(mediaId);
    return names.toSet();
  }

  /// Load a full [Playlist] domain model by name.
  Future<Playlist?> getPlaylistByName(String name) async {
    final playlistDB = await _playlistDao.getPlaylistByName(name);
    if (playlistDB == null) return null;
    return _playlistDao.loadPlaylist(name);
  }

  // ── Remote collection save (delegates to LibraryDAO) ───────────────────────

  Future<void> saveRemoteArtist(
      {required ArtistSummary artist,
      required String sourceName,
      bool showSnackbar = true}) async {
    try {
      await _libraryDao.saveArtist(artist, sourceName: sourceName);
      await _fetchPlaylists();
      if (showSnackbar) {
        SnackbarService.showMessage('Artist "${artist.name}" saved to library');
      }
    } catch (e, stack) {
      log('Error saving artist "${artist.name}": $e\n$stack',
          name: 'LibraryItemsCubit');
      if (showSnackbar) {
        SnackbarService.showMessage('Failed to save artist to library');
      }
      rethrow;
    }
  }

  Future<void> saveRemoteAlbum(
      {required AlbumSummary album,
      required String sourceName,
      String? pluginId,
      bool showSnackbar = true}) async {
    try {
      await _libraryDao.saveAlbum(album,
          sourceName: sourceName, pluginId: pluginId);
      await _fetchPlaylists();
      if (showSnackbar) {
        SnackbarService.showMessage('Album "${album.title}" saved to library');
      }
    } catch (e, stack) {
      log('Error saving album "${album.title}": $e\n$stack',
          name: 'LibraryItemsCubit');
      if (showSnackbar) {
        SnackbarService.showMessage('Failed to save album to library');
      }
      rethrow;
    }
  }

  Future<void> saveRemotePlaylist(
      {required PlaylistSummary playlist,
      required String sourceName,
      bool showSnackbar = true}) async {
    try {
      await _libraryDao.saveRemotePlaylist(playlist, sourceName: sourceName);
      await _fetchPlaylists();
      if (showSnackbar) {
        SnackbarService.showMessage(
            'Playlist "${playlist.title}" saved to library');
      }
    } catch (e, stack) {
      log('Error saving playlist "${playlist.title}": $e\n$stack',
          name: 'LibraryItemsCubit');
      if (showSnackbar) {
        SnackbarService.showMessage('Failed to save playlist to library');
      }
      rethrow;
    }
  }

  /// Check if a remote collection is already saved (by mediaId).
  Future<bool> isRemoteSaved(String mediaId, PlaylistType type) {
    return _libraryDao.isSaved(mediaId, type);
  }

  /// Remove a saved remote collection by mediaId.
  Future<void> removeRemoteSaved(String mediaId, PlaylistType type) async {
    try {
      final dbType = playlistTypeToPlaylistTypeDB(type);
      await _libraryDao.removeByMediaId(mediaId, dbType);
      await _fetchPlaylists();
      SnackbarService.showMessage('Removed from library');
    } catch (e, stack) {
      log('Error removing saved item ($mediaId): $e\n$stack',
          name: 'LibraryItemsCubit');
      SnackbarService.showMessage('Failed to remove from library');
      rethrow;
    }
  }

  // ── Navigation target resolution ──────────────────────────────────────────

  /// Resolve a library item by storage key into a domain [Playlist] for navigation.
  ///
  /// The returned [Playlist] carries embedded artist/album/remotePlaylist
  /// domain objects. Returns null if not found.
  Future<Playlist?> resolveLibraryItem(String storageKey) {
    return _libraryDao.resolveByStorageKey(storageKey);
  }

  // ── Search helper for LibrarySearchCubit ──────────────────────────────────

  /// Search tracks by query, returning domain [Track] objects.
  Future<List<Track>> searchTracks(String query) async {
    final results = await _playlistDao.searchLibrary(query);
    return results.map((r) => trackDBToTrack(r.$1)).toList();
  }

  // ── Library Arrangement ─────────────────────────────────────────────────

  /// Toggle pin state for a playlist.
  Future<void> togglePin(int playlistId) async {
    final item =
        state.playlists.where((p) => p.playlistId == playlistId).firstOrNull;
    if (item == null) return;
    await _playlistDao.setPinned(playlistId, !item.isPinned);
  }

  /// Reorder library playlists.
  ///
  /// Called after a drag-and-drop reorder. [oldIndex] and [newIndex] are
  /// positions within the displayed (filtered) list.
  Future<void> reorderLibrary(int oldIndex, int newIndex) async {
    final current = List<PlaylistItemProperties>.from(state.playlists);
    if (oldIndex < newIndex) newIndex -= 1;
    final item = current.removeAt(oldIndex);
    current.insert(newIndex, item);
    // Optimistic UI update.
    emit(state.copyWith(playlists: current));
    // Persist new order.
    await _playlistDao.reorderPlaylists(
      current.map((p) => p.playlistId).toList(),
    );
  }
}
