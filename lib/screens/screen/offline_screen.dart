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
import 'package:Orvia/l10n/app_localizations.dart';
import 'package:Orvia/screens/screen/offline_views/offline_collection_detail_screen.dart';
import 'package:Orvia/screens/widgets/confirmation_dialog.dart';
import 'package:Orvia/screens/widgets/downloading_item.dart';
import 'package:Orvia/screens/widgets/more_bottom_sheet.dart';
import 'package:Orvia/screens/widgets/multi_select_bar.dart';
import 'package:Orvia/screens/widgets/sign_board_widget.dart';
import 'package:Orvia/screens/widgets/snackbar.dart';
import 'package:Orvia/screens/widgets/song_tile.dart';
import 'package:Orvia/utils/load_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key});

  static _OfflineScreenState? _activeInstance;

  /// Public helper to immediately clear active multi-selection when
  /// navigating away from the Offline tab across bottom navigation.
  static void clearSelectionIfActive() {
    _activeInstance?._exitMultiSelect();
  }

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  int _selectedTabIndex = 0; // 0: All Songs, 1: Collections
  bool _isSearch = false;
  final TextEditingController _searchController = TextEditingController();
  List<Track> _filteredSongs = [];

  // Multi-Select Mode
  bool _isMultiSelect = false;
  final Set<String> _selectedTrackIds = {};

  @override
  void initState() {
    super.initState();
    OfflineScreen._activeInstance = this;
    final downloaderState = context.read<DownloaderCubit>().state;
    _filteredSongs = downloaderState.downloaded;
    _searchController.addListener(_filterSongs);
  }

  @override
  void dispose() {
    if (OfflineScreen._activeInstance == this) {
      OfflineScreen._activeInstance = null;
    }
    _searchController.removeListener(_filterSongs);
    _searchController.dispose();
    super.dispose();
  }

  void _filterSongs() {
    final downloaderState = context.read<DownloaderCubit>().state;
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSongs = downloaderState.downloaded
          .where((song) =>
              "${song.title.toLowerCase()} ${song.artists.map((a) => a.name).join(', ').toLowerCase()}"
                  .contains(query))
          .toList();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearch = !_isSearch;
      if (!_isSearch) {
        _searchController.clear();
        final downloaderState = context.read<DownloaderCubit>().state;
        _filteredSongs = downloaderState.downloaded;
      }
    });
  }

  void _exitMultiSelect() {
    if (!mounted) return;
    if (!_isMultiSelect && _selectedTrackIds.isEmpty) return;
    setState(() {
      _isMultiSelect = false;
      _selectedTrackIds.clear();
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedTrackIds.length == _filteredSongs.length) {
        _selectedTrackIds.clear();
      } else {
        _selectedTrackIds.addAll(_filteredSongs.map((t) => t.id));
      }
    });
  }

  List<Track> _getSelectedTracks() {
    return _filteredSongs
        .where((s) => _selectedTrackIds.contains(s.id))
        .toList();
  }

  Future<void> _handleMultiDelete() async {
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
      final selected = _getSelectedTracks();
      final downloader = context.read<DownloaderCubit>();
      for (final track in selected) {
        await downloader.removeDownload(track);
      }
      SnackbarService.showMessage(
          'Deleted $count song${count == 1 ? '' : 's'} from device');
      _exitMultiSelect();
    }
  }

  Future<void> _handleMultiLike() async {
    final selected = _getSelectedTracks();
    if (selected.isEmpty) return;
    await context.read<LibraryItemsCubit>().likeTracks(selected);
    _exitMultiSelect();
  }

  Future<void> _handleMultiAddToPlaylist() async {
    final selected = _getSelectedTracks();
    if (selected.isEmpty) return;
    await showMultiTrackAddToPlaylistSheet(context, selected);
    _exitMultiSelect();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Scaffold(
        backgroundColor: Default_Theme.themeColor,
        body: BlocBuilder<DownloaderCubit, DownloaderState>(
          builder: (context, state) {
            if (_searchController.text.isEmpty) {
              _filteredSongs = state.downloaded;
            }
            return CustomScrollView(
              slivers: [
                customDiscoverSliverBar(context, l10n),
                SliverToBoxAdapter(
                  child: _buildTabBar(),
                ),
                if (_selectedTabIndex == 0)
                  _buildAllSongsSliver(context, state, l10n)
                else
                  _buildCollectionsSliver(context, state),
              ],
            );
          },
        ),
        bottomNavigationBar: _isMultiSelect && _selectedTabIndex == 0
            ? MultiSelectActionBar(
                selectedCount: _selectedTrackIds.length,
                totalCount: _filteredSongs.length,
                onToggleSelectAll: _toggleSelectAll,
                onClose: _exitMultiSelect,
                contextType: MultiSelectContext.offline,
                onLike: _handleMultiLike,
                onAddToPlaylist: _handleMultiAddToPlaylist,
                onDelete: _handleMultiDelete,
              )
            : null,
      ),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildTabPill(
              index: 0, label: 'All Songs', icon: MingCute.music_2_line),
          const SizedBox(width: 8),
          _buildTabPill(
              index: 1, label: 'Collections', icon: Icons.album_outlined),
        ],
      ),
    );
  }

  Widget _buildTabPill({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (_isMultiSelect) _exitMultiSelect();
          setState(() => _selectedTabIndex = index);
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Default_Theme.accentColor2
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? Default_Theme.accentColor2
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.white70,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab 0: All Downloaded Songs ───────────────────────────────────────────

  Widget _buildAllSongsSliver(
    BuildContext context,
    DownloaderState state,
    AppLocalizations l10n,
  ) {
    if (state.downloads.isEmpty && state.downloaded.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: SignBoardWidget(
            message: l10n.offlineNoDownloads,
            icon: FontAwesome.download_solid,
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildListDelegate(
        [
          ...state.downloads.map(
              (download) => DownloadingCardWidget(downloadProgress: download)),
          ..._filteredSongs.map(
            (song) {
              final isSelected = _selectedTrackIds.contains(song.id);
              return SongCardWidget(
                song: song,
                showOptions: !_isMultiSelect,
                delDownBtn: false, // direct delete removed per requirement 7
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

                  final selectedIndex = state.downloaded.indexWhere(
                    (item) => item.id == song.id,
                  );

                  if (selectedIndex < 0 || state.downloaded.isEmpty) {
                    SnackbarService.showMessage(l10n.offlineOpenFailed);
                    log(
                      'Offline play failed: missing track in downloaded list (${song.id})',
                      name: 'OfflineScreen',
                    );
                    return;
                  }

                  try {
                    context.read<OrviaPlayerCubit>().orviaPlayer.loadPlaylist(
                          Playlist(
                            tracks: state.downloaded,
                            title: "Offline",
                          ),
                          idx: selectedIndex,
                          doPlay: true,
                        );
                  } catch (e, stack) {
                    log(
                      'Offline play crashed for ${song.id}',
                      name: 'OfflineScreen',
                      error: e,
                      stackTrace: stack,
                    );
                    SnackbarService.showMessage(l10n.offlinePlayFailed);
                  }
                },
                onOptionsTap: () {
                  showMoreBottomSheet(
                    context,
                    song,
                    showDelete: true,
                    onDelete: () async {
                      final confirmed = await showConfirmDestructiveDialog(
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
        ],
      ),
    );
  }

  // ── Tab 1: Collections ────────────────────────────────────────────────────

  Widget _buildCollectionsSliver(
      BuildContext context, DownloaderState downState) {
    return BlocBuilder<OfflineOrganizerCubit, OfflineOrganizerState>(
      builder: (context, orgState) {
        if (orgState is! OfflineOrganizerLoaded) {
          return const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(
                  color: Default_Theme.accentColor2),
            ),
          );
        }

        final collections = orgState.collections;
        final cubit = context.read<OfflineOrganizerCubit>();

        return SliverList(
          delegate: SliverChildListDelegate(
            [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  '${collections.length} Collection${collections.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color:
                        Default_Theme.primaryColor1.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ).merge(Default_Theme.secondoryTextStyle),
                ),
              ),
              if (collections.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(
                    child: SignBoardWidget(
                      message:
                          'No offline collections yet.\nUse Bulk Download in playlists or albums to save collections here.',
                      icon: Icons.album_rounded,
                    ),
                  ),
                )
              else
                ...collections.map((col) {
                  final validTracks =
                      cubit.getCollectionTracks(col.id, downState.downloaded);
                  return _buildCollectionTile(context, col, validTracks);
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCollectionTile(
    BuildContext context,
    OfflineCollection col,
    List<Track> validTracks,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 48,
            height: 48,
            child: col.coverUrl != null && col.coverUrl!.isNotEmpty
                ? LoadImageCached(
                    imageUrl: col.coverUrl!,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: Default_Theme.accentColor2.withValues(alpha: 0.15),
                    child: Icon(
                      col.type == 'album'
                          ? Icons.album_rounded
                          : MingCute.playlist_2_line,
                      color: Default_Theme.accentColor2,
                      size: 24,
                    ),
                  ),
          ),
        ),
        title: Text(
          col.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Default_Theme.primaryColor1,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ).merge(Default_Theme.primaryTextStyle),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Default_Theme.accentColor2.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                col.type.toUpperCase(),
                style: const TextStyle(
                  color: Default_Theme.accentColor2,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${validTracks.length} / ${col.requestedTrackIds.length} downloaded',
              style: TextStyle(
                color: Default_Theme.primaryColor1.withValues(alpha: 0.6),
                fontSize: 12,
              ).merge(Default_Theme.secondoryTextStyle),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (validTracks.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.play_circle_fill_rounded,
                    color: Default_Theme.accentColor2, size: 30),
                tooltip: 'Play Collection',
                onPressed: () {
                  context.read<OrviaPlayerCubit>().orviaPlayer.loadPlaylist(
                        Playlist(tracks: validTracks, title: col.title),
                        doPlay: true,
                        idx: 0,
                      );
                },
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent, size: 20),
              tooltip: 'Remove Collection',
              onPressed: () => _showDeleteCollectionDialog(context, col),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  OfflineCollectionDetailScreen(collectionId: col.id),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showDeleteCollectionDialog(
      BuildContext context, OfflineCollection col) async {
    final confirmed = await showConfirmDestructiveDialog(
      context,
      title: 'Remove Collection?',
      message:
          'Are you sure you want to remove "${col.title}" from Offline? Downloaded audio files will remain on your device.',
      confirmLabel: 'Remove',
    );

    if (confirmed && context.mounted) {
      await context.read<OfflineOrganizerCubit>().deleteCollection(col.id);
      SnackbarService.showMessage('Removed collection "${col.title}"');
    }
  }

  // ── Sliver AppBar ─────────────────────────────────────────────────────────

  SliverAppBar customDiscoverSliverBar(
      BuildContext context, AppLocalizations l10n) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      surfaceTintColor: Default_Theme.themeColor,
      backgroundColor: Default_Theme.themeColor,
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (Widget child, Animation<double> animation) {
          final slideAnimation = Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ));
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: slideAnimation,
              child: child,
            ),
          );
        },
        child: _isSearch ? _buildSearchField(l10n) : _buildTitle(l10n),
      ),
      actions: [
        !_isSearch
            ? Tooltip(
                message: l10n.offlineRefreshTooltip,
                child: IconButton(
                  icon: const Icon(MingCute.refresh_2_line),
                  onPressed: () {
                    context.read<DownloaderCubit>().refreshDownloadedSongs();
                    context.read<OfflineOrganizerCubit>().loadData();
                  },
                ),
              )
            : const SizedBox.shrink(),
        Tooltip(
          message:
              _isSearch ? l10n.offlineCloseSearch : l10n.offlineSearchTooltip,
          child: IconButton(
            icon: Icon(
              _isSearch ? Icons.close : Icons.search,
              color: Default_Theme.primaryColor1,
            ),
            onPressed: _toggleSearch,
          ),
        ),
      ],
    );
  }

  Widget _buildTitle(AppLocalizations l10n) {
    return Container(
      key: const ValueKey('title'),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l10n.offlineTitle,
              style: Default_Theme.primaryTextStyle.merge(const TextStyle(
                  fontSize: 34, color: Default_Theme.primaryColor1))),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildSearchField(AppLocalizations l10n) {
    return Container(
      key: const ValueKey('search'),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        cursorColor: Default_Theme.primaryColor1,
        decoration: InputDecoration(
          hintText: l10n.offlineSearchHint,
          border: InputBorder.none,
          hintStyle: TextStyle(
              color: Default_Theme.primaryColor1.withValues(alpha: 0.7)),
        ),
        style: Default_Theme.secondoryTextStyle.merge(
          const TextStyle(
            color: Default_Theme.primaryColor1,
            fontSize: 15.0,
          ),
        ),
      ),
    );
  }
}
