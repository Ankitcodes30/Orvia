import 'dart:ui';

import 'package:Orvia/blocs/downloader/cubit/downloader_cubit.dart';
import 'package:Orvia/blocs/offline/cubit/offline_organizer_cubit.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/screens/widgets/snackbar.dart';
import 'package:Orvia/utils/load_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

/// Opens the Bulk Download modal bottom sheet for a playlist or album.
void showBulkDownloadSheet({
  required BuildContext context,
  required String collectionId,
  required String title,
  required String type, // 'playlist' or 'album'
  String? coverUrl,
  required List<Track> tracks,
}) {
  if (tracks.isEmpty) {
    SnackbarService.showMessage('No songs available to download.');
    return;
  }

  final downloaderCubit = context.read<DownloaderCubit>();
  final offlineCubit = context.read<OfflineOrganizerCubit>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    elevation: 0,
    constraints: const BoxConstraints(maxWidth: 540),
    builder: (sheetContext) {
      return MultiBlocProvider(
        providers: [
          BlocProvider.value(value: downloaderCubit),
          BlocProvider.value(value: offlineCubit),
        ],
        child: _BulkDownloadSheetContent(
          collectionId: collectionId,
          title: title,
          type: type,
          coverUrl: coverUrl,
          tracks: tracks,
        ),
      );
    },
  );
}

class _BulkDownloadSheetContent extends StatefulWidget {
  final String collectionId;
  final String title;
  final String type;
  final String? coverUrl;
  final List<Track> tracks;

  const _BulkDownloadSheetContent({
    required this.collectionId,
    required this.title,
    required this.type,
    this.coverUrl,
    required this.tracks,
  });

  @override
  State<_BulkDownloadSheetContent> createState() =>
      _BulkDownloadSheetContentState();
}

class _BulkDownloadSheetContentState extends State<_BulkDownloadSheetContent> {
  late final Set<String> _selectedTrackIds;

  @override
  void initState() {
    super.initState();
    // Pre-select all tracks by default
    _selectedTrackIds = widget.tracks.map((t) => t.id).toSet();
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedTrackIds.length == widget.tracks.length) {
        _selectedTrackIds.clear();
      } else {
        _selectedTrackIds.addAll(widget.tracks.map((t) => t.id));
      }
    });
  }

  void _toggleTrack(String id) {
    setState(() {
      if (_selectedTrackIds.contains(id)) {
        _selectedTrackIds.remove(id);
      } else {
        _selectedTrackIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.85;

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
                  _buildHeader(context),
                  const Divider(height: 1, color: Colors.white12),
                  _buildControlsBar(),
                  const Divider(height: 1, color: Colors.white12),
                  Expanded(
                    child: BlocBuilder<DownloaderCubit, DownloaderState>(
                      builder: (context, downloadState) {
                        return ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          itemCount: widget.tracks.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: Colors.white10),
                          itemBuilder: (context, index) {
                            final track = widget.tracks[index];
                            final isSelected =
                                _selectedTrackIds.contains(track.id);
                            final isDownloaded = context
                                .read<DownloaderCubit>()
                                .isDownloaded(track.id);

                            final activeDownload = downloadState.downloads
                                .cast<dynamic>()
                                .firstWhere(
                                  (d) => d.task.mediaId == track.id,
                                  orElse: () => null,
                                );

                            return _buildTrackTile(
                              track: track,
                              isSelected: isSelected,
                              isDownloaded: isDownloaded,
                              activeDownload: activeDownload,
                            );
                          },
                        );
                      },
                    ),
                  ),
                  _buildBottomBar(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Default_Theme.accentColor2.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              MingCute.download_2_line,
              color: Default_Theme.accentColor2,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bulk Download',
                  style: const TextStyle(
                    color: Default_Theme.primaryColor1,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ).merge(Default_Theme.primaryTextStyle),
                ),
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Default_Theme.primaryColor1.withValues(alpha: 0.7),
                    fontSize: 13,
                  ).merge(Default_Theme.secondoryTextStyle),
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
    );
  }

  Widget _buildControlsBar() {
    final allSelected = _selectedTrackIds.length == widget.tracks.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_selectedTrackIds.length} of ${widget.tracks.length} selected',
            style: TextStyle(
              color: Default_Theme.primaryColor1.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ).merge(Default_Theme.secondoryTextStyle),
          ),
          TextButton.icon(
            onPressed: _toggleSelectAll,
            icon: Icon(
              allSelected
                  ? Icons.deselect_rounded
                  : Icons.select_all_rounded,
              size: 16,
              color: Default_Theme.accentColor2,
            ),
            label: Text(
              allSelected ? 'Deselect All' : 'Select All',
              style: const TextStyle(
                color: Default_Theme.accentColor2,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackTile({
    required Track track,
    required bool isSelected,
    required bool isDownloaded,
    dynamic activeDownload,
  }) {
    final imageUrl = track.thumbnail.urlHigh ?? track.thumbnail.url;
    final artists = track.artists.map((a) => a.name).join(', ');

    return InkWell(
      onTap: () => _toggleTrack(track.id),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleTrack(track.id),
              activeColor: Default_Theme.accentColor2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 44,
                child: LoadImageCached(
                  imageUrl: imageUrl,
                  fallbackUrl: track.thumbnail.url,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Default_Theme.primaryColor1,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ).merge(Default_Theme.primaryTextStyle),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    artists.isEmpty ? 'Unknown Artist' : artists,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Default_Theme.primaryColor1.withValues(alpha: 0.6),
                      fontSize: 12,
                    ).merge(Default_Theme.secondoryTextStyle),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildStatusIndicator(
              isDownloaded: isDownloaded,
              activeDownload: activeDownload,
              onRetry: () {
                context.read<DownloaderCubit>().downloadSong(track);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator({
    required bool isDownloaded,
    dynamic activeDownload,
    required VoidCallback onRetry,
  }) {
    if (isDownloaded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
            SizedBox(width: 4),
            Text(
              'Downloaded',
              style: TextStyle(
                color: Colors.green,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (activeDownload != null) {
      final status = activeDownload.status;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Default_Theme.accentColor2.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Default_Theme.accentColor2,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${(status.progress * 100).toInt()}%',
              style: const TextStyle(
                color: Default_Theme.accentColor2,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBottomBar(BuildContext context) {
    final count = _selectedTrackIds.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Default_Theme.themeColor.withValues(alpha: 0.6),
        border: const Border(top: BorderSide(color: Colors.white10)),
      ),
      child: ElevatedButton(
        onPressed: count == 0 ? null : () => _startDownload(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Default_Theme.accentColor2,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white12,
          disabledForegroundColor: Colors.white38,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Text(
          count == 0 ? 'Select Songs to Download' : 'Download Selected ($count)',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _startDownload(BuildContext context) async {
    final selected =
        widget.tracks.where((t) => _selectedTrackIds.contains(t.id)).toList();
    if (selected.isEmpty) return;

    final downloader = context.read<DownloaderCubit>();
    final organizer = context.read<OfflineOrganizerCubit>();

    // 1. Immediately register the collection for offline tracking
    await organizer.registerCollection(
      id: widget.collectionId,
      title: widget.title,
      type: widget.type,
      coverUrl: widget.coverUrl,
      trackIds: selected.map((t) => t.id).toList(),
    );

    int queuedCount = 0;
    // 2. Queue non-downloaded tracks via DownloaderCubit
    for (final track in selected) {
      if (!downloader.isDownloaded(track.id)) {
        await downloader.downloadSong(track, showSnackbar: false);
        queuedCount++;
      }
    }

    if (context.mounted) {
      Navigator.pop(context);
      if (queuedCount > 0) {
        SnackbarService.showMessage(
          'Added $queuedCount song${queuedCount == 1 ? '' : 's'} to download queue',
        );
      } else {
        SnackbarService.showMessage(
          'All selected songs are already downloaded.',
        );
      }
    }
  }
}

