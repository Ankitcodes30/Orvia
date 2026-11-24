import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:share_plus/share_plus.dart';

import 'package:Orvia/blocs/library/cubit/library_items_cubit.dart';
import 'package:Orvia/blocs/media_player/orvia_player_cubit.dart';
import 'package:Orvia/blocs/mini_player/mini_player_cubit.dart';
import 'package:Orvia/blocs/player_overlay/player_overlay_cubit.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/screens/screen/player_views/fullscreen_lyrics_view.dart';
import 'package:Orvia/screens/widgets/more_bottom_sheet.dart';
import 'package:Orvia/screens/widgets/snackbar.dart';
import 'package:Orvia/services/player/player_engine.dart';
import 'package:Orvia/utils/load_image.dart';

class MiniPlayerWidget extends StatelessWidget {
  const MiniPlayerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MiniPlayerCubit, MiniPlayerState>(
      builder: (context, state) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: state.isVisible && state.track != null
              ? MiniPlayerCard(
                  key: const ValueKey('metrolist_mini_player'),
                  state: state,
                )
              : const SizedBox.shrink(key: ValueKey('empty_player')),
        );
      },
    );
  }
}

class MiniPlayerCard extends StatefulWidget {
  final MiniPlayerState state;
  const MiniPlayerCard({super.key, required this.state});

  @override
  State<MiniPlayerCard> createState() => _MiniPlayerCardState();
}

class _MiniPlayerCardState extends State<MiniPlayerCard> {
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _checkLikedState();
  }

  @override
  void didUpdateWidget(covariant MiniPlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.track?.id != widget.state.track?.id) {
      _checkLikedState();
    }
  }

  Future<void> _checkLikedState() async {
    final track = widget.state.track;
    if (track == null) return;
    try {
      final liked = await context.read<LibraryItemsCubit>().isTrackLiked(track);
      if (mounted) setState(() => _isLiked = liked);
    } catch (_) {
      if (mounted) setState(() => _isLiked = false);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _showVolumeDialog(BuildContext context) {
    final player = context.read<OrviaPlayerCubit>().orviaPlayer;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Default_Theme.themeColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Volume',
            style: TextStyle(color: Default_Theme.primaryColor1, fontSize: 16),
          ),
          content: StreamBuilder<double>(
            stream: player.engine.volumeStream,
            initialData: player.engine.volume,
            builder: (context, snapshot) {
              final vol = snapshot.data ?? 1.0;
              return Row(
                children: [
                  Icon(
                    vol == 0 ? MingCute.volume_mute_line : MingCute.volume_line,
                    color: Default_Theme.primaryColor1,
                  ),
                  Expanded(
                    child: Slider(
                      value: vol.clamp(0.0, 1.0),
                      activeColor: Default_Theme.accentColor2,
                      inactiveColor: Default_Theme.primaryColor1.withValues(alpha: 0.2),
                      onChanged: (newVol) {
                        player.engine.setVolume(newVol);
                      },
                    ),
                  ),
                  Text(
                    '${(vol * 100).toInt()}%',
                    style: const TextStyle(
                      color: Default_Theme.primaryColor1,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.state.track!;
    final isDesktop = ResponsiveBreakpoints.of(context).isDesktop;
    final playerCubit = context.read<OrviaPlayerCubit>();
    final player = playerCubit.orviaPlayer;
    final isPlaying = widget.state.isPlaying;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1919).withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 1. Metrolist Top Interactive Seek Line ──
          StreamBuilder<ProgressBarStreams>(
            stream: playerCubit.progressStreams,
            builder: (context, snapshot) {
              final data = snapshot.data;
              final position = data?.position ?? Duration.zero;
              final duration = data?.duration ?? Duration.zero;
              final totalMs = duration.inMilliseconds;
              final currentMs = position.inMilliseconds.clamp(0, totalMs > 0 ? totalMs : 0);
              final progressFraction = totalMs > 0 ? (currentMs / totalMs).clamp(0.0, 1.0) : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  children: [
                    // Position label (left)
                    SizedBox(
                      width: 36,
                      child: Text(
                        _formatDuration(position),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Default_Theme.primaryColor1.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Scrubbable Progress Line (middle)
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragUpdate: (details) {
                              if (totalMs <= 0) return;
                              final ratio = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                              final target = Duration(milliseconds: (ratio * totalMs).toInt());
                              player.seek(target);
                            },
                            onTapDown: (details) {
                              if (totalMs <= 0) return;
                              final ratio = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                              final target = Duration(milliseconds: (ratio * totalMs).toInt());
                              player.seek(target);
                            },
                            child: SizedBox(
                              height: 18,
                              child: Center(
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    // Inactive track
                                    Container(
                                      height: 3.5,
                                      width: constraints.maxWidth,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    // Active progress track
                                    Container(
                                      height: 3.5,
                                      width: constraints.maxWidth * progressFraction,
                                      decoration: BoxDecoration(
                                        color: Default_Theme.accentColor2,
                                        borderRadius: BorderRadius.circular(2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Default_Theme.accentColor2.withValues(alpha: 0.4),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Scrubber knob
                                    Positioned(
                                      left: (constraints.maxWidth * progressFraction - 4).clamp(0.0, constraints.maxWidth - 8),
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Duration label (right)
                    SizedBox(
                      width: 36,
                      child: Text(
                        _formatDuration(duration),
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Default_Theme.primaryColor1.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // ── 2. Metrolist Controls Row ──
          Row(
            children: [
              // ── Left: Thumbnail + Title/Artist + Quick Actions ──
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: LoadImageCached(
                    imageUrl: track.thumbnail.url,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
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
              const SizedBox(width: 8),

              // Share Button
              IconButton(
                icon: const Icon(MingCute.share_2_line, size: 19),
                color: Default_Theme.primaryColor1.withValues(alpha: 0.7),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  SharePlus.instance.share(ShareParams(text: track.url ?? track.title));
                },
              ),

              // Heart (Like/Favorite) Button
              IconButton(
                icon: Icon(
                  _isLiked ? MingCute.heart_fill : MingCute.heart_line,
                  size: 20,
                  color: _isLiked
                      ? Default_Theme.accentColor2
                      : Default_Theme.primaryColor1.withValues(alpha: 0.7),
                ),
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  final target = !_isLiked;
                  await context.read<LibraryItemsCubit>().setTrackLiked(track, target);
                  if (mounted) {
                    setState(() => _isLiked = target);
                    SnackbarService.showMessage(
                      target ? 'Added to Favorites' : 'Removed from Favorites',
                    );
                  }
                },
              ),

              // More 3-dots Button
              IconButton(
                icon: const Icon(MingCute.more_2_line, size: 19),
                color: Default_Theme.primaryColor1.withValues(alpha: 0.7),
                onPressed: () {
                  showMoreBottomSheet(context, track, showSinglePlay: true);
                },
              ),

              // ── Center: Previous + Pill Play/Pause + Next ──
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(MingCute.skip_previous_fill, size: 22),
                color: Colors.white,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  player.skipToPrevious();
                },
              ),
              const SizedBox(width: 4),

              // Metrolist Pill Play/Pause Button
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (isPlaying) {
                    player.pause();
                  } else {
                    player.play();
                  }
                },
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Default_Theme.accentColor2,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPlaying ? MingCute.pause_fill : MingCute.play_fill,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isPlaying ? 'Pause' : 'Play',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),

              IconButton(
                icon: const Icon(MingCute.skip_forward_fill, size: 22),
                color: Colors.white,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  player.skipToNext();
                },
              ),

              // ── Right: Desktop Extra Controls (Lyrics, Shuffle, Repeat, Volume, Queue) ──
              if (isDesktop) ...[
                const SizedBox(width: 10),
                // Lyrics Button
                IconButton(
                  icon: const Icon(MingCute.music_2_line, size: 19),
                  color: Default_Theme.primaryColor1.withValues(alpha: 0.7),
                  onPressed: () {
                    Navigator.of(context).push(PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const FullscreenLyricsView(),
                      transitionsBuilder: (_, a, __, c) =>
                          FadeTransition(opacity: a, child: c),
                      transitionDuration: const Duration(milliseconds: 300),
                    ));
                  },
                ),

                // Miniplayer / Full screen viewer Button
                IconButton(
                  icon: const Icon(Icons.smart_display_outlined, size: 20),
                  color: Default_Theme.primaryColor1.withValues(alpha: 0.7),
                  onPressed: () {
                    context.read<PlayerOverlayCubit>().showPlayer();
                  },
                ),

                // Shuffle Button
                StreamBuilder<bool>(
                  stream: player.shuffleMode,
                  builder: (context, snap) {
                    final isShuffle = snap.data ?? false;
                    return IconButton(
                      icon: Icon(
                        isShuffle ? MingCute.shuffle_fill : MingCute.shuffle_line,
                        size: 19,
                        color: isShuffle
                            ? Default_Theme.accentColor2
                            : Default_Theme.primaryColor1.withValues(alpha: 0.7),
                      ),
                      onPressed: () {
                        player.shuffle(!isShuffle);
                      },
                    );
                  },
                ),

                // Repeat Button
                StreamBuilder<LoopMode>(
                  stream: player.loopMode,
                  builder: (context, snap) {
                    final loop = snap.data ?? LoopMode.off;
                    final isOne = loop == LoopMode.one;
                    final isActive = loop != LoopMode.off;
                    return IconButton(
                      icon: Icon(
                        isOne ? MingCute.repeat_one_line : MingCute.repeat_line,
                        size: 19,
                        color: isActive
                            ? Default_Theme.accentColor2
                            : Default_Theme.primaryColor1.withValues(alpha: 0.7),
                      ),
                      onPressed: () {
                        if (loop == LoopMode.off) {
                          player.setLoopMode(LoopMode.all);
                        } else if (loop == LoopMode.all) {
                          player.setLoopMode(LoopMode.one);
                        } else {
                          player.setLoopMode(LoopMode.off);
                        }
                      },
                    );
                  },
                ),

                // Volume Button
                IconButton(
                  icon: const Icon(MingCute.volume_line, size: 19),
                  color: Default_Theme.primaryColor1.withValues(alpha: 0.7),
                  onPressed: () => _showVolumeDialog(context),
                ),

                // Queue Button
                IconButton(
                  icon: const Icon(MingCute.playlist_line, size: 19),
                  color: Default_Theme.primaryColor1.withValues(alpha: 0.7),
                  onPressed: () {
                    context.read<PlayerOverlayCubit>().showPlayer();
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
