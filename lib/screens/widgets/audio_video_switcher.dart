import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:Orvia/blocs/media_player/orvia_player_cubit.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/src/rust/api/plugin/models.dart';
import 'package:Orvia/utils/load_image.dart';

class AudioVideoSurface extends StatefulWidget {
  final Track track;
  final Widget audioCoverWidget;

  const AudioVideoSurface({
    super.key,
    required this.track,
    required this.audioCoverWidget,
  });

  @override
  State<AudioVideoSurface> createState() => _AudioVideoSurfaceState();
}

class _AudioVideoSurfaceState extends State<AudioVideoSurface> {
  bool _isVideoMode = false;
  VideoController? _videoController;
  Player? _player;
  bool _isPlaying = true;
  bool _isMuted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initVideoController();
  }

  void _initVideoController() {
    try {
      final activePlayer =
          context.read<OrviaPlayerCubit>().orviaPlayer.engine.activePlayer;
      if (_player != activePlayer) {
        _player = activePlayer;
        _videoController = VideoController(activePlayer);
        _isPlaying = activePlayer.state.playing;
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant AudioVideoSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id) {
      _initVideoController();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // ── Main Display: Cover Artwork OR In-App Video Surface ──
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: _isVideoMode ? _buildInAppVideoPlayer() : widget.audioCoverWidget,
        ),

        // ── Top Audio / Video Toggle Pill ──
        Positioned(
          top: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeTab(
                  icon: MingCute.music_2_fill,
                  label: 'Audio',
                  isSelected: !_isVideoMode,
                  onTap: () => setState(() => _isVideoMode = false),
                ),
                const SizedBox(width: 4),
                _buildModeTab(
                  icon: MingCute.movie_fill,
                  label: 'Video',
                  isSelected: _isVideoMode,
                  onTap: () {
                    _initVideoController();
                    setState(() => _isVideoMode = true);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeTab({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Default_Theme.accentColor2 : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInAppVideoPlayer() {
    return AspectRatio(
      aspectRatio: 1.0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          key: const ValueKey('in_app_video_surface'),
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Native in-app video renderer via media_kit_video
              if (_videoController != null)
                Video(
                  controller: _videoController!,
                  fit: BoxFit.cover,
                  controls: NoVideoControls,
                )
              else
                LoadImageCached(
                  imageUrl: widget.track.thumbnail.url,
                  fit: BoxFit.cover,
                ),

              // 2. Subtle gradient overlay for in-app controls
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.65),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),

              // 3. Center In-App Play/Pause Toggle
              Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () {
                    final player = _player;
                    if (player != null) {
                      player.playOrPause();
                      setState(() {
                        _isPlaying = !_isPlaying;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      _isPlaying ? MingCute.pause_fill : MingCute.play_fill,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),

              // 4. Bottom Video Control Bar (In-App)
              Positioned(
                bottom: 12,
                left: 14,
                right: 14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Mute / Unmute
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        final player = _player;
                        if (player != null) {
                          final currentVol = player.state.volume;
                          if (currentVol > 0) {
                            player.setVolume(0);
                            setState(() => _isMuted = true);
                          } else {
                            player.setVolume(100);
                            setState(() => _isMuted = false);
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isMuted
                              ? MingCute.volume_mute_fill
                              : MingCute.volume_fill,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),

                    // Badge: In-App Video
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Default_Theme.accentColor2.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(MingCute.movie_line,
                              size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'In-App Video',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
