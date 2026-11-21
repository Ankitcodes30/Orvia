import 'package:Orvia/blocs/media_player/orvia_player_cubit.dart';
import 'package:Orvia/core/di/service_locator.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/core/utils/track_identity.dart';
import 'package:Orvia/screens/widgets/bhakti_section.dart';
import 'package:Orvia/screens/widgets/load_more_songs_tile.dart';
import 'package:Orvia/screens/widgets/more_bottom_sheet.dart';
import 'package:Orvia/screens/widgets/sign_board_widget.dart';
import 'package:Orvia/screens/widgets/song_tile.dart';
import 'package:Orvia/services/catalogue/best_of_2026_service.dart';
import 'package:Orvia/services/catalogue/curated_playlists_service.dart';
import 'package:Orvia/src/rust/api/plugin/commands.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'package:Orvia/screens/widgets/navratri_special_card.dart';

class IndianCategoryItem {
  final String title;
  final String query;
  final IconData icon;
  final Color accentColor;

  const IndianCategoryItem({
    required this.title,
    required this.query,
    required this.icon,
    required this.accentColor,
  });
}

const List<IndianCategoryItem> kIndianBrowseCategories = [
  IndianCategoryItem(
    title: 'Best of 2026',
    query: 'Latest 2026 Hindi Chartbusters',
    icon: MingCute.sparkles_fill,
    accentColor: Color(0xFF9C27B0),
  ),
  IndianCategoryItem(
    title: 'Bollywood Hits',
    query: 'Top Bollywood Chartbusters Dance Songs',
    icon: MingCute.film_fill,
    accentColor: Color(0xFFF44336),
  ),
  IndianCategoryItem(
    title: 'Lofi & Chill',
    query: 'Hindi Lofi Chill Beats Aesthetic',
    icon: MingCute.headphone_fill,
    accentColor: Color(0xFF673AB7),
  ),
  IndianCategoryItem(
    title: 'Study / Focus',
    query: 'Study Focus Ambient Deep Work Music',
    icon: MingCute.book_2_fill,
    accentColor: Color(0xFF607D8B),
  ),
  IndianCategoryItem(
    title: 'Sleep / Relaxing',
    query: 'Deep Sleep Relaxing Ambient Peaceful Music',
    icon: MingCute.moon_fill,
    accentColor: Color(0xFF795548),
  ),
  IndianCategoryItem(
    title: 'Instrumental Discovery',
    query: 'Indian Instrumental Classical Sitar Flute Saxophone',
    icon: MingCute.guitar_fill,
    accentColor: Color(0xFF2E7D32),
  ),
  IndianCategoryItem(
    title: 'Bhakti & Spiritual',
    query: 'Bhakti Devotional Bhajan Aarti Mantra Devi',
    icon: MingCute.flower_fill,
    accentColor: Color(0xFFFF9800),
  ),
  IndianCategoryItem(
    title: 'Marathi Hits',
    query: 'Top Marathi Hits Bhavgeet Lavani Party Songs',
    icon: MingCute.heart_fill,
    accentColor: Color(0xFF009688),
  ),
  IndianCategoryItem(
    title: 'Punjabi Hits',
    query: 'Latest Punjabi Pop Hits',
    icon: MingCute.disc_fill,
    accentColor: Color(0xFFFF9800),
  ),
  IndianCategoryItem(
    title: 'Haryanvi Hits',
    query: 'Top Haryanvi Hits Ragni Songs',
    icon: MingCute.volume_fill,
    accentColor: Color(0xFFFFC107),
  ),
  IndianCategoryItem(
    title: 'Gujarati Hits',
    query: 'Gujarati Top Songs Geet',
    icon: MingCute.palette_fill,
    accentColor: Color(0xFF4CAF50),
  ),
  IndianCategoryItem(
    title: 'Tamil Hits',
    query: 'Latest Tamil Hits Kollywood',
    icon: MingCute.star_fill,
    accentColor: Color(0xFF00BCD4),
  ),
  IndianCategoryItem(
    title: 'Telugu Hits',
    query: 'Latest Telugu Hits Tollywood',
    icon: MingCute.flash_fill,
    accentColor: Color(0xFF03A9F4),
  ),
  IndianCategoryItem(
    title: 'Bengali Hits',
    query: 'Top Bengali Songs Rabindra Sangeet Hits',
    icon: MingCute.flower_fill,
    accentColor: Color(0xFF3F51B5),
  ),
  IndianCategoryItem(
    title: 'Best of 2025',
    query: 'Best of 2025 Hindi Hits',
    icon: MingCute.calendar_fill,
    accentColor: Color(0xFFE91E63),
  ),
  IndianCategoryItem(
    title: 'Navratri 2026',
    query: 'Navratri 2026 Garba Dandiya Mataji Bhakti',
    icon: MingCute.fire_fill,
    accentColor: Color(0xFFFF7A00),
  ),
];

class IndianBrowseCategories extends StatelessWidget {
  final String pluginId;

  const IndianBrowseCategories({super.key, required this.pluginId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Text(
                'Indian-First Discovery',
                style: Default_Theme.primaryTextStyle.merge(
                  const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Default_Theme.primaryColor1,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${kIndianBrowseCategories.length} Categories',
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 90,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: kIndianBrowseCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final cat = kIndianBrowseCategories[index];
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => _CategoryDetailScreen(
                        category: cat,
                        pluginId: pluginId,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 150,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cat.accentColor.withValues(alpha: 0.35),
                        cat.accentColor.withValues(alpha: 0.12),
                        Default_Theme.themeColor,
                      ],
                    ),
                    border: Border.all(
                      color: cat.accentColor.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(cat.icon, size: 22, color: cat.accentColor),
                      Text(
                        cat.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Default_Theme.primaryColor1,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
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

class CategoryDetailScreenLauncher extends StatelessWidget {
  final IndianCategoryItem category;
  final String pluginId;

  const CategoryDetailScreenLauncher({
    super.key,
    required this.category,
    required this.pluginId,
  });

  @override
  Widget build(BuildContext context) {
    return _CategoryDetailScreen(category: category, pluginId: pluginId);
  }
}

class _CategoryDetailScreen extends StatefulWidget {
  final IndianCategoryItem category;
  final String pluginId;

  const _CategoryDetailScreen({
    required this.category,
    required this.pluginId,
  });

  @override
  State<_CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<_CategoryDetailScreen> {
  final List<Track> _tracks = [];
  bool _isLoading = true;
  String? _error;
  String? _nextPageToken;
  bool _isLoadingMore = false;
  String? _loadMoreError;

  @override
  void initState() {
    super.initState();
    _fetchTracks();
  }

  Future<void> _fetchTracks() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _loadMoreError = null;
    });

    try {
      if (widget.category.title == 'Best of 2026') {
        final verifiedTracks = BestOf2026Service.getVerified2026Tracks();
        if (mounted) {
          setState(() {
            _tracks
              ..clear()
              ..addAll(TrackIdentity.deduplicateTracks(verifiedTracks));
            _isLoading = false;
            _nextPageToken = null;
          });
        }
        return;
      }

      if (widget.category.title == 'Bollywood Hits') {
        final verifiedTracks = CuratedPlaylistsService.getBollywoodTracks();
        if (mounted) {
          setState(() {
            _tracks
              ..clear()
              ..addAll(TrackIdentity.deduplicateTracks(verifiedTracks));
            _isLoading = false;
            _nextPageToken = '1';
          });
        }
        return;
      }

      if (widget.category.title == 'Marathi Hits') {
        final verifiedTracks = CuratedPlaylistsService.getMarathiTracks();
        if (mounted) {
          setState(() {
            _tracks
              ..clear()
              ..addAll(TrackIdentity.deduplicateTracks(verifiedTracks));
            _isLoading = false;
            _nextPageToken = '1';
          });
        }
        return;
      }

      if (widget.category.title == 'Instrumental Discovery' ||
          widget.category.title == 'Instrumental') {
        final verifiedTracks = CuratedPlaylistsService.getInstrumentalTracks();
        if (mounted) {
          setState(() {
            _tracks
              ..clear()
              ..addAll(TrackIdentity.deduplicateTracks(verifiedTracks));
            _isLoading = false;
            _nextPageToken = '1';
          });
        }
        return;
      }

      if (widget.category.title == 'Bhakti & Spiritual') {
        if (mounted) {
          setState(() {
            _tracks
              ..clear()
              ..addAll(TrackIdentity.deduplicateTracks(kVerifiedBhaktiTracks));
            _isLoading = false;
            _nextPageToken = '1';
          });
        }
        return;
      }

      if (widget.category.title == 'Navratri 2026') {
        final verifiedTracks =
            kVerifiedNavratriTracks.map((item) => item.track).toList();
        if (mounted) {
          setState(() {
            _tracks
              ..clear()
              ..addAll(TrackIdentity.deduplicateTracks(verifiedTracks));
            _isLoading = false;
            _nextPageToken = null;
          });
        }
        return;
      }

      final response = await ServiceLocator.pluginService.execute(
        pluginId: widget.pluginId,
        request: PluginRequest.contentResolver(
          ContentResolverCommand.search(
            query: widget.category.query,
            filter: ContentSearchFilter.track,
          ),
        ),
      ).timeout(const Duration(seconds: 15));

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
          final deduplicated = TrackIdentity.deduplicateTracks(tracks);
          setState(() {
            _tracks
              ..clear()
              ..addAll(deduplicated);
            _isLoading = false;
            _nextPageToken = results.nextPageToken;
            if (deduplicated.isEmpty) {
              _error = 'No tracks available for ${widget.category.title}';
            }
          });
        },
        trackDetails: (_) => _handleNonSearchResponse(),
        albumDetails: (_) => _handleNonSearchResponse(),
        artistDetails: (_) => _handleNonSearchResponse(),
        playlistDetails: (_) => _handleNonSearchResponse(),
        streams: (_) => _handleNonSearchResponse(),
        moreTracks: (paged) {
          final deduplicated = TrackIdentity.deduplicateTracks(paged.items);
          setState(() {
            _tracks
              ..clear()
              ..addAll(deduplicated);
            _isLoading = false;
            _nextPageToken = paged.nextPageToken;
          });
        },
        moreAlbums: (_) => _handleNonSearchResponse(),
        homeSections: (_) => _handleNonSearchResponse(),
        loadMoreItems: (_) => _handleNonSearchResponse(),
        charts: (_) => _handleNonSearchResponse(),
        chartDetails: (_) => _handleNonSearchResponse(),
        segments: (_) => _handleNonSearchResponse(),
        lyricsResult: (_) => _handleNonSearchResponse(),
        lyricsSearchResults: (_) => _handleNonSearchResponse(),
        lyricsById: (_, __) => _handleNonSearchResponse(),
        suggestions: (_) => _handleNonSearchResponse(),
        canHandle: (_) => _handleNonSearchResponse(),
        collectionInfo: (_) => _handleNonSearchResponse(),
        importTracks: (_) => _handleNonSearchResponse(),
        ack: () => _handleNonSearchResponse(),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load ${widget.category.title}';
        });
      }
    }
  }

  void _handleNonSearchResponse() {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (_tracks.isEmpty) {
        _error = 'No tracks found for ${widget.category.title}';
      }
    });
  }

  Future<void> _loadMoreTracks() async {
    if (_isLoadingMore || _nextPageToken == null) return;

    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });

    try {
      final response = await ServiceLocator.pluginService.execute(
        pluginId: widget.pluginId,
        request: PluginRequest.contentResolver(
          ContentResolverCommand.search(
            query: widget.category.query,
            filter: ContentSearchFilter.track,
            pageToken: _nextPageToken,
          ),
        ),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      response.when(
        search: (results) {
          final newTracks = <Track>[];
          for (final item in results.items) {
            item.when(
              track: (t) => newTracks.add(t),
              album: (_) {},
              artist: (_) {},
              playlist: (_) {},
            );
          }
          final deduplicated = TrackIdentity.deduplicateTracks(
            newTracks,
            existingTracks: _tracks,
          );

          setState(() {
            _tracks.addAll(deduplicated);
            _isLoadingMore = false;
            _nextPageToken = (results.nextPageToken == null || deduplicated.isEmpty)
                ? null
                : results.nextPageToken;
          });
        },
        trackDetails: (_) => setState(() => _isLoadingMore = false),
        albumDetails: (_) => setState(() => _isLoadingMore = false),
        artistDetails: (_) => setState(() => _isLoadingMore = false),
        playlistDetails: (_) => setState(() => _isLoadingMore = false),
        streams: (_) => setState(() => _isLoadingMore = false),
        moreTracks: (paged) {
          final deduplicated = TrackIdentity.deduplicateTracks(
            paged.items,
            existingTracks: _tracks,
          );
          setState(() {
            _tracks.addAll(deduplicated);
            _isLoadingMore = false;
            _nextPageToken = paged.nextPageToken;
          });
        },
        moreAlbums: (_) => setState(() => _isLoadingMore = false),
        homeSections: (_) => setState(() => _isLoadingMore = false),
        loadMoreItems: (_) => setState(() => _isLoadingMore = false),
        charts: (_) => setState(() => _isLoadingMore = false),
        chartDetails: (_) => setState(() => _isLoadingMore = false),
        segments: (_) => setState(() => _isLoadingMore = false),
        lyricsResult: (_) => setState(() => _isLoadingMore = false),
        lyricsSearchResults: (_) => setState(() => _isLoadingMore = false),
        lyricsById: (_, __) => setState(() => _isLoadingMore = false),
        suggestions: (_) => setState(() => _isLoadingMore = false),
        canHandle: (_) => setState(() => _isLoadingMore = false),
        collectionInfo: (_) => setState(() => _isLoadingMore = false),
        importTracks: (_) => setState(() => _isLoadingMore = false),
        ack: () => setState(() => _isLoadingMore = false),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _loadMoreError = 'Failed to load more. Tap to retry';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Default_Theme.themeColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.category.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: Default_Theme.accentColor2),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _fetchTracks,
                        icon: const Icon(MingCute.refresh_3_line, size: 16),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _tracks.isEmpty
                  ? Center(
                      child: SignBoardWidget(
                        message: 'No tracks found for ${widget.category.title}',
                        icon: MingCute.music_2_line,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(
                          bottom: 120, left: 16, right: 16, top: 12),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                context
                                    .read<OrviaPlayerCubit>()
                                    .orviaPlayer
                                    .loadPlaylist(
                                      Playlist(
                                        tracks: _tracks,
                                        title: widget.category.title,
                                      ),
                                      doPlay: true,
                                      idx: 0,
                                      isFromPlaylist: false,
                                    );
                              },
                              icon: const Icon(MingCute.play_fill, size: 16),
                              label: const Text('Play All'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.category.accentColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: () {
                                context
                                    .read<OrviaPlayerCubit>()
                                    .orviaPlayer
                                    .loadPlaylist(
                                      Playlist(
                                        tracks: _tracks,
                                        title: widget.category.title,
                                      ),
                                      doPlay: true,
                                      shuffling: true,
                                      isFromPlaylist: false,
                                    );
                              },
                              icon:
                                  const Icon(MingCute.shuffle_line, size: 16),
                              label: const Text('Shuffle'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_tracks.length} Tracks',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.white54),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ..._tracks.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final song = entry.value;
                          return SongCardWidget(
                            song: song,
                            onOptionsTap: () => showMoreBottomSheet(
                              context,
                              song,
                              showDelete: false,
                              showSinglePlay: true,
                            ),
                            onTap: () {
                              context
                                    .read<OrviaPlayerCubit>()
                                    .orviaPlayer
                                    .loadPlaylist(
                                      Playlist(
                                        tracks: _tracks,
                                        title: widget.category.title,
                                      ),
                                      doPlay: true,
                                      idx: idx,
                                      isFromPlaylist: false,
                                    );
                            },
                          );
                        }),
                        LoadMoreSongsTile(
                          isLoading: _isLoadingMore,
                          hasMore: _nextPageToken != null,
                          error: _loadMoreError,
                          currentCount: _tracks.length,
                          onTap: _loadMoreTracks,
                        ),
                      ],
                    ),
    );
  }
}
