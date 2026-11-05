import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

import 'package:Orvia/blocs/library/cubit/library_items_cubit.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/services/catalogue/creators_choice_service.dart';

/// Context type determining which batch actions are available in Multi-Select Mode.
enum MultiSelectContext {
  /// Home, Search, Online Album, Online Playlist
  discovery,

  /// Offline section (All Songs, Collection details)
  offline,

  /// User-created or editable playlist
  userPlaylist,
}

/// Floating or pinned bottom action bar shown during Multi-Select Mode.
class MultiSelectActionBar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final VoidCallback onToggleSelectAll;
  final VoidCallback onClose;
  final MultiSelectContext contextType;
  final VoidCallback? onLike;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;
  final VoidCallback? onRemoveFromPlaylist;

  const MultiSelectActionBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.onToggleSelectAll,
    required this.onClose,
    required this.contextType,
    this.onLike,
    this.onAddToPlaylist,
    this.onDownload,
    this.onDelete,
    this.onRemoveFromPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final allSelected = selectedCount > 0 && selectedCount == totalCount;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Default_Theme.themeColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Close / Exit selection
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                  tooltip: 'Exit Selection',
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),

                // Selected count
                Text(
                  '$selectedCount selected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),

                // Select All / Deselect All toggle
                TextButton(
                  onPressed: onToggleSelectAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    allSelected ? 'Deselect All' : 'Select All',
                    style: const TextStyle(
                      color: Default_Theme.accentColor2,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const Spacer(),

                // Action 1: Like (Available in all contexts)
                if (onLike != null)
                  IconButton(
                    icon: const Icon(MingCute.heart_line, color: Colors.white, size: 20),
                    tooltip: 'Like Songs',
                    onPressed: selectedCount == 0 ? null : onLike,
                  ),

                // Action 2: Add to Playlist (Discovery & Offline)
                if (onAddToPlaylist != null)
                  IconButton(
                    icon: const Icon(Icons.playlist_add_rounded, color: Colors.white, size: 22),
                    tooltip: 'Add to Playlist',
                    onPressed: selectedCount == 0 ? null : onAddToPlaylist,
                  ),

                // Action 3: Download (Discovery & User Playlists)
                if (onDownload != null && contextType != MultiSelectContext.offline)
                  IconButton(
                    icon: const Icon(MingCute.download_2_line, color: Colors.white, size: 20),
                    tooltip: 'Download Songs',
                    onPressed: selectedCount == 0 ? null : onDownload,
                  ),

                // Action 4: Delete from Device (Offline only)
                if (onDelete != null && contextType == MultiSelectContext.offline)
                  IconButton(
                    icon: const Icon(MingCute.delete_2_line, color: Colors.redAccent, size: 20),
                    tooltip: 'Delete Songs',
                    onPressed: selectedCount == 0 ? null : onDelete,
                  ),

                // Action 5: Remove from Playlist (User Playlist only)
                if (onRemoveFromPlaylist != null && contextType == MultiSelectContext.userPlaylist)
                  IconButton(
                    icon: const Icon(MingCute.delete_2_line, color: Colors.redAccent, size: 20),
                    tooltip: 'Remove from Playlist',
                    onPressed: selectedCount == 0 ? null : onRemoveFromPlaylist,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens a playlist picker bottom sheet for multiple tracks,
/// strictly excluding Creator's Choice and system playlists.
Future<void> showMultiTrackAddToPlaylistSheet(
  BuildContext context,
  List<Track> tracks,
) async {
  if (tracks.isEmpty) return;

  final libraryCubit = context.read<LibraryItemsCubit>();
  final libState = libraryCubit.state;

  // Filter only user-created playlists and strictly exclude Creator's Choice & system playlists
  final userPlaylists = libState.playlists.where((p) {
    return p.type == PlaylistType.userPlaylist &&
        !CreatorsChoiceService.isCreatorsChoice(p.playlistName) &&
        p.playlistName != 'recently_played' &&
        p.playlistName != 'downloadPlaylist' &&
        p.playlistName != 'localMusicPlaylist';
  }).toList();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetCtx).size.height * 0.65,
        ),
        decoration: BoxDecoration(
          color: Default_Theme.themeColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add ${tracks.length} song${tracks.length == 1 ? '' : 's'} to...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12),
              Expanded(
                child: userPlaylists.isEmpty
                    ? const Center(
                        child: Text(
                          'No custom playlists found.\nCreate one in Library to add songs.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        itemCount: userPlaylists.length,
                        itemBuilder: (ctx, idx) {
                          final p = userPlaylists[idx];
                          return ListTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Default_Theme.accentColor2.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                MingCute.playlist_2_line,
                                color: Default_Theme.accentColor2,
                              ),
                            ),
                            title: Text(
                              p.playlistName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: p.subTitle != null
                                ? Text(
                                    p.subTitle!,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  )
                                : null,
                            onTap: () async {
                              Navigator.pop(sheetCtx);
                              await libraryCubit.addTracksToPlaylist(
                                tracks,
                                p.playlistName,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
