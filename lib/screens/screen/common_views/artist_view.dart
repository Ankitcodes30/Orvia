// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:ui';

import 'package:Orvia/blocs/media_player/orvia_player_cubit.dart';
import 'package:Orvia/core/di/service_locator.dart';
import 'package:Orvia/core/events/global_event_bus.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/plugins/blocs/content/content_bloc.dart';
import 'package:Orvia/plugins/blocs/content/content_event.dart';
import 'package:Orvia/plugins/blocs/content/content_state.dart';
import 'package:Orvia/plugins/blocs/plugin/plugin_bloc.dart';
import 'package:Orvia/blocs/library/cubit/library_items_cubit.dart';
import 'package:Orvia/screens/widgets/album_card.dart';
import 'package:Orvia/screens/widgets/animated_list_item.dart';
import 'package:Orvia/screens/widgets/more_bottom_sheet.dart';
import 'package:Orvia/screens/widgets/sign_board_widget.dart';
import 'package:Orvia/screens/widgets/snackbar.dart';
import 'package:Orvia/screens/widgets/song_tile.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/utils/load_image.dart';
import 'package:Orvia/src/rust/api/plugin/commands.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ArtistView extends StatefulWidget {
  final ArtistSummary artist;
  final String pluginId;

  const ArtistView({super.key, required this.artist, required this.pluginId});

  static String _normalizeArtistString(String str) {
    return str.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static bool isTrackRelatedToArtist(Track track, String artistName, {String? artistId}) {
    final cleanTarget = _normalizeArtistString(artistName);
    if (cleanTarget.isEmpty) return true;

    // 1. Direct ID match if available
    if (artistId != null && artistId.isNotEmpty) {
      final cleanTargetId = artistId.contains('::') ? artistId.split('::').last : artistId;
      for (final a in track.artists) {
        final aId = a.id.contains('::') ? a.id.split('::').last : a.id;
        if (aId.isNotEmpty && aId == cleanTargetId) return true;
      }
    }

    // 2. Track artists (vocals, featured, composer, producer, collaborations)
    for (final a in track.artists) {
      final cleanA = _normalizeArtistString(a.name);
      if (cleanA.isEmpty) continue;
      if (cleanA == cleanTarget ||
          cleanA.contains(cleanTarget) ||
          cleanTarget.contains(cleanA)) {
        return true;
      }
    }

    // 3. Album artists match if available
    if (track.album?.artists != null) {
      for (final a in track.album!.artists) {
        final cleanA = _normalizeArtistString(a.name);
        if (cleanA.isEmpty) continue;
        if (cleanA == cleanTarget ||
            cleanA.contains(cleanTarget) ||
            cleanTarget.contains(cleanA)) {
          return true;
        }
      }
    }

    return false;
  }

  @override
  State<ArtistView> createState() => _ArtistViewState();
}

class _ArtistViewState extends State<ArtistView> {
  late final ContentBloc _contentBloc;
  bool _isSaved = false;

  final List<Track> _catalogueTracks = [];
  String? _nextPageToken;
  bool _isLoadingCatalogue = false;
  bool _isLoadingMoreTracks = false;
  String? _catalogueError;
  bool _isSearching = false;
  late final TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _contentBloc = ContentBloc(pluginService: ServiceLocator.pluginService);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!context.read<PluginBloc>().state.isPluginLoaded(widget.pluginId)) {
        GlobalEventBus.instance.emitError(
          AppError.pluginNotLoaded(pluginId: widget.pluginId),
        );
        return;
      }
      _contentBloc.add(LoadArtistDetails(
        pluginId: widget.pluginId,
        artistId: widget.artist.id,
      ));
      _fetchInitialCatalogue();
      _checkSavedState();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _contentBloc.close();
    super.dispose();
  }

  Future<void> _fetchInitialCatalogue() async {
    if (_isLoadingCatalogue) return;
    setState(() {
      _isLoadingCatalogue = true;
      _catalogueError = null;
    });

    try {
      final response = await ServiceLocator.pluginService.execute(
        pluginId: widget.pluginId,
        request: PluginRequest.contentResolver(
          ContentResolverCommand.search(
            query: widget.artist.name,
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
              track: (t) {
                if (ArtistView.isTrackRelatedToArtist(t, widget.artist.name, artistId: widget.artist.id)) {
                  tracks.add(t);
                }
              },
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
          setState(() {
            _catalogueTracks
              ..clear()
              ..addAll(deduplicated);
            _nextPageToken = results.nextPageToken;
            _isLoadingCatalogue = false;
          });
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
      if (mounted) {
        setState(() {
          _isLoadingCatalogue = false;
          _catalogueError = e.toString();
        });
      }
    }
  }

  Future<void> _loadMoreCatalogue() async {
    if (_isLoadingMoreTracks || _nextPageToken == null || _searchQuery.isNotEmpty) return;
    setState(() => _isLoadingMoreTracks = true);

    try {
      final response = await ServiceLocator.pluginService.execute(
        pluginId: widget.pluginId,
        request: PluginRequest.contentResolver(
          ContentResolverCommand.search(
            query: widget.artist.name,
            filter: ContentSearchFilter.track,
            pageToken: _nextPageToken,
          ),
        ),
      );

      if (!mounted) return;

      response.when(
        search: (results) {
          final newTracks = <Track>[];
          for (final item in results.items) {
            item.when(
              track: (t) {
                if (ArtistView.isTrackRelatedToArtist(t, widget.artist.name, artistId: widget.artist.id)) {
                  newTracks.add(t);
                }
              },
              album: (_) {},
              artist: (_) {},
              playlist: (_) {},
            );
          }
          final existingIds = _catalogueTracks.map((t) => t.id).toSet();
          final deduplicated = newTracks
              .where((t) => t.id.isNotEmpty && !existingIds.contains(t.id))
              .toList();

          setState(() {
            _catalogueTracks.addAll(deduplicated);
            _nextPageToken = results.nextPageToken;
            _isLoadingMoreTracks = false;
          });
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
      if (mounted) {
        setState(() => _isLoadingMoreTracks = false);
      }
    }
  }

  String _sourceName(BuildContext context) {
    final plugins = context.read<PluginBloc>().state.availablePlugins;
    for (final plugin in plugins) {
      if (plugin.manifest.id == widget.pluginId) return plugin.manifest.name;
    }
    return widget.pluginId;
  }

  Future<void> _checkSavedState() async {
    final saved = await context
        .read<LibraryItemsCubit>()
        .isRemoteSaved(widget.artist.id, PlaylistType.artist);
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<void> _toggleSaveState() async {
    final cubit = context.read<LibraryItemsCubit>();
    if (_isSaved) {
      await cubit.removeRemoteSaved(widget.artist.id, PlaylistType.artist);
    } else {
      await cubit.saveRemoteArtist(
        artist: widget.artist,
        sourceName: _sourceName(context),
      );
    }
    await _checkSavedState();
  }

  void _loadMoreAlbums() {
    final details = _contentBloc.state.artistDetails;
    final nextPageToken = details?.albums.nextPageToken;
    final status = _contentBloc.state.artistDetailStatus;

    if (nextPageToken == null ||
        status == DetailStatus.loading ||
        status == DetailStatus.loadingMore) return;

    _contentBloc.add(LoadMoreArtistAlbums(
      pluginId: widget.pluginId,
      artistId: widget.artist.id,
      pageToken: nextPageToken,
    ));
  }

  String? _cleanText(String? raw) {
    final clean = raw?.trim();
    return (clean == null || clean.isEmpty || clean == '[]') ? null : clean;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Default_Theme.themeColor,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildOptimizedBackground(),
          _buildScrollableContent(),
        ],
      ),
    );
  }

  // ─── ARCHITECTURE METHODS ───

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leadingWidth: 70,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16.0),
        child: Center(
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Default_Theme.themeColor.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Default_Theme.primaryColor1.withValues(alpha: 0.15),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Default_Theme.primaryColor1,
                size: 20,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      title: _isSearching
          ? Container(
              height: 40,
              decoration: BoxDecoration(
                color: Default_Theme.themeColor.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Default_Theme.primaryColor1.withValues(alpha: 0.2),
                ),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search in ${widget.artist.name}...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(MingCute.search_line,
                      size: 18, color: Default_Theme.accentColor2),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              size: 16, color: Colors.white70),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim());
                },
              ),
            )
          : null,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Default_Theme.themeColor.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Default_Theme.primaryColor1.withValues(alpha: 0.15),
                ),
              ),
              child: Icon(
                _isSearching ? Icons.close_rounded : MingCute.search_line,
                color: Default_Theme.primaryColor1,
                size: 20,
              ),
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOptimizedBackground() {
    return Positioned.fill(
      child: RepaintBoundary(
        child: BlocSelector<ContentBloc, ContentState, String>(
          bloc: _contentBloc,
          selector: (state) {
            final summary = state.artistDetails?.summary;
            return summary?.thumbnail?.urlHigh ??
                summary?.thumbnail?.url ??
                widget.artist.thumbnail?.urlHigh ??
                widget.artist.thumbnail?.url ??
                '';
          },
          builder: (context, imageUrl) {
            return Stack(
              fit: StackFit.expand,
              children: [
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                  child: LoadImageCached(
                    imageUrl: imageUrl,
                    fallbackUrl: widget.artist.thumbnail?.url,
                    fit: BoxFit.cover,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Default_Theme.themeColor.withValues(alpha: 0.4),
                        Default_Theme.themeColor.withValues(alpha: 0.9),
                        Default_Theme.themeColor,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildScrollableContent() {
    return SafeArea(
      bottom: false,
      top: false,
      child: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return <Widget>[
              _buildArtistHeaderSliver(),
              SliverOverlapAbsorber(
                handle:
                    NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                sliver: SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color:
                            Default_Theme.accentColor2.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color:
                              Default_Theme.accentColor2.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      splashBorderRadius: BorderRadius.circular(24),
                      labelColor: Default_Theme.accentColor2,
                      unselectedLabelColor:
                          Default_Theme.primaryColor1.withValues(alpha: 0.6),
                      labelStyle: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)
                          .merge(Default_Theme.secondoryTextStyleMedium),
                      unselectedLabelStyle: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)
                          .merge(Default_Theme.secondoryTextStyle),
                      tabs: const [Tab(text: 'Popular Songs'), Tab(text: 'Albums')],
                    ),
                  ),
                ),
              ),
            ];
          },
          body: _buildTabsBody(),
        ),
      ),
    );
  }

  Widget _buildArtistHeaderSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: BlocBuilder<ContentBloc, ContentState>(
          bloc: _contentBloc,
          builder: (context, state) {
            final details = state.artistDetails;
            final artistSummary = details?.summary ?? widget.artist;
            final topTracks = details?.topTracks ?? [];
            final albums = details?.albums.items ?? [];
            final imageUrl = artistSummary.thumbnail?.urlHigh ??
                artistSummary.thumbnail?.url ??
                widget.artist.thumbnail?.urlHigh ??
                widget.artist.thumbnail?.url ??
                '';

            final allTracks =
                _catalogueTracks.isNotEmpty ? _catalogueTracks : topTracks;
            final artistMeta = <String>[
              if (allTracks.isNotEmpty)
                '${allTracks.length} Song${allTracks.length == 1 ? '' : 's'}',
              if (albums.isNotEmpty)
                '${albums.length} Album${albums.length == 1 ? '' : 's'}',
            ];

            return LayoutBuilder(
              builder: (context, constraints) {
                return _ArtistHeaderContent(
                  isMobile: constraints.maxWidth < 750,
                  imageUrl: imageUrl,
                  fallbackUrl: artistSummary.thumbnail?.url,
                  title: artistSummary.name,
                  subtitle: _cleanText(artistSummary.subtitle),
                  meta: artistMeta,
                  description: _cleanText(details?.description),
                  pluginId: widget.pluginId,
                  artistId: artistSummary.id,
                  topTracks: allTracks,
                  isSaved: _isSaved,
                  url: artistSummary.url,
                  onToggleSave: _toggleSaveState,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabsBody() {
    return BlocBuilder<ContentBloc, ContentState>(
      bloc: _contentBloc,
      builder: (context, state) {
        if (state.artistDetailStatus == DetailStatus.error) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    (state.error?.contains('offline') ?? false)
                        ? MingCute.wifi_off_line
                        : MingCute.warning_line,
                    size: 44,
                    color: Default_Theme.primaryColor1.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    state.error ?? 'Failed to load artist',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Default_Theme.primaryColor1.withValues(alpha: 0.7),
                    ).merge(Default_Theme.secondoryTextStyle),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      _contentBloc.add(LoadArtistDetails(
                          pluginId: widget.pluginId,
                          artistId: widget.artist.id));
                      _fetchInitialCatalogue();
                    },
                    icon: const Icon(MingCute.refresh_3_line, size: 18),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Default_Theme.accentColor2,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (state.artistDetailStatus != DetailStatus.loaded &&
            state.artistDetailStatus != DetailStatus.loadingMore) {
          return const Center(
            child: CircularProgressIndicator(color: Default_Theme.accentColor2),
          );
        }

        final details = state.artistDetails;
        final topTracks = details?.topTracks ?? [];
        final albums = details?.albums.items ?? [];
        final artistName = details?.summary.name ?? widget.artist.name;

        return TabBarView(
          children: [
            _buildTopTracksTab(topTracks, artistName),
            _buildAlbumsTab(albums, state.artistDetailStatus),
          ],
        );
      },
    );
  }

  Widget _buildTopTracksTab(List<Track> topTracks, String artistName) {
    if (_isLoadingCatalogue && _catalogueTracks.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Default_Theme.accentColor2),
      );
    }

    final seenIds = <String>{};
    final combined = <Track>[];
    for (final t in topTracks) {
      if (t.id.isNotEmpty && seenIds.add(t.id)) {
        combined.add(t);
      }
    }
    for (final t in _catalogueTracks) {
      if (t.id.isNotEmpty && seenIds.add(t.id)) {
        combined.add(t);
      }
    }

    final displayedTracks = _searchQuery.isEmpty
        ? combined
        : combined.where((t) {
            final q = _searchQuery.toLowerCase();
            return t.title.toLowerCase().contains(q) ||
                (t.album?.title.toLowerCase().contains(q) ?? false);
          }).toList();

    if (displayedTracks.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return Center(
          child: SignBoardWidget(
            message: 'No songs matching "$_searchQuery"',
            icon: MingCute.search_line,
          ),
        );
      }
      return const Center(
        child: SignBoardWidget(
          message: 'No songs available',
          icon: MingCute.music_2_line,
        ),
      );
    }

    return Builder(
      builder: (context) {
        return NotificationListener<ScrollNotification>(
          onNotification: (scrollInfo) {
            if (scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 240) {
              _loadMoreCatalogue();
            }
            return false;
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            key: const PageStorageKey('artist_songs'),
            slivers: [
              SliverOverlapInjector(
                  handle:
                      NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
              SliverPadding(
                padding: const EdgeInsets.only(top: 12, bottom: 100),
                sliver: SliverList.builder(
                  itemCount:
                      displayedTracks.length + (_isLoadingMoreTracks ? 1 : 0),
                  addRepaintBoundaries: true,
                  itemBuilder: (context, index) {
                    if (index >= displayedTracks.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Default_Theme.accentColor2,
                            ),
                          ),
                        ),
                      );
                    }
                    return AnimatedListItem(
                      index: index,
                      child: SongCardWidget(
                        song: displayedTracks[index],
                        onOptionsTap: () => showMoreBottomSheet(
                          context,
                          displayedTracks[index],
                          showDelete: false,
                          showSinglePlay: true,
                        ),
                        onTap: () {
                          context
                              .read<OrviaPlayerCubit>()
                              .orviaPlayer
                              .loadPlaylist(
                                Playlist(
                                    tracks: displayedTracks, title: artistName),
                                doPlay: true,
                                idx: index,
                              );
                        },
                      ),
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

  Widget _buildAlbumsTab(List<AlbumSummary> albums, DetailStatus status) {
    if (albums.isEmpty) {
      return const Center(
          child: SignBoardWidget(
              message: 'No albums available', icon: MingCute.album_line));
    }

    return Builder(
      builder: (context) {
        return NotificationListener<ScrollNotification>(
          onNotification: (scrollInfo) {
            if (scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 200) {
              _loadMoreAlbums();
            }
            return false;
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            key: const PageStorageKey('artist_albums'),
            slivers: [
              SliverOverlapInjector(
                  handle:
                      NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisExtent: 230,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == albums.length) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: Default_Theme.accentColor2));
                      }
                      return AnimatedListItem(
                        index: index,
                        child: AlbumCard(
                            album: albums[index], pluginId: widget.pluginId),
                      );
                    },
                    childCount: albums.length +
                        (status == DetailStatus.loadingMore ? 1 : 0),
                    addRepaintBoundaries: true,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── HEADER CONTENT WIDGET ───

class _ArtistHeaderContent extends StatelessWidget {
  final bool isMobile;
  final String imageUrl;
  final String? fallbackUrl;
  final String title;
  final String? subtitle;
  final List<String> meta;
  final String? description;
  final String pluginId;
  final String artistId;
  final List<Track> topTracks;
  final bool isSaved;
  final String? url;
  final VoidCallback onToggleSave;

  const _ArtistHeaderContent({
    required this.isMobile,
    required this.imageUrl,
    this.fallbackUrl,
    required this.title,
    this.subtitle,
    required this.meta,
    this.description,
    required this.pluginId,
    required this.artistId,
    required this.topTracks,
    required this.isSaved,
    this.url,
    required this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildAvatar(150),
            const SizedBox(height: 24),
            _buildInfo(isCentered: true),
            const SizedBox(height: 24),
            _buildActions(context, isCentered: true),
            const SizedBox(height: 16),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildAvatar(200),
          const SizedBox(width: 40),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfo(isCentered: false),
                const SizedBox(height: 24),
                _buildActions(context, isCentered: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(double size) {
    return Hero(
      tag: '${pluginId}_artist_$artistId',
      child: RepaintBoundary(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 40,
                offset: const Offset(0, 15),
              ),
            ],
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.1), width: 1),
          ),
          child: ClipOval(
            child: LoadImageCached(
              imageUrl: imageUrl,
              fallbackUrl: fallbackUrl,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfo({required bool isCentered}) {
    return Column(
      crossAxisAlignment:
          isCentered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        if (subtitle != null) ...[
          Text(
            subtitle!.toUpperCase(),
            style: TextStyle(
              color: Default_Theme.accentColor2.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ).merge(Default_Theme.secondoryTextStyle),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          title,
          textAlign: isCentered ? TextAlign.center : TextAlign.left,
          style: const TextStyle(
            color: Default_Theme.primaryColor1,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            height: 1.1,
          ).merge(Default_Theme.secondoryTextStyleMedium),
        ),
        const SizedBox(height: 10),
        if (meta.isNotEmpty)
          Text(
            meta.join(' • '),
            style: TextStyle(
              color: Default_Theme.primaryColor1.withValues(alpha: 0.6),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ).merge(Default_Theme.secondoryTextStyle),
          ),
        if (description != null) ...[
          const SizedBox(height: 14),
          Text(
            description!,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: isCentered ? TextAlign.center : TextAlign.left,
            style: TextStyle(
              color: Default_Theme.primaryColor1.withValues(alpha: 0.5),
              fontSize: 14,
              height: 1.4,
            ).merge(Default_Theme.secondoryTextStyle),
          ),
        ],
      ],
    );
  }

  Widget _buildActions(BuildContext context, {required bool isCentered}) {
    final player = context.read<OrviaPlayerCubit>().orviaPlayer;
    return StreamBuilder<bool>(
      stream: player.playingStream,
      builder: (context, playSnap) {
        return StreamBuilder<String>(
          stream: player.queueTitle,
          builder: (context, titleSnap) {
            final isPlaying = playSnap.data ?? false;
            final currentQueue = titleSnap.data ?? '';
            final isThisQueue = currentQueue.trim().toLowerCase() ==
                title.trim().toLowerCase();

            return Wrap(
              alignment:
                  isCentered ? WrapAlignment.center : WrapAlignment.start,
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  height: 44,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: topTracks.isEmpty
                          ? null
                          : () {
                              if (isThisQueue) {
                                if (isPlaying) {
                                  player.pause();
                                } else {
                                  player.play();
                                }
                              } else {
                                player.loadPlaylist(
                                  Playlist(tracks: topTracks, title: title),
                                  doPlay: true,
                                  idx: 0,
                                );
                              }
                            },
                      borderRadius: BorderRadius.circular(30),
                      splashColor:
                          Default_Theme.accentColor2.withValues(alpha: 0.2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          color: Default_Theme.accentColor2
                              .withValues(alpha: 0.15),
                          border: Border.all(
                              color: Default_Theme.accentColor2, width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              (isThisQueue && isPlaying)
                                  ? MingCute.pause_fill
                                  : MingCute.play_fill,
                              size: 20,
                              color: Default_Theme.accentColor2,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              (isThisQueue && isPlaying) ? 'Pause' : 'Play',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Default_Theme.accentColor2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _PremiumCircularButton(
                  icon: MingCute.shuffle_line,
                  color: Default_Theme.primaryColor1,
                  isActive: false,
                  tooltip: 'Shuffle Play',
                  onTap: topTracks.isEmpty
                      ? () {}
                      : () {
                          player.loadPlaylist(
                            Playlist(tracks: topTracks, title: title),
                            doPlay: true,
                            shuffling: true,
                          );
                        },
                ),
                _PremiumCircularButton(
                  icon: MingCute.playlist_2_line,
                  color: Default_Theme.primaryColor1,
                  isActive: false,
                  tooltip: 'Add to Up Next',
                  onTap: topTracks.isEmpty
                      ? () {}
                      : () {
                          player.addQueueTracks(topTracks, atLast: false);
                          SnackbarService.showMessage(
                              'Added ${topTracks.length} track${topTracks.length == 1 ? '' : 's'} to Up Next');
                        },
                ),
                _PremiumCircularButton(
                  icon: isSaved
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isSaved
                      ? Default_Theme.accentColor2
                      : Default_Theme.primaryColor1,
                  isActive: isSaved,
                  tooltip: isSaved ? 'Remove from Library' : 'Save to Library',
                  onTap: onToggleSave,
                ),
                if (url != null)
                  _PremiumCircularButton(
                    icon: MingCute.external_link_line,
                    color: Default_Theme.primaryColor1,
                    isActive: false,
                    tooltip: 'Open Original Link',
                    onTap: () {
                      SnackbarService.showMessage(
                          'Opening original artist page.');
                      launchUrl(Uri.parse(url!),
                          mode: LaunchMode.externalApplication);
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PremiumCircularButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isActive;
  final String tooltip;
  final VoidCallback onTap;

  const _PremiumCircularButton({
    required this.icon,
    required this.color,
    required this.isActive,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(25),
          child: Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? Default_Theme.accentColor2.withValues(alpha: 0.15)
                  : Default_Theme.primaryColor1.withValues(alpha: 0.05),
              border: Border.all(
                color: isActive
                    ? Default_Theme.accentColor2.withValues(alpha: 0.5)
                    : Default_Theme.primaryColor1.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => 60.0;
  @override
  double get maxExtent => 60.0;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          color: Default_Theme.themeColor.withValues(alpha: 0.2),
          alignment: Alignment.center,
          child: Container(
            height: 44,
            constraints: const BoxConstraints(maxWidth: 400),
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              color: Default_Theme.primaryColor1.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Default_Theme.primaryColor1.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
            child: _tabBar,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

