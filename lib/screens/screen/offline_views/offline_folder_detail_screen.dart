import 'dart:developer';

import 'package:Orvia/blocs/downloader/cubit/downloader_cubit.dart';
import 'package:Orvia/blocs/media_player/orvia_player_cubit.dart';
import 'package:Orvia/blocs/offline/cubit/offline_organizer_cubit.dart';
import 'package:Orvia/blocs/offline/cubit/offline_organizer_state.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/core/models/offline_organizer_models.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/screens/widgets/sign_board_widget.dart';
import 'package:Orvia/screens/widgets/snackbar.dart';
import 'package:Orvia/screens/widgets/song_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OfflineFolderDetailScreen extends StatefulWidget {
  final String folderId;

  const OfflineFolderDetailScreen({super.key, required this.folderId});

  @override
  State<OfflineFolderDetailScreen> createState() =>
      _OfflineFolderDetailScreenState();
}

class _OfflineFolderDetailScreenState extends State<OfflineFolderDetailScreen> {
  bool _isMultiSelect = false;
  final Set<String> _selectedTrackIds = <String>{};
  final TextEditingController _searchController = TextEditingController();
  bool _isSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelectAll(List<Track> tracks) {
    setState(() {
      if (_selectedTrackIds.length == tracks.length) {
        _selectedTrackIds.clear();
      } else {
        _selectedTrackIds.addAll(tracks.map((t) => t.id));
      }
    });
  }

  void _toggleTrackSelection(String trackId) {
    setState(() {
      if (_selectedTrackIds.contains(trackId)) {
        _selectedTrackIds.remove(trackId);
      } else {
        _selectedTrackIds.add(trackId);
      }
    });
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

        final folder = orgState.folders.cast<OfflineFolder?>().firstWhere(
              (f) => f?.id == widget.folderId,
              orElse: () => null,
            );

        if (folder == null) {
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
                'Folder not found or has been deleted.',
                style: TextStyle(color: Default_Theme.primaryColor1),
              ),
            ),
          );
        }

        return BlocBuilder<DownloaderCubit, DownloaderState>(
          builder: (context, downState) {
            final cubit = context.read<OfflineOrganizerCubit>();
            final allFolderTracks =
                cubit.getFolderTracks(folder.id, downState.downloaded);

            final query = _searchController.text.trim().toLowerCase();
            final displayedTracks = query.isEmpty
                ? allFolderTracks
                : allFolderTracks.where((t) {
                    final title = t.title.toLowerCase();
                    final artists =
                        t.artists.map((a) => a.name.toLowerCase()).join(' ');
                    return title.contains(query) || artists.contains(query);
                  }).toList();

            return Scaffold(
              backgroundColor: Default_Theme.themeColor,
              appBar: _buildAppBar(context, folder, allFolderTracks),
              body: Column(
                children: [
                  if (_isSearch) _buildSearchField(),
                  _buildControlsBar(context, folder, allFolderTracks),
                  if (_isMultiSelect)
                    _buildMultiSelectBar(
                        context, folder, displayedTracks, allFolderTracks),
                  Expanded(
                    child: displayedTracks.isEmpty
                        ? Center(
                            child: SignBoardWidget(
                              message: allFolderTracks.isEmpty
                                  ? 'This folder is empty'
                                  : 'No matching songs found',
                              icon: Icons.folder_open_rounded,
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: displayedTracks.length,
                            itemBuilder: (context, index) {
                              final song = displayedTracks[index];
                              final isSelected =
                                  _selectedTrackIds.contains(song.id);

                              return _buildSongItem(
                                context: context,
                                song: song,
                                index: index,
                                allTracks: displayedTracks,
                                folder: folder,
                                isSelected: isSelected,
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    OfflineFolder folder,
    List<Track> folderTracks,
  ) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded,
            color: Default_Theme.primaryColor1),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        folder.name,
        style: const TextStyle(
          color: Default_Theme.primaryColor1,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ).merge(Default_Theme.primaryTextStyle),
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
          icon: const Icon(Icons.edit_outlined,
              color: Default_Theme.primaryColor1),
          tooltip: 'Rename Folder',
          onPressed: () => _showRenameDialog(context, folder),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              color: Colors.redAccent),
          tooltip: 'Delete Folder',
          onPressed: () => _showSafeDeleteFolderDialog(folder),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: Default_Theme.primaryColor1),
        decoration: const InputDecoration(
          hintText: 'Search songs in folder...',
          hintStyle: TextStyle(color: Colors.white38),
          border: InputBorder.none,
          icon: Icon(Icons.search, color: Colors.white38, size: 20),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildControlsBar(
    BuildContext context,
    OfflineFolder folder,
    List<Track> tracks,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Text(
            '${tracks.length} song${tracks.length == 1 ? '' : 's'}',
            style: TextStyle(
              color: Default_Theme.primaryColor1.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ).merge(Default_Theme.secondoryTextStyle),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: tracks.isEmpty
                ? null
                : () {
                    context.read<OrviaPlayerCubit>().orviaPlayer.loadPlaylist(
                          Playlist(tracks: tracks, title: folder.name),
                          doPlay: true,
                          idx: 0,
                        );
                  },
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Play'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Default_Theme.accentColor2,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              _isMultiSelect ? Icons.checklist_rtl_rounded : Icons.checklist_rounded,
              color: _isMultiSelect
                  ? Default_Theme.accentColor2
                  : Default_Theme.primaryColor1,
            ),
            tooltip: _isMultiSelect ? 'Exit Select Mode' : 'Select Songs',
            onPressed: () {
              setState(() {
                _isMultiSelect = !_isMultiSelect;
                if (!_isMultiSelect) _selectedTrackIds.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMultiSelectBar(
    BuildContext context,
    OfflineFolder folder,
    List<Track> displayedTracks,
    List<Track> allFolderTracks,
  ) {
    final count = _selectedTrackIds.length;
    final allSelected =
        displayedTracks.isNotEmpty && count == displayedTracks.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$count of ${displayedTracks.length} selected',
                style: const TextStyle(
                  color: Default_Theme.primaryColor1,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => _toggleSelectAll(displayedTracks),
                child: Text(
                  allSelected ? 'Deselect All' : 'Select All',
                  style: const TextStyle(
                    color: Default_Theme.accentColor2,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.output_rounded,
                label: 'Extract',
                tooltip: 'Extract out of folder',
                enabled: count > 0,
                onTap: () => _performExtract(folder, allFolderTracks),
              ),
              _buildActionButton(
                icon: Icons.drive_file_move_outline,
                label: 'Move',
                tooltip: 'Move to another folder',
                enabled: count > 0,
                onTap: () => _showMoveDialog(context, folder),
              ),
              _buildActionButton(
                icon: Icons.copy_rounded,
                label: 'Copy',
                tooltip: 'Copy to another folder',
                enabled: count > 0,
                onTap: () => _showCopyDialog(context, folder),
              ),
              _buildActionButton(
                icon: Icons.delete_outline_rounded,
                label: 'Remove',
                tooltip: 'Remove from this folder',
                color: Colors.redAccent,
                enabled: count > 0,
                onTap: () => _performRemove(folder, allFolderTracks),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String tooltip,
    required bool enabled,
    required VoidCallback onTap,
    Color? color,
  }) {
    final effectiveColor = enabled
        ? (color ?? Default_Theme.primaryColor1)
        : Colors.white24;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: effectiveColor, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: effectiveColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSongItem({
    required BuildContext context,
    required Track song,
    required int index,
    required List<Track> allTracks,
    required OfflineFolder folder,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        if (_isMultiSelect) {
          _toggleTrackSelection(song.id);
        } else {
          try {
            context.read<OrviaPlayerCubit>().orviaPlayer.loadPlaylist(
                  Playlist(tracks: allTracks, title: folder.name),
                  idx: index,
                  doPlay: true,
                );
          } catch (e, stack) {
            log('Error playing song from folder',
                name: 'OfflineFolderDetail', error: e, stackTrace: stack);
            SnackbarService.showMessage('Unable to play offline track.');
          }
        }
      },
      child: Row(
        children: [
          if (_isMultiSelect)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleTrackSelection(song.id),
                activeColor: Default_Theme.accentColor2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          Expanded(
            child: SongCardWidget(
              song: song,
              showOptions: !_isMultiSelect,
              delDownBtn: true,
              onOptionsTap: () {
                _showSingleSongOptions(context, song, folder, allTracks);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Single Song Options Sheet ─────────────────────────────────────────────

  void _showSingleSongOptions(
    BuildContext context,
    Track song,
    OfflineFolder folder,
    List<Track> allFolderTracks,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Default_Theme.themeColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Default_Theme.primaryColor1,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.output_rounded,
                    color: Default_Theme.primaryColor1),
                title: const Text('Extract out of folder',
                    style: TextStyle(color: Default_Theme.primaryColor1)),
                subtitle: const Text(
                  'Removes folder association; audio remains in All Downloaded Songs',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _extractSpecificTracks(folder, [song.id], allFolderTracks);
                },
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outline,
                    color: Default_Theme.primaryColor1),
                title: const Text('Move to another folder',
                    style: TextStyle(color: Default_Theme.primaryColor1)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => _selectedTrackIds
                    ..clear()
                    ..add(song.id));
                  _showMoveDialog(context, folder);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded,
                    color: Default_Theme.primaryColor1),
                title: const Text('Copy to another folder',
                    style: TextStyle(color: Default_Theme.primaryColor1)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => _selectedTrackIds
                    ..clear()
                    ..add(song.id));
                  _showCopyDialog(context, folder);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent),
                title: const Text('Remove from this folder',
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _removeSpecificTracks(folder, [song.id], allFolderTracks);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Actions: Extract, Move, Copy, Remove ───────────────────────────────────

  Future<void> _performExtract(
    OfflineFolder folder,
    List<Track> allFolderTracks,
  ) async {
    final trackIds = _selectedTrackIds.toList();
    if (trackIds.isEmpty) return;
    await _extractSpecificTracks(folder, trackIds, allFolderTracks);
  }

  Future<void> _extractSpecificTracks(
    OfflineFolder folder,
    List<String> trackIds,
    List<Track> allFolderTracks,
  ) async {
    final cubit = context.read<OfflineOrganizerCubit>();
    await cubit.extractTracksFromFolder(folder.id, trackIds);

    if (!mounted) return;
    setState(() {
      _selectedTrackIds.removeAll(trackIds);
    });

    SnackbarService.showMessage(
      'Extracted ${trackIds.length} song${trackIds.length == 1 ? '' : 's'} out of ${folder.name}',
    );

    // Requirement 8: If extracting leaves the folder empty, prompt to delete
    final remainingCount = allFolderTracks.length - trackIds.length;
    if (remainingCount <= 0) {
      _showEmptyFolderPrompt(folder);
    }
  }

  Future<void> _performRemove(
    OfflineFolder folder,
    List<Track> allFolderTracks,
  ) async {
    final trackIds = _selectedTrackIds.toList();
    if (trackIds.isEmpty) return;
    await _removeSpecificTracks(folder, trackIds, allFolderTracks);
  }

  Future<void> _removeSpecificTracks(
    OfflineFolder folder,
    List<String> trackIds,
    List<Track> allFolderTracks,
  ) async {
    final cubit = context.read<OfflineOrganizerCubit>();
    await cubit.removeTracksFromFolder(folder.id, trackIds);

    if (!mounted) return;
    setState(() {
      _selectedTrackIds.removeAll(trackIds);
    });

    SnackbarService.showMessage(
      'Removed ${trackIds.length} song${trackIds.length == 1 ? '' : 's'} from ${folder.name}',
    );

    final remainingCount = allFolderTracks.length - trackIds.length;
    if (remainingCount <= 0) {
      _showEmptyFolderPrompt(folder);
    }
  }

  void _showMoveDialog(BuildContext context, OfflineFolder currentFolder) {
    final orgCubit = context.read<OfflineOrganizerCubit>();
    final state = orgCubit.state;
    if (state is! OfflineOrganizerLoaded) return;

    final otherFolders =
        state.folders.where((f) => f.id != currentFolder.id).toList();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: Default_Theme.themeColor,
          title: const Text('Move to Folder',
              style: TextStyle(color: Default_Theme.primaryColor1)),
          content: otherFolders.isEmpty
              ? const Text(
                  'No other folders available. Create a new folder first.',
                  style: TextStyle(color: Colors.white70),
                )
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: otherFolders.length,
                    itemBuilder: (ctx, index) {
                      final f = otherFolders[index];
                      return ListTile(
                        leading: const Icon(Icons.folder_rounded,
                            color: Default_Theme.accentColor2),
                        title: Text(f.name,
                            style: const TextStyle(
                                color: Default_Theme.primaryColor1)),
                        subtitle: Text('${f.trackIds.length} songs',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                        onTap: () async {
                          Navigator.pop(dialogCtx);
                          final trackIds = _selectedTrackIds.toList();
                          await orgCubit.moveTracks(
                            sourceFolderId: currentFolder.id,
                            targetFolderId: f.id,
                            trackIds: trackIds,
                          );
                          setState(() => _selectedTrackIds.clear());
                          SnackbarService.showMessage(
                            'Moved ${trackIds.length} song${trackIds.length == 1 ? '' : 's'} to ${f.name}',
                          );
                        },
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white60)),
            ),
          ],
        );
      },
    );
  }

  void _showCopyDialog(BuildContext context, OfflineFolder currentFolder) {
    final orgCubit = context.read<OfflineOrganizerCubit>();
    final state = orgCubit.state;
    if (state is! OfflineOrganizerLoaded) return;

    final otherFolders =
        state.folders.where((f) => f.id != currentFolder.id).toList();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: Default_Theme.themeColor,
          title: const Text('Copy to Folder',
              style: TextStyle(color: Default_Theme.primaryColor1)),
          content: otherFolders.isEmpty
              ? const Text(
                  'No other folders available. Create a new folder first.',
                  style: TextStyle(color: Colors.white70),
                )
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: otherFolders.length,
                    itemBuilder: (ctx, index) {
                      final f = otherFolders[index];
                      return ListTile(
                        leading: const Icon(Icons.folder_copy_rounded,
                            color: Default_Theme.accentColor2),
                        title: Text(f.name,
                            style: const TextStyle(
                                color: Default_Theme.primaryColor1)),
                        subtitle: Text('${f.trackIds.length} songs',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                        onTap: () async {
                          Navigator.pop(dialogCtx);
                          final trackIds = _selectedTrackIds.toList();
                          await orgCubit.copyTracks(
                            targetFolderId: f.id,
                            trackIds: trackIds,
                          );
                          setState(() => _selectedTrackIds.clear());
                          SnackbarService.showMessage(
                            'Copied ${trackIds.length} song${trackIds.length == 1 ? '' : 's'} to ${f.name}',
                          );
                        },
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white60)),
            ),
          ],
        );
      },
    );
  }

  // ── Requirement 8: Empty Folder Prompt ────────────────────────────────────

  void _showEmptyFolderPrompt(OfflineFolder folder) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Default_Theme.themeColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Folder is Empty',
            style: TextStyle(
                color: Default_Theme.primaryColor1,
                fontWeight: FontWeight.bold),
          ),
          content: Text(
            'This folder "${folder.name}" is now empty. Would you like to delete the empty folder?',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), // Keep folder
              child: const Text('No, Keep Folder',
                  style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await context
                    .read<OfflineOrganizerCubit>()
                    .deleteFolder(folder.id, deleteAudioFiles: false);
                if (mounted) {
                  Navigator.pop(context); // Exit detail view back to Offline
                  SnackbarService.showMessage('Deleted empty folder "${folder.name}"');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Yes, Delete Folder'),
            ),
          ],
        );
      },
    );
  }

  // ── Requirement 7: Safe Deletion Confirmation ─────────────────────────────

  Future<void> _showSafeDeleteFolderDialog(OfflineFolder folder) async {
    final cubit = context.read<OfflineOrganizerCubit>();
    final downloader = context.read<DownloaderCubit>();
    final impact = await cubit.getFolderDeleteImpact(folder.id);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Default_Theme.themeColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Delete Folder "${folder.name}"?',
            style: const TextStyle(
                color: Default_Theme.primaryColor1,
                fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This folder contains ${impact.totalTracks} song${impact.totalTracks == 1 ? '' : 's'}.',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              if (impact.sharedTracksCount > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined,
                          color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${impact.sharedTracksCount} song${impact.sharedTracksCount == 1 ? '' : 's'} are also organized in other folders/collections and will remain safely on your device.',
                          style: const TextStyle(
                              color: Colors.green, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (impact.uniqueTracksCount > 0) ...[
                const SizedBox(height: 10),
                Text(
                  '${impact.uniqueTracksCount} song${impact.uniqueTracksCount == 1 ? '' : 's'} exist only in this folder.',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Choose how you want to proceed:',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white60)),
            ),
            OutlinedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await cubit.deleteFolder(folder.id, deleteAudioFiles: false);
                if (mounted) {
                  Navigator.pop(context);
                  SnackbarService.showMessage(
                    'Deleted folder "${folder.name}". Audio files preserved in All Downloads.',
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Default_Theme.accentColor2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Delete Folder Only',
                  style: TextStyle(color: Default_Theme.accentColor2)),
            ),
            if (impact.uniqueTracksCount > 0)
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await cubit.deleteFolder(
                    folder.id,
                    deleteAudioFiles: true,
                    downloaderCubit: downloader,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    SnackbarService.showMessage(
                      'Deleted folder and removed ${impact.uniqueTracksCount} unique audio file(s).',
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Delete Folder & Files'),
              ),
          ],
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context, OfflineFolder folder) {
    final controller = TextEditingController(text: folder.name);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Default_Theme.themeColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Rename Folder',
              style: TextStyle(color: Default_Theme.primaryColor1)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Default_Theme.primaryColor1),
            decoration: const InputDecoration(
              hintText: 'Folder name',
              hintStyle: TextStyle(color: Colors.white38),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  Navigator.pop(ctx);
                  await context
                      .read<OfflineOrganizerCubit>()
                      .renameFolder(folder.id, newName);
                  SnackbarService.showMessage('Folder renamed to "$newName"');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Default_Theme.accentColor2,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
  }
}
