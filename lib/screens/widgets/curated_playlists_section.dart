import 'package:Orvia/blocs/media_player/orvia_player_cubit.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/screens/widgets/more_bottom_sheet.dart';
import 'package:Orvia/screens/widgets/song_tile.dart';
import 'package:Orvia/services/catalogue/curated_playlists_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

enum CuratedTab {
  bollywood,
  marathi,
  instrumental,
}

typedef CuratedTrackTileBuilder = Widget Function(
  BuildContext context,
  Track track,
  int index,
  VoidCallback onTap,
);

class CuratedPlaylistsSection extends StatefulWidget {
  final String pluginId;
  final CuratedTrackTileBuilder? tileBuilder;

  const CuratedPlaylistsSection({
    super.key,
    required this.pluginId,
    this.tileBuilder,
  });

  @override
  State<CuratedPlaylistsSection> createState() =>
      _CuratedPlaylistsSectionState();
}

class _CuratedPlaylistsSectionState extends State<CuratedPlaylistsSection> {
  CuratedTab _selectedTab = CuratedTab.bollywood;
  bool _isExpanded = false;

  static const int _kInitialVisibleCount = 4;

  List<Track> get _currentTracks {
    switch (_selectedTab) {
      case CuratedTab.bollywood:
        return CuratedPlaylistsService.getBollywoodTracks();
      case CuratedTab.marathi:
        return CuratedPlaylistsService.getMarathiTracks();
      case CuratedTab.instrumental:
        return CuratedPlaylistsService.getInstrumentalTracks();
    }
  }

  String get _currentTitle {
    switch (_selectedTab) {
      case CuratedTab.bollywood:
        return 'Bollywood Dance Hits';
      case CuratedTab.marathi:
        return 'Marathi Superhits';
      case CuratedTab.instrumental:
        return 'Instrumental Classics';
    }
  }

  String get _currentDescription {
    switch (_selectedTab) {
      case CuratedTab.bollywood:
        return '20 iconic Bollywood dance anthems & chartbusters verified from the jukebox.';
      case CuratedTab.marathi:
        return 'High energy Marathi party anthems, folk rhythms & melodic classics.';
      case CuratedTab.instrumental:
        return 'Timeless saxophone, flute, sitar, and acoustic instrumental covers.';
    }
  }

  LinearGradient get _currentGradient {
    switch (_selectedTab) {
      case CuratedTab.bollywood:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFC2185B).withValues(alpha: 0.28),
            const Color(0xFF7B1FA2).withValues(alpha: 0.18),
            Default_Theme.themeColor,
          ],
        );
      case CuratedTab.marathi:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF6F00).withValues(alpha: 0.26),
            const Color(0xFFD84315).withValues(alpha: 0.18),
            Default_Theme.themeColor,
          ],
        );
      case CuratedTab.instrumental:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00897B).withValues(alpha: 0.26),
            const Color(0xFF006064).withValues(alpha: 0.18),
            Default_Theme.themeColor,
          ],
        );
    }
  }

  Color get _currentAccent {
    switch (_selectedTab) {
      case CuratedTab.bollywood:
        return const Color(0xFFFF4081);
      case CuratedTab.marathi:
        return const Color(0xFFFF9100);
      case CuratedTab.instrumental:
        return const Color(0xFF26A69A);
    }
  }

  void _showAllBottomSheet(BuildContext context) {
    final tracks = _currentTracks;
    final title = _currentTitle;
    final accent = _currentAccent;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Container(
          height: MediaQuery.of(modalContext).size.height * 0.78,
          decoration: BoxDecoration(
            color: Default_Theme.themeColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: accent.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Icon(MingCute.disc_fill, color: accent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Default_Theme.primaryColor1,
                            ),
                          ),
                          Text(
                            '${tracks.length} verified tracks',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(MingCute.close_line,
                          color: Colors.white70),
                      onPressed: () => Navigator.pop(modalContext),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  itemCount: tracks.length,
                  itemBuilder: (ctx, index) {
                    final track = tracks[index];
                    if (widget.tileBuilder != null) {
                      return widget.tileBuilder!(ctx, track, index, () {});
                    }
                    return SongCardWidget(
                      song: track,
                      onOptionsTap: () => showMoreBottomSheet(
                        ctx,
                        track,
                        showDelete: false,
                        showSinglePlay: true,
                      ),
                      onTap: () {
                        context.read<OrviaPlayerCubit>().orviaPlayer.loadPlaylist(
                              Playlist(
                                tracks: tracks,
                                title: title,
                              ),
                              doPlay: true,
                              idx: index,
                              isFromPlaylist: false,
                            );
                        Navigator.pop(modalContext);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tracks = _currentTracks;
    final accent = _currentAccent;
    final visibleCount = _isExpanded
        ? tracks.length
        : (tracks.length > _kInitialVisibleCount
            ? _kInitialVisibleCount
            : tracks.length);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: _currentGradient,
        border: Border.all(
          color: accent.withValues(alpha: 0.28),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.2),
                ),
                child: Icon(
                  MingCute.music_2_fill,
                  size: 18,
                  color: accent,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Curated Playlists',
                style: Default_Theme.primaryTextStyle.merge(
                  const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Default_Theme.primaryColor1,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${tracks.length} Songs',
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _currentDescription,
            style: TextStyle(
              fontSize: 13,
              color: Default_Theme.primaryColor1.withValues(alpha: 0.65),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          // Tab selection chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildTabChip(
                  tab: CuratedTab.bollywood,
                  label: 'Bollywood Hits (${CuratedPlaylistsService.getBollywoodTracks().length})',
                  icon: MingCute.disc_line,
                ),
                const SizedBox(width: 8),
                _buildTabChip(
                  tab: CuratedTab.marathi,
                  label: 'Marathi Hits (${CuratedPlaylistsService.getMarathiTracks().length})',
                  icon: MingCute.fire_line,
                ),
                const SizedBox(width: 8),
                _buildTabChip(
                  tab: CuratedTab.instrumental,
                  label: 'Instrumental (${CuratedPlaylistsService.getInstrumentalTracks().length})',
                  icon: MingCute.headphone_line,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Action Buttons: Play All & Shuffle
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: tracks.isEmpty
                    ? null
                    : () {
                        context
                            .read<OrviaPlayerCubit>()
                            .orviaPlayer
                            .loadPlaylist(
                              Playlist(
                                tracks: tracks,
                                title: _currentTitle,
                              ),
                              doPlay: true,
                              idx: 0,
                              isFromPlaylist: false,
                            );
                      },
                icon: const Icon(MingCute.play_fill, size: 16),
                label: const Text('Play All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black87,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: tracks.isEmpty
                    ? null
                    : () {
                        context
                            .read<OrviaPlayerCubit>()
                            .orviaPlayer
                            .loadPlaylist(
                              Playlist(
                                tracks: tracks,
                                title: _currentTitle,
                              ),
                              doPlay: true,
                              shuffling: true,
                              isFromPlaylist: false,
                            );
                      },
                icon: const Icon(MingCute.shuffle_line, size: 16),
                label: const Text('Shuffle'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Compact list rendering
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleCount,
            itemBuilder: (context, index) {
              final track = tracks[index];
              if (widget.tileBuilder != null) {
                return widget.tileBuilder!(context, track, index, () {});
              }
              return SongCardWidget(
                song: track,
                onOptionsTap: () => showMoreBottomSheet(
                  context,
                  track,
                  showDelete: false,
                  showSinglePlay: true,
                ),
                onTap: () {
                  context.read<OrviaPlayerCubit>().orviaPlayer.loadPlaylist(
                        Playlist(
                          tracks: tracks,
                          title: _currentTitle,
                        ),
                        doPlay: true,
                        idx: index,
                        isFromPlaylist: false,
                      );
                },
              );
            },
          ),
          // See all / Show more toggle
          if (tracks.length > _kInitialVisibleCount) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  icon: Icon(
                    _isExpanded ? MingCute.up_line : MingCute.down_line,
                    size: 16,
                    color: accent,
                  ),
                  label: Text(
                    _isExpanded
                        ? 'Show less'
                        : 'Show more (${tracks.length - _kInitialVisibleCount} more)',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showAllBottomSheet(context),
                  icon: const Icon(
                    MingCute.list_check_line,
                    size: 16,
                    color: Colors.white70,
                  ),
                  label: const Text(
                    'See all',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabChip({
    required CuratedTab tab,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedTab == tab;
    final accent = _currentAccent;

    return FilterChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? accent : Colors.white60,
      ),
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (!isSelected) {
          setState(() {
            _selectedTab = tab;
            _isExpanded = false; // Reset expansion when switching tabs
          });
        }
      },
      backgroundColor: Colors.white.withValues(alpha: 0.04),
      selectedColor: accent.withValues(alpha: 0.22),
      checkmarkColor: accent,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected
            ? accent
            : Default_Theme.primaryColor1.withValues(alpha: 0.75),
      ),
      side: BorderSide(
        color: isSelected ? accent : Colors.white.withValues(alpha: 0.1),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
