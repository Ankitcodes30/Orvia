part of 'library_items_cubit.dart';

sealed class LibraryItemsState extends Equatable {
  final List<PlaylistItemProperties> playlists;
  final List<ArtistSummary> favouriteArtists;
  final List<AlbumSummary> likedAlbums;

  const LibraryItemsState({
    this.playlists = const [],
    this.favouriteArtists = const [],
    this.likedAlbums = const [],
  });

  @override
  List<Object?> get props => [playlists, favouriteArtists, likedAlbums];

  LibraryItemsState copyWith({
    List<PlaylistItemProperties>? playlists,
    List<ArtistSummary>? favouriteArtists,
    List<AlbumSummary>? likedAlbums,
  }) {
    return LibraryItemsLoaded(
      playlists: playlists ?? this.playlists,
      favouriteArtists: favouriteArtists ?? this.favouriteArtists,
      likedAlbums: likedAlbums ?? this.likedAlbums,
    );
  }
}

/// Library is being loaded for the first time.
final class LibraryItemsLoading extends LibraryItemsState {}

/// Data successfully loaded.
final class LibraryItemsLoaded extends LibraryItemsState {
  const LibraryItemsLoaded({
    required super.playlists,
    super.favouriteArtists = const [],
    super.likedAlbums = const [],
  });
}

/// Error during data fetch.
final class LibraryItemsError extends LibraryItemsState {
  final String message;
  const LibraryItemsError(this.message);

  @override
  List<Object?> get props => [message];
}

/// View-model for a single playlist row in the library list.
///
/// Uses domain [PlaylistType] — never DB types.
class PlaylistItemProperties extends Equatable {
  final String playlistName;
  final String storageKey;
  final String? coverImgUrl;
  final String? subTitle;
  final PlaylistType type;
  final bool isPinned;
  final int sortOrder;
  final int playlistId;

  const PlaylistItemProperties({
    required this.playlistName,
    required this.storageKey,
    this.coverImgUrl,
    this.subTitle,
    this.type = PlaylistType.userPlaylist,
    this.isPinned = false,
    this.sortOrder = 0,
    this.playlistId = 0,
  });

  @override
  List<Object?> get props => [
        playlistName,
        storageKey,
        coverImgUrl,
        subTitle,
        type,
        isPinned,
        sortOrder,
        playlistId
      ];
}
