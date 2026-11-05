import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import 'package:Orvia/blocs/library/cubit/library_items_cubit.dart';
import 'package:Orvia/blocs/media_player/orvia_player_cubit.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/screens/screen/library_views/cubit/current_playlist_cubit.dart';
import 'package:Orvia/screens/screen/library_views/playlist_edit_view.dart';
import 'package:Orvia/screens/widgets/confirmation_dialog.dart';
import 'package:Orvia/screens/widgets/snackbar.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/l10n/app_localizations.dart';
import 'package:Orvia/services/catalogue/creators_choice_service.dart';
import 'package:Orvia/services/import_export_service.dart';
import 'package:Orvia/services/share/orvia_deep_link_service.dart';

/// Shows options for an internal/local playlist
void showPlaylistOptsInrSheet(BuildContext context, Playlist playlist) {
  int? playlistId;
  try {
    playlistId = context.read<CurrentPlaylistCubit>().playlistId;
  } catch (_) {}

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _PlaylistOptionsSheet(
      title: playlist.title,
      playlistId: playlistId,
      isInternal: true,
      initialTracks: playlist.tracks,
      description: playlist.description,
      parentContext: context,
      onEdit: () async {
        final playlistCubit = context.read<CurrentPlaylistCubit>();
        await playlistCubit.ensureAllTracksLoaded();
        if (!context.mounted) return;
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const PlaylistEditView()));
      },
    ),
  );
}

void showPlaylistOptsExtSheet(
  BuildContext context,
  String playlistName, {
  int? playlistId,
  bool isPinned = false,
  String? artworkUrl,
  String? storageKey,
  String? description,
  Future<void> Function(BuildContext ctx, String title)? onExport,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _PlaylistOptionsSheet(
      title: playlistName,
      playlistId: playlistId,
      isInternal: false,
      isPinned: isPinned,
      parentContext: context,
      artworkUrl: artworkUrl,
      storageKey: storageKey,
      description: description,
      onExport: onExport,
    ),
  );
}

class _PlaylistOptionsSheet extends StatelessWidget {
  final String title;
  final bool isInternal;
  final int? playlistId;
  final bool isPinned;
  final VoidCallback? onEdit;
  final BuildContext? parentContext;
  final List<Track>? initialTracks;
  final String? artworkUrl;
  final String? storageKey;
  final String? description;
  final Future<void> Function(BuildContext ctx, String title)? onExport;

  const _PlaylistOptionsSheet({
    required this.title,
    required this.isInternal,
    this.playlistId,
    this.isPinned = false,
    this.onEdit,
    this.parentContext,
    this.initialTracks,
    this.artworkUrl,
    this.storageKey,
    this.description,
    this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ctx = parentContext ?? context;
    final sheetRoute = ModalRoute.of(context);
    final isProtected = CreatorsChoiceService.isCreatorsChoice(title) ||
        title == 'Liked songs' ||
        title == 'Liked' ||
        title == 'Liked albums' ||
        storageKey == 'liked_albums_collection';
    bool effectiveIsPinned = isPinned;
    if (isInternal) {
      try {
        final libState = ctx.read<LibraryItemsCubit>().state;
        final match = libState.playlists
            .where((p) => p.playlistName == title)
            .firstOrNull;
        if (match != null) effectiveIsPinned = match.isPinned;
      } catch (_) {}
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: Default_Theme.themeColor.withValues(alpha: 0.85),
                border: Border(
                    top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08), width: 1)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 16),
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 8),
                      child: Text(
                        title,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isInternal)
                              _OptionGroup(
                                children: [
                                  _BottomSheetTile(
                                    icon: MingCute.play_circle_fill,
                                    iconColor: Default_Theme.accentColor2,
                                    title: l10n.playlistPlay,
                                    onTap: () async {
                                      final libraryCubit =
                                          ctx.read<LibraryItemsCubit>();
                                      final playerCubit =
                                          ctx.read<OrviaPlayerCubit>();
                                      final list = await libraryCubit
                                          .getPlaylistTracks(title);
                                      if (list != null && list.isNotEmpty) {
                                        playerCubit.orviaPlayer.loadPlaylist(
                                            Playlist(
                                                tracks: list, title: title),
                                            doPlay: true);
                                        SnackbarService.showMessage(
                                            l10n.snackbarNowPlaying(title));
                                      }
                                    },
                                  ),
                                  _BottomSheetTile(
                                    icon: MingCute.playlist_2_line,
                                    title: l10n.playlistAddToQueue,
                                    onTap: () async {
                                      final libraryCubit =
                                          ctx.read<LibraryItemsCubit>();
                                      final playerCubit =
                                          ctx.read<OrviaPlayerCubit>();
                                      final list = await libraryCubit
                                          .getPlaylistTracks(title);
                                      if (list != null && list.isNotEmpty) {
                                        playerCubit.orviaPlayer
                                            .addQueueTracks(list);
                                        SnackbarService.showMessage(
                                            l10n.snackbarPlaylistAddedToQueue(
                                                title));
                                      }
                                    },
                                  ),
                                ],
                              ),
                            if (!isProtected)
                              _OptionGroup(
                              children: [
                                _BottomSheetTile(
                                  icon: MingCute.share_forward_line,
                                  title: l10n.playlistShare,
                                  onTap: () async {
                                    if (OrviaDeepLinkService.isSharing) {
                                      SnackbarService.showMessage('A share operation is already in progress...');
                                      return;
                                    }

                                    LibraryItemsCubit? libraryCubit;
                                    try {
                                      libraryCubit = ctx.read<LibraryItemsCubit>();
                                    } catch (_) {}

                                    CurrentPlaylistCubit? playlistCubit;
                                    if (isInternal) {
                                      try {
                                        playlistCubit = ctx.read<CurrentPlaylistCubit>();
                                      } catch (_) {}
                                    }

                                    // Wait for modal dismiss animation to complete across platforms
                                    // to avoid route transition and window presentation collision.
                                    await Future.any([
                                      if (sheetRoute != null) sheetRoute.completed,
                                      Future.delayed(const Duration(milliseconds: 300)),
                                    ]);

                                    SnackbarService.showMessage(
                                        l10n.snackbarPreparingShare(title));

                                    List<Track>? tracks;
                                    if (isInternal && playlistCubit != null) {
                                      try {
                                        final fullyLoaded = await playlistCubit.ensureAllTracksLoaded();
                                        tracks = fullyLoaded.tracks;
                                      } catch (_) {}
                                    }
                                    if (tracks == null || tracks.isEmpty) {
                                      tracks = initialTracks;
                                    }
                                    if ((tracks == null || tracks.isEmpty) && libraryCubit != null) {
                                      if (storageKey != null && storageKey!.isNotEmpty) {
                                        try {
                                          final resolved = await libraryCubit.resolveLibraryItem(storageKey!);
                                          tracks = resolved?.tracks;
                                        } catch (_) {}
                                      }
                                      if (tracks == null || tracks.isEmpty) {
                                        tracks = await libraryCubit.getPlaylistTracks(title);
                                      }
                                    }

                                    if (tracks == null || tracks.isEmpty) {
                                      SnackbarService.showMessage(
                                          'Cannot share an empty playlist.');
                                      return;
                                    }

                                    if (!ctx.mounted) return;

                                    await OrviaDeepLinkService.sharePlaylist(
                                      ctx,
                                      name: title,
                                      tracks: tracks,
                                      artworkUrl: artworkUrl,
                                      description: description,
                                    );
                                  },
                                ),
                                _BottomSheetTile(
                                  icon: MingCute.file_export_line,
                                  title: l10n.playlistExportFile,
                                  onTap: () async {
                                    // Wait for modal dismiss animation to complete across platforms
                                    // to avoid route transition and window presentation collision.
                                    await Future.any([
                                      if (sheetRoute != null) sheetRoute.completed,
                                      Future.delayed(const Duration(milliseconds: 300)),
                                    ]);

                                    if (!ctx.mounted) return;
                                    if (onExport != null) {
                                      await onExport!(ctx, title);
                                      return;
                                    }
                                    SnackbarService.showMessage(
                                        l10n.snackbarPreparingExport(title));
                                    try {
                                      if (Platform.isAndroid) {
                                        final tmpPath = await ImportExportService
                                            .exportPlaylist(title);
                                        if (tmpPath != null) {
                                          await SharePlus.instance.share(
                                            ShareParams(
                                              files: [XFile(tmpPath)],
                                              text: title,
                                            ),
                                          );
                                        }
                                      } else {
                                        String? path = await FilePicker.platform
                                            .getDirectoryPath();
                                        if (path == null || path == "/") {
                                          path = (await getDownloadsDirectory())
                                              ?.path
                                              .toString();
                                        }
                                        final tmpPath = await ImportExportService
                                            .exportPlaylist(title,
                                                filePath: path);
                                        SnackbarService.showMessage(l10n
                                            .snackbarExportedTo(tmpPath ?? ''));
                                      }
                                    } catch (e, stack) {
                                      log('Error exporting playlist "$title": $e\n$stack',
                                          name: 'more_opts_sheet');
                                      SnackbarService.showMessage(
                                          'Failed to export playlist: $e');
                                    }
                                  },
                                ),
                              ],
                            ),
                            _OptionGroup(
                              children: [
                                if (!isProtected)
                                  _BottomSheetTile(
                                    icon: MingCute.edit_line,
                                    title: 'Rename Playlist',
                                  onTap: () async {
                                    // Wait for modal dismiss animation to complete across platforms
                                    // to avoid route transition and window presentation collision.
                                    await Future.any([
                                      if (sheetRoute != null) sheetRoute.completed,
                                      Future.delayed(const Duration(milliseconds: 300)),
                                    ]);

                                    if (!ctx.mounted) return;
                                    final controller =
                                        TextEditingController(text: title);
                                    final newName = await showDialog<String>(
                                      context: ctx,
                                      builder: (dlgContext) => AlertDialog(
                                        backgroundColor:
                                            Default_Theme.themeColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          side: BorderSide(
                                            color: Colors.white
                                                .withValues(alpha: 0.1),
                                          ),
                                        ),
                                        title: const Text(
                                          'Rename Playlist',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        content: TextField(
                                          controller: controller,
                                          autofocus: true,
                                          style: const TextStyle(
                                              color: Colors.white),
                                          decoration: InputDecoration(
                                            hintText: 'Enter new name',
                                            hintStyle: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.4),
                                            ),
                                            enabledBorder: UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: Default_Theme
                                                    .accentColor2
                                                    .withValues(alpha: 0.5),
                                              ),
                                            ),
                                            focusedBorder:
                                                const UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color:
                                                    Default_Theme.accentColor2,
                                              ),
                                            ),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dlgContext),
                                            child: Text(
                                              'Cancel',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.7),
                                              ),
                                            ),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Default_Theme.accentColor2,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            onPressed: () => Navigator.pop(
                                                dlgContext,
                                                controller.text.trim()),
                                            child: const Text('Rename'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (newName != null &&
                                        newName.trim().isNotEmpty &&
                                        newName.trim() != title.trim()) {
                                      if (!ctx.mounted) return;
                                      final trimmed = newName.trim();
                                      int? targetId = playlistId;
                                      if (targetId == null && isInternal) {
                                        try {
                                          targetId = ctx
                                              .read<CurrentPlaylistCubit>()
                                              .playlistId;
                                        } catch (_) {}
                                      }

                                      final libraryCubit =
                                          ctx.read<LibraryItemsCubit>();
                                      final success = targetId != null
                                          ? await libraryCubit.renamePlaylist(
                                              targetId, trimmed)
                                          : await libraryCubit
                                              .renamePlaylistByName(
                                                  title, trimmed);

                                      if (success &&
                                          isInternal &&
                                          ctx.mounted) {
                                        try {
                                          ctx
                                              .read<CurrentPlaylistCubit>()
                                              .renameCurrentPlaylist(trimmed);
                                        } catch (_) {}
                                      }
                                    }
                                  },
                                ),
                                if (isInternal && !isProtected)
                                  _BottomSheetTile(
                                    icon: MingCute.edit_2_line,
                                    title: l10n.playlistEdit,
                                    onTap: onEdit ?? () {},
                                  ),
                                _BottomSheetTile(
                                  icon: effectiveIsPinned
                                      ? MingCute.unlink_line
                                      : MingCute.pin_2_fill,
                                  iconColor: effectiveIsPinned
                                      ? null
                                      : Default_Theme.accentColor2,
                                  title: effectiveIsPinned
                                      ? l10n.playlistUnpin
                                      : l10n.playlistPinToTop,
                                  onTap: () {
                                    int? targetId = playlistId;
                                    if (targetId == null && isInternal) {
                                      try {
                                        targetId = ctx
                                            .read<CurrentPlaylistCubit>()
                                            .playlistId;
                                      } catch (_) {}
                                    }
                                    if (targetId != null) {
                                      ctx
                                          .read<LibraryItemsCubit>()
                                          .togglePin(targetId);
                                    }
                                  },
                                ),
                                if (!isInternal && !isProtected)
                                  _BottomSheetTile(
                                    icon: MingCute.delete_2_line,
                                    title: l10n.playlistDelete,
                                    iconColor: Colors.redAccent,
                                    titleColor: Colors.redAccent,
                                    onTap: () async {
                                      // Wait for bottom sheet to close
                                      await Future.any([
                                        if (sheetRoute != null) sheetRoute.completed,
                                        Future.delayed(const Duration(milliseconds: 300)),
                                      ]);
                                      if (!ctx.mounted) return;

                                      final confirmed = await showConfirmDestructiveDialog(
                                        ctx,
                                        title: 'Delete Playlist?',
                                        message: 'Are you sure you want to delete "$title"? This cannot be undone.',
                                        confirmLabel: 'Delete',
                                      );
                                      if (!confirmed || !ctx.mounted) return;

                                      final targetId = playlistId;
                                      if (targetId != null) {
                                        ctx
                                            .read<LibraryItemsCubit>()
                                            .removePlaylistById(targetId);
                                      } else if (storageKey != null &&
                                          storageKey!.isNotEmpty) {
                                        ctx
                                            .read<LibraryItemsCubit>()
                                            .removePlaylistByName(storageKey!);
                                      } else {
                                        ctx
                                            .read<LibraryItemsCubit>()
                                            .removePlaylistByName(title);
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Smart "Glass Shelf" Group Container ─────────────────────────────────────

class _OptionGroup extends StatelessWidget {
  final List<Widget> children;
  const _OptionGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04), // Borderless floating card
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: _buildChildrenWithDividers(),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChildrenWithDividers() {
    final List<Widget> result = [];
    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(
          Divider(
            height: 1,
            color:
                Colors.white.withValues(alpha: 0.04), // Ultra subtle separator
            indent: 52, // Perfectly aligns with the start of the text
          ),
        );
      }
    }
    return result;
  }
}

// ── Highly Aesthetic Interactive Tile ────────────────────────────────────────

class _BottomSheetTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? iconColor;
  final Color? titleColor;
  final VoidCallback onTap;

  const _BottomSheetTile({
    required this.icon,
    required this.title,
    this.iconColor,
    this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor =
        iconColor ?? Colors.white.withValues(alpha: 0.55);
    final effectiveTitleColor =
        titleColor ?? Colors.white.withValues(alpha: 0.9);

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      splashColor: Colors.white.withValues(alpha: 0.06),
      highlightColor: Colors.white.withValues(alpha: 0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: effectiveIconColor,
              size: 20,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: effectiveTitleColor,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
