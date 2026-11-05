import 'dart:ui';

import 'package:Orvia/blocs/offline/cubit/offline_organizer_cubit.dart';
import 'package:Orvia/blocs/offline/cubit/offline_organizer_state.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/screens/widgets/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

/// Opens a bottom sheet to add [track] or [trackIds] to one or more folders.
void showFolderPickerSheet({
  required BuildContext context,
  Track? track,
  List<String>? trackIds,
}) {
  final targetIds = trackIds ?? (track != null ? [track.id] : <String>[]);
  if (targetIds.isEmpty) return;

  final organizerCubit = context.read<OfflineOrganizerCubit>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (sheetCtx) {
      return BlocProvider.value(
        value: organizerCubit,
        child: _FolderPickerContent(
          trackIds: targetIds,
          trackTitle: track?.title,
        ),
      );
    },
  );
}

class _FolderPickerContent extends StatelessWidget {
  final List<String> trackIds;
  final String? trackTitle;

  const _FolderPickerContent({
    required this.trackIds,
    this.trackTitle,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.75;

    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: mediaQuery.viewInsets.bottom + 16,
        top: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Default_Theme.themeColor.withValues(alpha: 0.96),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.folder_special_rounded,
                          color: Default_Theme.accentColor2,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Add to Offline Folder',
                                style: TextStyle(
                                  color: Default_Theme.primaryColor1,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (trackTitle != null)
                                Text(
                                  trackTitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Default_Theme.primaryColor1
                                        .withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Default_Theme.primaryColor1),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white12),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            Default_Theme.accentColor2.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(MingCute.add_line,
                          color: Default_Theme.accentColor2, size: 20),
                    ),
                    title: const Text(
                      'Create New Folder',
                      style: TextStyle(
                        color: Default_Theme.accentColor2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () => _showCreateFolderDialog(context),
                  ),
                  const Divider(height: 1, color: Colors.white10),
                  Expanded(
                    child: BlocBuilder<OfflineOrganizerCubit,
                        OfflineOrganizerState>(
                      builder: (context, state) {
                        if (state is! OfflineOrganizerLoaded ||
                            state.folders.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Text(
                                'No offline folders yet. Tap "Create New Folder" above.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 13),
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: state.folders.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: Colors.white10),
                          itemBuilder: (context, index) {
                            final folder = state.folders[index];
                            final containsAll = trackIds
                                .every((id) => folder.trackIds.contains(id));

                            return ListTile(
                              leading: const Icon(Icons.folder_rounded,
                                  color: Colors.white70),
                              title: Text(
                                folder.name,
                                style: const TextStyle(
                                    color: Default_Theme.primaryColor1),
                              ),
                              subtitle: Text(
                                '${folder.trackIds.length} song${folder.trackIds.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12),
                              ),
                              trailing: containsAll
                                  ? const Icon(Icons.check_circle_rounded,
                                      color: Colors.green)
                                  : const Icon(Icons.add_rounded,
                                      color: Colors.white54),
                              onTap: () async {
                                final cubit =
                                    context.read<OfflineOrganizerCubit>();
                                if (containsAll) {
                                  await cubit.removeTracksFromFolder(
                                      folder.id, trackIds);
                                  SnackbarService.showMessage(
                                      'Removed from ${folder.name}');
                                } else {
                                  await cubit.addTracksToFolder(
                                      folder.id, trackIds);
                                  SnackbarService.showMessage(
                                      'Added to ${folder.name}');
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
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateFolderDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: Default_Theme.themeColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('New Folder',
              style: TextStyle(color: Default_Theme.primaryColor1)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Default_Theme.primaryColor1),
            decoration: const InputDecoration(
              hintText: 'Enter folder name',
              hintStyle: TextStyle(color: Colors.white38),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(dialogCtx);
                  final cubit = context.read<OfflineOrganizerCubit>();
                  final newFolder = await cubit.createFolder(name);
                  await cubit.addTracksToFolder(newFolder.id, trackIds);
                  SnackbarService.showMessage('Added to "${newFolder.name}"');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Default_Theme.accentColor2,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Create & Add'),
            ),
          ],
        );
      },
    );
  }
}
