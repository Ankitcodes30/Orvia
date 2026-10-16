import 'package:Orvia/blocs/media_player/orvia_player_cubit.dart';
import 'package:Orvia/core/di/service_locator.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/screens/widgets/more_bottom_sheet.dart';
import 'package:Orvia/screens/widgets/sign_board_widget.dart';
import 'package:Orvia/screens/widgets/song_tile.dart';
import 'package:Orvia/src/rust/api/plugin/commands.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

class InstrumentalSection extends StatefulWidget {
  final String pluginId;

  const InstrumentalSection({super.key, required this.pluginId});

  @override
  State<InstrumentalSection> createState() => _InstrumentalSectionState();
}

class _InstrumentalSectionState extends State<InstrumentalSection> {
  String _selectedFilter = 'Sitar';
  bool _isLoading = false;
  String? _error;

  static const List<String> _filters = [
    'Sitar',
    'Flute',
    'Tabla',
    'Violin',
    'Santoor',
    'Piano',
    'Saxophone',
    'Guitar',
    'Indian Classical Instrumental',
    'Instrumental Film Music',
    'Relaxing Instrumental',
  ];

  static const Map<String, String> _filterQueries = {
    'Sitar': 'Sitar Instrumental Indian',
    'Flute': 'Bansuri Flute Instrumental',
    'Tabla': 'Tabla Solo Classical',
    'Violin': 'Violin Instrumental Carnatic Hindustani',
    'Santoor': 'Santoor Instrumental Classical',
    'Piano': 'Piano Instrumental Bollywood Melodies',
    'Saxophone': 'Saxophone Instrumental Melodies',
    'Guitar': 'Acoustic Guitar Instrumental Bollywood',
    'Indian Classical Instrumental': 'Indian Classical Instrumental Ragas',
    'Instrumental Film Music': 'Bollywood Instrumental Film Hits',
    'Relaxing Instrumental': 'Relaxing Indian Instrumental Meditative',
  };

  // In-memory cache for instrument category tracks to avoid re-fetching
  final Map<String, List<Track>> _tracksCache = {};
  int _activeRequestId = 0;

  @override
  void initState() {
    super.initState();
    _fetchInstrumentTracks(_selectedFilter);
  }

  Future<void> _fetchInstrumentTracks(String filter) async {
    final requestId = ++_activeRequestId;

    if (_tracksCache.containsKey(filter) && _tracksCache[filter]!.isNotEmpty) {
      setState(() {
        _selectedFilter = filter;
        _isLoading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _selectedFilter = filter;
      _isLoading = true;
      _error = null;
    });

    final query = _filterQueries[filter] ?? '$filter Instrumental';

    try {
      final response = await ServiceLocator.pluginService.execute(
        pluginId: widget.pluginId,
        request: PluginRequest.contentResolver(
          ContentResolverCommand.search(
            query: query,
            filter: ContentSearchFilter.track,
          ),
        ),
      );

      if (!mounted) return;

      response.when(
        search: (results) {
          final tracks = <Track>[];
          for (final item in results.items) {
            item.when(
              track: (t) => tracks.add(t),
              album: (_) {},
              artist: (_) {},
              playlist: (_) {},
            );
          }
          final seenIds = <String>{};
          final deduplicated = <Track>[];
          for (final t in tracks) {
            if (t.id.isNotEmpty && seenIds.add(t.id)) {
              deduplicated.add(t);
            }
          }

          _tracksCache[filter] = deduplicated;

          if (requestId == _activeRequestId) {
            setState(() {
              _isLoading = false;
            });
          }
        },
        trackDetails: (_) {},
        albumDetails: (_) {},
        artistDetails: (_) {},
        playlistDetails: (_) {},
        streams: (_) {},
        moreTracks: (_) {},
        moreAlbums: (_) {},
        homeSections: (_) {},
        loadMoreItems: (_) {},
        charts: (_) {},
        chartDetails: (_) {},
        segments: (_) {},
        lyricsResult: (_) {},
        lyricsSearchResults: (_) {},
        lyricsById: (_, __) {},
        suggestions: (_) {},
        canHandle: (_) {},
        collectionInfo: (_) {},
        importTracks: (_) {},
        ack: () {},
      );
    } catch (e) {
      if (mounted && requestId == _activeRequestId) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load $filter melodies';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTracks = _tracksCache[_selectedFilter] ?? const [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(MingCute.music_2_line,
                  size: 20, color: Default_Theme.accentColor2),
              const SizedBox(width: 8),
              Text(
                'Instrumental Discovery',
                style: Default_Theme.primaryTextStyle.merge(
                  const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Default_Theme.primaryColor1,
                  ),
                ),
              ),
              const Spacer(),
              if (currentTracks.isNotEmpty)
                Text(
                  '${currentTracks.length} Melodies',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Explore timeless classical and contemporary Indian instrumental music by instrument.',
            style: TextStyle(
              fontSize: 13,
              color: Default_Theme.primaryColor1.withValues(alpha: 0.65),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (val) {
                      _fetchInstrumentTracks(filter);
                    },
                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                    selectedColor:
                        Default_Theme.accentColor2.withValues(alpha: 0.2),
                    checkmarkColor: Default_Theme.accentColor2,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? Default_Theme.accentColor2
                          : Default_Theme.primaryColor1.withValues(alpha: 0.7),
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? Default_Theme.accentColor2
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child:
                    CircularProgressIndicator(color: Default_Theme.accentColor2),
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () => _fetchInstrumentTracks(_selectedFilter),
                      icon: const Icon(MingCute.refresh_3_line, size: 16),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Default_Theme.accentColor2,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (currentTracks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SignBoardWidget(
                  message: 'No instrumental tracks found for $_selectedFilter',
                  icon: MingCute.music_2_line,
                ),
              ),
            )
          else ...[
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    context.read<OrviaPlayerCubit>().orviaPlayer.loadPlaylist(
                          Playlist(
                            tracks: currentTracks,
                            title: '$_selectedFilter Instrumental',
                          ),
                          doPlay: true,
                          idx: 0,
                        );
                  },
                  icon: const Icon(MingCute.play_fill, size: 16),
                  label: const Text('Play All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Default_Theme.accentColor2,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    context.read<OrviaPlayerCubit>().orviaPlayer.loadPlaylist(
                          Playlist(
                            tracks: currentTracks,
                            title: '$_selectedFilter Instrumental',
                          ),
                          doPlay: true,
                          shuffling: true,
                        );
                  },
                  icon: const Icon(MingCute.shuffle_line, size: 16),
                  label: const Text('Shuffle'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: currentTracks.length > 8 ? 8 : currentTracks.length,
              itemBuilder: (context, index) {
                final track = currentTracks[index];
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
                            tracks: currentTracks,
                            title: '$_selectedFilter Instrumental',
                          ),
                          doPlay: true,
                          idx: index,
                        );
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
