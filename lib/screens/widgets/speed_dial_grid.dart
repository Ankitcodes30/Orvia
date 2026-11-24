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
import 'package:Orvia/services/catalogue/creators_choice_service.dart';
import 'package:Orvia/utils/load_image.dart';

class SpeedDialSection extends StatefulWidget {
  final List<Track>? tracks;
  final String? categoryTitle;

  const SpeedDialSection({
    super.key,
    this.tracks,
    this.categoryTitle,
  });

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
      final surpriseTrack =
          candidateTracks[math.Random().nextInt(candidateTracks.length)];
      final player = context.read<OrviaPlayerCubit>().orviaPlayer;

      player.loadPlaylist(
        Playlist(tracks: candidateTracks, title: 'Speed Dial Surprise'),
        idx: candidateTracks.indexOf(surpriseTrack),
        doPlay: true,
      );

      SnackbarService.showMessage(
          '🎲 Rolled $_diceFace! Playing "${surpriseTrack.title}"');
    });
  }

  @override
  Widget build(BuildContext context) {
    final recentlyTracks = context.watch<RecentlyCubit>().state.tracks;
    final List<Track> poolTracks;

    if (widget.tracks != null && widget.tracks!.isNotEmpty) {
      poolTracks = widget.tracks!;
    } else if (recentlyTracks.isNotEmpty) {
      poolTracks = recentlyTracks;
    } else {
      poolTracks = CreatorsChoiceService.getVerifiedTracks();
    }

    // Always ensure 8 candidate tracks for the grid (pad from curated if needed)
    final displayTracks = <Track>[...poolTracks];
    if (displayTracks.length < 8) {
      final fallback = CreatorsChoiceService.getVerifiedTracks();
      for (final t in fallback) {
        if (!displayTracks.any((d) => d.id == t.id)) {
          displayTracks.add(t);
        }
        if (displayTracks.length >= 8) break;
      }
    }
    final activeTracks = displayTracks.take(8).toList();

    final title = widget.categoryTitle != null
        ? 'Speed dial • ${widget.categoryTitle}'
        : 'Speed dial';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section Title & Circular Arrow Action ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Default_Theme.primaryColor1,
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  if (activeTracks.isNotEmpty) {
                    _rollDiceAndPlaySurprise(activeTracks);
                  }
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Default_Theme.accentColor2.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      MingCute.right_line,
                      color: Default_Theme.accentColor2,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Compact 3x3 Grid (Metrolist Style: Exact Squares) ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.0, // Exact compact square
            ),
            itemCount: 9, // 8 music boxes + 1 dice box
            itemBuilder: (context, index) {
              if (index == 8) {
                // Slot 9: Interactive Animated Dice Square
                return _buildDiceSlot(activeTracks);
              }

              if (index < activeTracks.length) {
                final track = activeTracks[index];
                return _buildSquareTrackTile(track, activeTracks, index);
              }

              return _buildEmptySlot();
            },
          ),
        ),

        // ── Metrolist Pagination Dots Indicator ──
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Default_Theme.accentColor2,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: Default_Theme.primaryColor1.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: Default_Theme.primaryColor1.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSquareTrackTile(Track track, List<Track> allTracks, int index) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Full-bleed artwork
            LoadImageCached(
              imageUrl: track.thumbnail.url,
              fit: BoxFit.cover,
            ),
            // Gradient scrim for text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.4, 0.65, 1.0],
                ),
              ),
            ),
            // Title overlay inside the card at bottom
            Positioned(
              left: 7,
              right: 7,
              bottom: 6,
              child: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiceSlot(List<Track> candidateTracks) {
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
        borderRadius: BorderRadius.circular(14),
        onTap: () => _rollDiceAndPlaySurprise(candidateTracks),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2C3246).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
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
    const dotColor = Colors.white;

    switch (face) {
      case 1:
        return _buildDot(12, dotColor);
      case 2:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [_buildDot(9, dotColor), _buildDot(9, dotColor)],
        );
      case 3:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDot(8, dotColor),
            _buildDot(8, dotColor),
            _buildDot(8, dotColor),
          ],
        );
      case 4:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDot(7, dotColor),
                const SizedBox(width: 14),
                _buildDot(7, dotColor)
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDot(7, dotColor),
                const SizedBox(width: 14),
                _buildDot(7, dotColor)
              ],
            ),
          ],
        );
      case 6:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDot(7, dotColor),
                const SizedBox(width: 10),
                _buildDot(7, dotColor),
                const SizedBox(width: 10),
                _buildDot(7, dotColor)
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDot(7, dotColor),
                const SizedBox(width: 10),
                _buildDot(7, dotColor),
                const SizedBox(width: 10),
                _buildDot(7, dotColor)
              ],
            ),
          ],
        );
      case 5:
      default:
        // Classic Metrolist 5-dot dice arrangement
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDot(7, dotColor),
                const SizedBox(width: 20),
                _buildDot(7, dotColor),
              ],
            ),
            const SizedBox(height: 6),
            _buildDot(7, dotColor),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDot(7, dotColor),
                const SizedBox(width: 20),
                _buildDot(7, dotColor),
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
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.3),
            blurRadius: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySlot() {
    return Container(
      decoration: BoxDecoration(
        color: Default_Theme.primaryColor1.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Icon(
          MingCute.music_2_line,
          color: Default_Theme.primaryColor1.withValues(alpha: 0.2),
          size: 22,
        ),
      ),
    );
  }
}
