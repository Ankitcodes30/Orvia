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

class BhaktiCategory {
  final String name;
  final String query;
  final String tag;

  const BhaktiCategory({
    required this.name,
    required this.query,
    required this.tag,
  });
}

const List<BhaktiCategory> kBhaktiCategories = [
  BhaktiCategory(
    name: 'Radha–Krishna',
    query: 'Radha Krishna Bhajans Kirtan',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Shiv Ji',
    query: 'Shiv Ji Bhajans Mahadev Aarti Shiv Tandav',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Hanuman Ji',
    query: 'Hanuman Chalisa Bajrang Baan Sundarkand',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Ram Ji',
    query: 'Shree Ram Bhajans Ram Siya Ram Aarti',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Khatu Shyam Ji',
    query: 'Khatu Shyam Ji Bhajans Kirtan',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Ganesh Ji',
    query: 'Ganesh Aarti Ganpati Bhajans Stuti',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Durga Maa / Mata Rani',
    query: 'Durga Mata Aarti Mata Rani Bhajans Bhenten',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Maa Lakshmi',
    query: 'Maa Lakshmi Aarti Mahalakshmi Ashtakam',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Maa Mahakali',
    query: 'Mahakali Stotram Maa Kali Aarti',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Saraswati Ji',
    query: 'Saraswati Vandana Stotram Aarti',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Vitthal–Rukmini',
    query: 'Vitthal Rukmini Abhang Pandharpur Bhajans',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Vishnu Ji',
    query: 'Vishnu Sahasranamam Narayan Aarti Stotram',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Sai Baba',
    query: 'Shirdi Sai Baba Aarti Bhajans',
    tag: 'Deity',
  ),
  BhaktiCategory(
    name: 'Maa Parvati',
    query: 'Gauri Parvati Aarti Stotram',
    tag: 'Deity',
  ),
  // Regional Traditions
  BhaktiCategory(
    name: 'Maharashtra: Abhang & Warkari',
    query: 'Sant Tukaram Dnyaneshwar Vitthal Abhang Marathi',
    tag: 'Regional',
  ),
  BhaktiCategory(
    name: 'Gujarat: Krishna & Garba Bhajans',
    query: 'Gujarati Krishna Bhajans Prabhatiya Mataji Na Garba',
    tag: 'Regional',
  ),
  BhaktiCategory(
    name: 'Punjab: Shabad Kirtan',
    query: 'Gurbani Shabad Kirtan Waheguru Simran',
    tag: 'Regional',
  ),
  BhaktiCategory(
    name: 'Bengal: Devotional & Kirtan',
    query: 'Bengali Kirtan Shyama Sangeet Krishna Nam',
    tag: 'Regional',
  ),
  BhaktiCategory(
    name: 'South Indian Devotional',
    query: 'South Indian Carnatic Devotional Songs Tamil Telugu Kannada',
    tag: 'Regional',
  ),
  BhaktiCategory(
    name: 'North Indian Bhajans',
    query: 'North Indian Bhajans Khatu Shyam Mata Rani Jagran',
    tag: 'Regional',
  ),
];

class BhaktiSpiritualSection extends StatefulWidget {
  final String pluginId;

  const BhaktiSpiritualSection({super.key, required this.pluginId});

  @override
  State<BhaktiSpiritualSection> createState() => _BhaktiSpiritualSectionState();
}

class _BhaktiSpiritualSectionState extends State<BhaktiSpiritualSection> {
  late BhaktiCategory _selectedCategory;
  bool _isLoading = false;
  String? _error;

  final Map<String, List<Track>> _bhaktiCache = {};
  int _activeRequestId = 0;

  @override
  void initState() {
    super.initState();
    _selectedCategory = kBhaktiCategories.first;
    _fetchBhaktiTracks(_selectedCategory);
  }

  Future<void> _fetchBhaktiTracks(BhaktiCategory cat) async {
    final requestId = ++_activeRequestId;

    if (_bhaktiCache.containsKey(cat.name) &&
        _bhaktiCache[cat.name]!.isNotEmpty) {
      setState(() {
        _selectedCategory = cat;
        _isLoading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _selectedCategory = cat;
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ServiceLocator.pluginService.execute(
        pluginId: widget.pluginId,
        request: PluginRequest.contentResolver(
          ContentResolverCommand.search(
            query: cat.query,
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

          _bhaktiCache[cat.name] = deduplicated;

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
          _error = 'Failed to load ${cat.name} devotional songs';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTracks = _bhaktiCache[_selectedCategory.name] ?? const [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE65100).withValues(alpha: 0.20),
            const Color(0xFF4A148C).withValues(alpha: 0.15),
            Default_Theme.themeColor,
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFB300).withValues(alpha: 0.25),
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
                  color: const Color(0xFFFFB300).withValues(alpha: 0.2),
                ),
                child: const Icon(
                  MingCute.sun_fill,
                  size: 18,
                  color: Color(0xFFFFB300),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Bhakti & Spiritual',
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
                  '${currentTracks.length} Bhajans',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Sacred bhajans, aartis, kirtans, and devotional traditions across India.',
            style: TextStyle(
              fontSize: 13,
              color: Default_Theme.primaryColor1.withValues(alpha: 0.65),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          // Category selection chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: kBhaktiCategories.map((cat) {
                final isSelected = _selectedCategory.name == cat.name;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat.name),
                    selected: isSelected,
                    onSelected: (val) => _fetchBhaktiTracks(cat),
                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                    selectedColor:
                        const Color(0xFFFFB300).withValues(alpha: 0.25),
                    checkmarkColor: const Color(0xFFFFB300),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFFFFD54F)
                          : Default_Theme.primaryColor1.withValues(alpha: 0.75),
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFFFFB300)
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
                child: CircularProgressIndicator(color: Color(0xFFFFB300)),
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
                      onPressed: () => _fetchBhaktiTracks(_selectedCategory),
                      icon: const Icon(MingCute.refresh_3_line, size: 16),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB300),
                        foregroundColor: Colors.black87,
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
                  message:
                      'No devotional tracks found for ${_selectedCategory.name}',
                  icon: MingCute.sun_line,
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
                            title: '${_selectedCategory.name} Bhakti',
                          ),
                          doPlay: true,
                          idx: 0,
                        );
                  },
                  icon: const Icon(MingCute.play_fill, size: 16),
                  label: const Text('Play All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB300),
                    foregroundColor: Colors.black87,
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
                            title: '${_selectedCategory.name} Bhakti',
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
                            title: '${_selectedCategory.name} Bhakti',
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
