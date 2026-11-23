import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'package:Orvia/blocs/explore/cubit/recently_cubit.dart';
import 'package:Orvia/blocs/media_player/orvia_player_cubit.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/screens/widgets/more_bottom_sheet.dart';
import 'package:Orvia/screens/widgets/snackbar.dart';
import 'package:Orvia/utils/load_image.dart';

class SpeedDialSection extends StatefulWidget {
  final List<Track> tracks;

  const SpeedDialSection({super.key, required this.tracks});

  @override
  State<SpeedDialSection> createState() => _SpeedDialSectionState();
}

class _SpeedDialSectionState extends State<SpeedDialSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _diceController;
  late Animation<double> _diceRotation;
  late Animation<double> _diceScale;
  int _diceFace = 5;

  @override
  void initState() {
    super.initState();
    _diceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _diceRotation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _diceController, curve: Curves.easeInOutCubic),
    );
    _diceScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.95), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
    ]).animate(
      CurvedAnimation(parent: _diceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _diceController.dispose();
    super.dispose();
  }

  void _rollDiceAndPlaySurprise(List<Track> candidateTracks) {
    if (_diceController.isAnimating) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _diceFace = math.Random().nextInt(6) + 1;
    });

    _diceController.forward(from: 0.0).then((_) {
      if (candidateTracks.isEmpty) {
        SnackbarService.showMessage('No tracks available to shuffle yet!');
        return;
      }
      final surpriseTrack = candidateTracks[math.Random().nextInt(candidateTracks.length)];
      final player = context.read<OrviaPlayerCubit>().orviaPlayer;

      player.loadPlaylist(
        Playlist(tracks: candidateTracks, title: 'Speed Dial Surprise'),
        idx: candidateTracks.indexOf(surpriseTrack),
        doPlay: true,
      );

      SnackbarService.showMessage('🎲 Rolled $_diceFace! Playing "${surpriseTrack.title}"');
    });
  }

  @override
  Widget build(BuildContext context) {
    // Take up to 8 tracks from the available list
    final displayTracks = widget.tracks.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section Title ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Speed dial',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Default_Theme.primaryColor1,
                ),
              ),
              IconButton(
                icon: const Icon(
                  MingCute.right_line,
                  color: Default_Theme.primaryColor1,
                  size: 20,
                ),
                onPressed: () {
                  if (displayTracks.isNotEmpty) {
                    _rollDiceAndPlaySurprise(displayTracks);
                  }
                },
              ),
            ],
          ),
        ),

        // ── 3x3 Grid Layout ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 16) / 3;
              final itemHeight = itemWidth + 34; // Square image + 2 lines of text

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 10,
                  childAspectRatio: itemWidth / itemHeight,
                ),
                itemCount: 9, // 8 music cards + 1 Dice
                itemBuilder: (context, index) {
                  if (index == 8) {
                    // Slot 9: Interactive Animated Dice
                    return _buildDiceSlot(itemWidth, displayTracks);
                  }

                  if (index < displayTracks.length) {
                    final track = displayTracks[index];
                    return _buildTrackSlot(track, displayTracks, index);
                  }

                  // Placeholder slot if user has fewer than 8 tracks
                  return _buildEmptySlot(itemWidth);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrackSlot(Track track, List<Track> allTracks, int index) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        context.read<OrviaPlayerCubit>().orviaPlayer.loadPlaylist(
          Playlist(tracks: allTracks, title: 'Speed Dial'),
          idx: index,
          doPlay: true,
        );
      },
      onLongPress: () {
        showMoreBottomSheet(
          context,
          track,
          showSinglePlay: true,
          showRemoveFromHistory: true,
          onRemoveFromHistory: () {
            context.read<RecentlyCubit>().removeTrack(track.id);
            SnackbarService.showMessage('Removed from Speed Dial');
          },
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Album artwork
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LoadImageCached(
                    imageUrl: track.thumbnail.url,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.4),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Song title
          Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Default_Theme.primaryColor1,
            ),
          ),
          // Artist
          Text(
            track.artists.isNotEmpty
                ? track.artists.map((a) => a.name).join(', ')
                : 'Unknown Artist',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: Default_Theme.primaryColor1.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiceSlot(double size, List<Track> candidateTracks) {
    return AnimatedBuilder(
      animation: _diceController,
      builder: (context, child) {
        return Transform.scale(
          scale: _diceScale.value,
          child: Transform.rotate(
            angle: _diceRotation.value,
            child: child,
          ),
        );
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _rollDiceAndPlaySurprise(candidateTracks),
        child: Container(
          decoration: BoxDecoration(
            color: Default_Theme.primaryColor1.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Default_Theme.accentColor2.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Center(
            child: _buildDiceFace(_diceFace),
          ),
        ),
      ),
    );
  }

  Widget _buildDiceFace(int face) {
    // 5-dot dice arrangement or dynamic dots based on face
    final dotColor = Default_Theme.primaryColor1.withValues(alpha: 0.85);

    switch (face) {
      case 1:
        return _buildDot(14, dotColor);
      case 2:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [_buildDot(10, dotColor), _buildDot(10, dotColor)],
        );
      case 3:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDot(9, dotColor),
            _buildDot(9, dotColor),
            _buildDot(9, dotColor),
          ],
        );
      case 4:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [_buildDot(8, dotColor), const SizedBox(width: 14), _buildDot(8, dotColor)],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [_buildDot(8, dotColor), const SizedBox(width: 14), _buildDot(8, dotColor)],
            ),
          ],
        );
      case 6:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [_buildDot(8, dotColor), const SizedBox(width: 12), _buildDot(8, dotColor), const SizedBox(width: 12), _buildDot(8, dotColor)],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [_buildDot(8, dotColor), const SizedBox(width: 12), _buildDot(8, dotColor), const SizedBox(width: 12), _buildDot(8, dotColor)],
            ),
          ],
        );
      case 5:
      default:
        // Classic Metrolist 5-dot dice pattern
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDot(8, dotColor),
                const SizedBox(width: 22),
                _buildDot(8, dotColor),
              ],
            ),
            const SizedBox(height: 6),
            _buildDot(8, dotColor),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDot(8, dotColor),
                const SizedBox(width: 22),
                _buildDot(8, dotColor),
              ],
            ),
          ],
        );
    }
  }

  Widget _buildDot(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildEmptySlot(double size) {
    return Container(
      decoration: BoxDecoration(
        color: Default_Theme.primaryColor1.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          MingCute.music_2_line,
          color: Default_Theme.primaryColor1.withValues(alpha: 0.2),
          size: 24,
        ),
      ),
    );
  }
}
