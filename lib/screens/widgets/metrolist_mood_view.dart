import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'package:Orvia/blocs/media_player/orvia_player_cubit.dart';
import 'package:Orvia/core/di/service_locator.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/screens/widgets/more_bottom_sheet.dart';
import 'package:Orvia/screens/widgets/snackbar.dart';
import 'package:Orvia/services/catalogue/category_tracks_service.dart';
import 'package:Orvia/src/rust/api/plugin/commands.dart';
import 'package:Orvia/utils/load_image.dart';

class MetrolistMoodView extends StatelessWidget {
  final String category;
  final String pluginId;

  const MetrolistMoodView({
    super.key,
    required this.category,
    required this.pluginId,
  });

  @override
  Widget build(BuildContext context) {
    final sections = CategoryTracksService.getMoodSections(category);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        for (final section in sections) ...[
          if (section is MoodCardSection)
            _MoodCardSectionWidget(
              section: section,
              pluginId: pluginId,
            )
          else if (section is MoodSongGridSection)
            _MoodSongGridSectionWidget(
              section: section,
            ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _MoodCardSectionWidget extends StatefulWidget {
  final MoodCardSection section;
  final String pluginId;

  const _MoodCardSectionWidget({
    required this.section,
    required this.pluginId,
  });

  @override
  State<_MoodCardSectionWidget> createState() => _MoodCardSectionWidgetState();
}

class _MoodCardSectionWidgetState extends State<_MoodCardSectionWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollForward() {
    if (_scrollController.hasClients) {
      final target = _scrollController.offset + 300;
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.animateTo(
        target > max ? max : target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _onCardTap(BuildContext context, MoodCardItem item) async {
    final player = context.read<OrviaPlayerCubit>().orviaPlayer;

    // 1. Immediate playback of verified fallback tracks to prevent any wait
    if (item.fallbackTracks.isNotEmpty) {
      player.loadPlaylist(
        Playlist(tracks: item.fallbackTracks, title: item.title),
        idx: 0,
        doPlay: true,
      );
      SnackbarService.showMessage('Playing ${item.title}');
    }

    // 2. Query live tracks in background if plugin available
    if (widget.pluginId.isNotEmpty) {
      try {
        final response = await ServiceLocator.pluginService.execute(
          pluginId: widget.pluginId,
          request: PluginRequest.contentResolver(
            ContentResolverCommand.search(
              query: item.searchQuery,
              filter: ContentSearchFilter.track,
            ),
          ),
        ).timeout(const Duration(seconds: 5));

        final liveTracks = <Track>[];
        response.whenOrNull(
          search: (results) {
            for (final res in results.items) {
              res.whenOrNull(track: (t) => liveTracks.add(t));
            }
          },
        );

        if (liveTracks.isNotEmpty && context.mounted) {
          player.loadPlaylist(
            Playlist(tracks: liveTracks, title: item.title),
            idx: 0,
            doPlay: true,
          );
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tag + Title + Scroll Right Action
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.section.tag != null) ...[
                Text(
                  widget.section.tag!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Default_Theme.primaryColor1.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.section.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Default_Theme.primaryColor1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _scrollForward,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Default_Theme.primaryColor1.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          MingCute.right_line,
                          color: Default_Theme.primaryColor1,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Horizontal scrolling card row
        SizedBox(
          height: 200,
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: widget.section.items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = widget.section.items[index];
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _onCardTap(context, item),
                child: SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Square Card Artwork
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 140,
                          height: 140,
                          child: LoadImageCached(
                            imageUrl: item.imageUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Title
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Default_Theme.primaryColor1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Subtitle
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Default_Theme.primaryColor1.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MoodSongGridSectionWidget extends StatefulWidget {
  final MoodSongGridSection section;

  const _MoodSongGridSectionWidget({
    required this.section,
  });

  @override
  State<_MoodSongGridSectionWidget> createState() =>
      _MoodSongGridSectionWidgetState();
}

class _MoodSongGridSectionWidgetState
    extends State<_MoodSongGridSectionWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollForward() {
    if (_scrollController.hasClients) {
      final target = _scrollController.offset + 320;
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.animateTo(
        target > max ? max : target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracks = widget.section.tracks;
    // Group tracks into columns of 3 rows
    final List<List<Track>> columns = [];
    for (int i = 0; i < tracks.length; i += 3) {
      columns.add(tracks.sublist(
        i,
        i + 3 > tracks.length ? tracks.length : i + 3,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title + Scroll Right Action
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.section.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Default_Theme.primaryColor1,
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _scrollForward,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Default_Theme.primaryColor1.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      MingCute.right_line,
                      color: Default_Theme.primaryColor1,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 3-Row Song Tiles horizontally scrolling grid
        SizedBox(
          height: 196,
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: columns.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, colIndex) {
              final colTracks = columns[colIndex];
              return SizedBox(
                width: 310,
                child: Column(
                  children: [
                    for (int r = 0; r < colTracks.length; r++) ...[
                      _buildSongTile(
                        context,
                        colTracks[r],
                        tracks,
                        colIndex * 3 + r,
                      ),
                      if (r < colTracks.length - 1)
                        const SizedBox(height: 8),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSongTile(
    BuildContext context,
    Track track,
    List<Track> allTracks,
    int index,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        context.read<OrviaPlayerCubit>().orviaPlayer.loadPlaylist(
          Playlist(tracks: allTracks, title: widget.section.title),
          idx: index,
          doPlay: true,
        );
      },
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: LoadImageCached(
                  imageUrl: track.thumbnail.url,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Default_Theme.primaryColor1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.artists.isNotEmpty
                        ? track.artists.first.name
                        : track.album?.title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Default_Theme.primaryColor1.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            // 3-dots Menu
            IconButton(
              icon: Icon(
                MingCute.more_2_line,
                size: 18,
                color: Default_Theme.primaryColor1.withValues(alpha: 0.6),
              ),
              onPressed: () {
                showMoreBottomSheet(
                  context,
                  track,
                  showSinglePlay: true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
