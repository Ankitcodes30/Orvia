import 'dart:developer';

import 'package:Orvia/blocs/downloader/cubit/downloader_cubit.dart';
import 'package:Orvia/blocs/library/cubit/library_items_cubit.dart';
import 'package:Orvia/blocs/media_player/orvia_player_cubit.dart';
import 'package:Orvia/blocs/offline/cubit/offline_organizer_cubit.dart';
import 'package:Orvia/blocs/offline/cubit/offline_organizer_state.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/core/models/offline_organizer_models.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/screens/widgets/confirmation_dialog.dart';
import 'package:Orvia/screens/widgets/more_bottom_sheet.dart';
import 'package:Orvia/screens/widgets/multi_select_bar.dart';
import 'package:Orvia/screens/widgets/sign_board_widget.dart';
import 'package:Orvia/screens/widgets/snackbar.dart';
import 'package:Orvia/screens/widgets/song_tile.dart';
import 'package:Orvia/utils/load_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

class OfflineCollectionDetailScreen extends StatefulWidget {
  final String collectionId;

  const OfflineCollectionDetailScreen({super.key, required this.collectionId});

  @override
  State<OfflineCollectionDetailScreen> createState() =>
      _OfflineCollectionDetailScreenState();
}

class _OfflineCollectionDetailScreenState
    extends State<OfflineCollectionDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearch = false;

  // Multi-Select Mode
  bool _isMultiSelect = false;
  final Set<String> _selectedTrackIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _exitMultiSelect() {
    setState(() {
      _isMultiSelect = false;
      _selectedTrackIds.clear();
    });
  }

  void _toggleSelectAll(List<Track> displayedTracks) {
    setState(() {
      if (_selectedTrackIds.length == displayedTracks.length) {
        _selectedTrackIds.clear();
      } else {
        _selectedTrackIds.addAll(displayedTracks.map((t) => t.id));
      }
    });
  }

  Future<void> _handleMultiDelete(List<Track> displayedTracks) async {
    final count = _selectedTrackIds.length;
    if (count == 0) return;

    final confirmed = await showConfirmDestructiveDialog(
      context,
      title: 'Delete $count Songs?',
      message:
          'Are you sure you want to delete $count downloaded song${count == 1 ? '' : 's'} from your device?',
      confirmLabel: 'Delete',
    );

    if (confirmed && mounted) {
      final selected =
          displayedTracks.where((t) => _selectedTrackIds.contains(t.id)).toList();
      final downloader = context.read<DownloaderCubit>();
      for (final track in selected) {
        await downloader.removeDownload(track);
      }
      SnackbarService.showMessage(
          'Deleted $count song${count == 1 ? '' : 's'} from device');
      _exitMultiSelect();
    }
  }

  Future<void> _handleMultiLike(List<Track> displayedTracks) async {
    final selected =
        displayedTracks.where((t) => _selectedTrackIds.contains(t.id)).toList();
    if (selected.isEmpty) return;
    await context.read<LibraryItemsCubit>().likeTracks(selected);
    _exitMultiSelect();
  }

  Future<void> _handleMultiAddToPlaylist(List<Track> displayedTracks) async {
    final selected =
        displayedTracks.where((t) => _selectedTrackIds.contains(t.id)).toList();
    if (selected.isEmpty) return;
    await showMultiTrackAddToPlaylistSheet(context, selected);
    _exitMultiSelect();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OfflineOrganizerCubit, OfflineOrganizerState>(
      builder: (context, orgState) {
        if (orgState is! OfflineOrganizerLoaded) {
          return const Scaffold(
            backgroundColor: Default_Theme.themeColor,
            body: Center(
              child: CircularProgressIndicator(
                  color: Default_Theme.accentColor2),
            ),
          );
        }

        final collection =
            orgState.collections.cast<OfflineCollection?>().firstWhere(
                  (c) => c?.id == widget.collectionId,
                  orElse: () => null,
                );

        if (collection == null) {
          return Scaffold(
            backgroundColor: Default_Theme.themeColor,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Default_Theme.primaryColor1),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: const Center(
              child: Text(
                'Collection not found or has been removed.',
                style: TextStyle(color: Default_Theme.primaryColor1),
              ),
            ),
          );
        }

        return BlocBuilder<DownloaderCubit, DownloaderState>(
          builder: (context, downState) {
            final cubit = context.read<OfflineOrganizerCubit>();
            final downloadedTracks = cubit.getCollectionTracks(
                collection.id, downState.downloaded);

            final query = _searchController.text.trim().toLowerCase();
            final displayedTracks = query.isEmpty
                ? downloadedTracks
                : downloadedTracks.where((t) {
                    final title = t.title.toLowerCase();
                    final artists =
                        t.artists.map((a) => a.name.toLowerCase()).join(' ');
                    return title.contains(query) || artists.contains(query);
                  }).toList();

            return Scaffold(
              backgroundColor: Default_Theme.themeColor,
              appBar: _buildAppBar(context, collection),
              body: Column(
                children: [
                  _buildHeader(context, collection, downloadedTracks),
                  if (_isSearch) _buildSearchField(),
                  _buildPlayControls(context, collection, displayedTracks),
                  Expanded(
                    child: displayedTracks.isEmpty
                        ? Center(
                            child: SignBoardWidget(
                              message: downloadedTracks.isEmpty
                                  ? 'No downloaded tracks in this collection yet'
                                  : 'No matching songs found',
                              icon: collection.type == 'album'
                                  ? Icons.album_rounded
                                  : MingCute.playlist_2_line,
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: displayedTracks.length,
                            itemBuilder: (context, index) {
                              final song = displayedTracks[index];
                              final isSelected =
                                  _selectedTrackIds.contains(song.id);
                              return SongCardWidget(
                                song: song,
                                showOptions: !_isMultiSelect,
                                delDownBtn: false,
                                isSelectMode: _isMultiSelect,
                                isSelected: isSelected,
                                onSelectChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedTrackIds.add(song.id);
                                    } else {
                                      _selectedTrackIds.remove(song.id);
                                      if (_selectedTrackIds.isEmpty) {
                                        _isMultiSelect = false;
                                      }
                                    }
                                  });
                                },
                                onLongPress: () {
                                  setState(() {
                                    _isMultiSelect = true;
                                    _selectedTrackIds.add(song.id);
                                  });
                                },
                                onTap: () {
                                  if (_isMultiSelect) {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedTrackIds.remove(song.id);
                                        if (_selectedTrackIds.isEmpty) {
                                          _isMultiSelect = false;
                                        }
                                      } else {
                                        _selectedTrackIds.add(song.id);
                                      }
                                    });
                                    return;
                                  }

                                  try {
                                    context
                                        .read<OrviaPlayerCubit>()
                                        .orviaPlayer
                                        .loadPlaylist(
                                          Playlist(
                                            tracks: displayedTracks,
                                            title: collection.title,
                                          ),
                                          idx: index,
                                          doPlay: true,
                                        );
                                  } catch (e, stack) {
                                    log('Offline collection play crashed',
                                        name: 'OfflineCollectionDetail',
                                        error: e,
                                        stackTrace: stack);
                                    SnackbarService.showMessage(
                                        'Unable to play offline track.');
                                  }
                                },
                                onOptionsTap: () {
                                  showMoreBottomSheet(
                                    context,
                                    song,
                                    showDelete: true,
                                    onDelete: () async {
                                      final confirmed =
                                          await showConfirmDestructiveDialog(
                                        context,
                                        title: 'Delete Song?',
                                        message:
                                            'Are you sure you want to delete this song from your device?',
                                        confirmLabel: 'Delete',
                                      );
                                      if (confirmed && context.mounted) {
                                        await context
                                            .read<DownloaderCubit>()
                                            .removeDownload(song);
                                        SnackbarService.showMessage(
                                            'Deleted "${song.title}" from device');
                                      }
                                    },
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
              bottomNavigationBar: _isMultiSelect
                  ? MultiSelectActionBar(
                      selectedCount: _selectedTrackIds.length,
                      totalCount: displayedTracks.length,
                      onToggleSelectAll: () =>
                          _toggleSelectAll(displayedTracks),
                      onClose: _exitMultiSelect,
                      contextType: MultiSelectContext.offline,
                      onLike: () => _handleMultiLike(displayedTracks),
                      onAddToPlaylist: () =>
                          _handleMultiAddToPlaylist(displayedTracks),
                      onDelete: () => _handleMultiDelete(displayedTracks),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, OfflineCollection collection) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded,
            color: Default_Theme.primaryColor1),
        onPressed: () {
          if (_isMultiSelect) {
            _exitMultiSelect();
          } else {
            Navigator.pop(context);
          }
        },
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isSearch ? Icons.close_rounded : Icons.search_rounded,
            color: Default_Theme.primaryColor1,
          ),
          onPressed: () {
            setState(() {
              _isSearch = !_isSearch;
              if (!_isSearch) _searchController.clear();
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              color: Colors.redAccent),
          tooltip: 'Remove Collection',
          onPressed: () => _showDeleteCollectionDialog(collection),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    OfflineCollection collection,
    List<Track> downloadedTracks,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 80,
              height: 80,
              child: collection.coverUrl != null &&
                      collection.coverUrl!.isNotEmpty
                  ? LoadImageCached(
                      imageUrl: collection.coverUrl!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.white10,
                      child: Icon(
                        collection.type == 'album'
                            ? Icons.album_rounded
                            : MingCute.playlist_2_line,
                        color: Default_Theme.accentColor2,
                        size: 36,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Default_Theme.accentColor2.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    collection.type.toUpperCase(),
                    style: const TextStyle(
                      color: Default_Theme.accentColor2,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  collection.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Default_Theme.primaryColor1,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ).merge(Default_Theme.primaryTextStyle),
                ),
                const SizedBox(height: 4),
                Text(
                  '${downloadedTracks.length} / ${collection.requestedTrackIds.length} downloaded',
                  style: TextStyle(
                    color: Default_Theme.primaryColor1.withValues(alpha: 0.6),
                    fontSize: 13,
                  ).merge(Default_Theme.secondoryTextStyle),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: Default_Theme.primaryColor1),
        decoration: InputDecoration(
          hintText: 'Search songs in this collection...',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon:
              const Icon(Icons.search, color: Default_Theme.primaryColor1),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildPlayControls(
    BuildContext context,
    OfflineCollection collection,
    List<Track> displayedTracks,
  ) {
    if (displayedTracks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: () {
              context.read<OrviaPlayerCubit>().orviaPlayer.loadPlaylist(
                    Playlist(tracks: displayedTracks, title: collection.title),
                    doPlay: true,
                    idx: 0,
                  );
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            label: const Text('Play All'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Default_Theme.accentColor2,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () {
              final shuffled = List<Track>.from(displayedTracks)..shuffle();
              context.read<OrviaPlayerCubit>().orviaPlayer.loadPlaylist(
                    Playlist(tracks: shuffled, title: collection.title),
                    doPlay: true,
                    idx: 0,
                  );
            },
            icon: const Icon(MingCute.shuffle_line, size: 18),
            label: const Text('Shuffle'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Default_Theme.primaryColor1,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteCollectionDialog(OfflineCollection collection) async {
    final confirmed = await showConfirmDestructiveDialog(
      context,
      title: 'Remove Collection?',
      message:
          'Are you sure you want to remove "${collection.title}" from Offline? Downloaded audio files will remain on your device.',
      confirmLabel: 'Remove',
    );

    if (confirmed && mounted) {
      await context
          .read<OfflineOrganizerCubit>()
          .deleteCollection(collection.id);
      if (mounted) {
        Navigator.pop(context);
        SnackbarService.showMessage(
          'Removed "${collection.title}" from Collections.',
        );
      }
    }
  }
}
