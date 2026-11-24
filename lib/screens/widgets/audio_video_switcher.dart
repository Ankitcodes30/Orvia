import 'package:flutter/material.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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

  void _openMusicVideo() async {
    final query = Uri.encodeComponent('${widget.track.title} ${widget.track.artists.map((a) => a.name).join(" ")} official music video');
    final youtubeUri = Uri.parse('https://www.youtube.com/results?search_query=$query');
    if (await canLaunchUrl(youtubeUri)) {
      await launchUrl(youtubeUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // ── Main Display: Cover Artwork OR Video Surface ──
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: _isVideoMode ? _buildVideoSurface() : widget.audioCoverWidget,
        ),

        // ── Top Mode Pill (Audio / Video) ──
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
                  onTap: () => setState(() => _isVideoMode = true),
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

  Widget _buildVideoSurface() {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        key: const ValueKey('video_surface'),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Default_Theme.accentColor2.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Darkened background thumbnail
            Opacity(
              opacity: 0.45,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LoadImageCached(
                  imageUrl: widget.track.thumbnail.url,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Video overlay controls
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Default_Theme.accentColor2,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Default_Theme.accentColor2.withValues(alpha: 0.5),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(
                        MingCute.play_fill,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: _openMusicVideo,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Music Video Mode',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Tap to watch official music video with lyrics sync',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
