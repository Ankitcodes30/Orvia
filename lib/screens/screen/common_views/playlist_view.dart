import 'dart:async';
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
import 'package:Orvia/screens/widgets/animated_list_item.dart';
import 'package:Orvia/screens/widgets/more_bottom_sheet.dart';
import 'package:Orvia/screens/widgets/sign_board_widget.dart';
import 'package:Orvia/screens/widgets/snackbar.dart';
import 'package:Orvia/screens/widgets/song_tile.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/src/rust/api/plugin/commands.dart';
import 'package:Orvia/utils/load_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class OnlPlaylistView extends StatefulWidget {
  final PlaylistSummary playlist;
  final String pluginId;
  final String? heroTag;

  const OnlPlaylistView({
    super.key,
    required this.playlist,
    required this.pluginId,
    this.heroTag,
  });

  @override
  State<OnlPlaylistView> createState() => _OnlPlaylistViewState();
}

class _OnlPlaylistViewState extends State<OnlPlaylistView> {
  late final ContentBloc _contentBloc;
  late final ScrollController _scrollController;
  StreamSubscription<ContentState>? _contentSubscription;
  bool _isSaved = false;

  List<Track> _fallbackTracks = const [];
  bool _fallbackAttempted = false;
  bool _isSearchingFallback = false;

  @override
  void initState() {
    super.initState();
    _contentBloc = ContentBloc(pluginService: ServiceLocator.pluginService);
    _scrollController = ScrollController()..addListener(_onScroll);

    _contentSubscription = _contentBloc.stream.listen((state) {
      if (!mounted) return;
      if (state.playlistDetailStatus == DetailStatus.loaded) {
        final tracks = state.playlistDetails?.tracks.items ?? [];
        if (tracks.isEmpty && !_fallbackAttempted && !_isSearchingFallback) {
          _fallbackAttempted = true;
          _isSearchingFallback = true;
          final query = widget.playlist.title.trim();
          if (query.isNotEmpty) {
            _contentBloc.add(SetActiveContentPlugin(pluginId: widget.pluginId));
            _contentBloc.add(SearchContent(
              query: query,
              filter: ContentSearchFilter.all,
            ));
          }
        }
      }

      if (_isSearchingFallback && state.searchStatus == SearchStatus.loaded) {
        final results = state.searchResults?.items ?? [];
        final collected = <Track>[];
        for (final item in results) {
          item.when(
            track: (t) => collected.add(t),
            album: (_) {},
            artist: (_) {},
            playlist: (_) {},
          );
        }
        if (mounted) {
          setState(() {
            _fallbackTracks = collected;
            _isSearchingFallback = false;
          });
        }
      } else if (_isSearchingFallback &&
          state.searchStatus == SearchStatus.error) {
        if (mounted) {
          setState(() {
            _isSearchingFallback = false;
          });
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!context.read<PluginBloc>().state.isPluginLoaded(widget.pluginId)) {
        GlobalEventBus.instance
            .emitError(AppError.pluginNotLoaded(pluginId: widget.pluginId));
        return;
      }
      _contentBloc.add(LoadPlaylistDetails(
          pluginId: widget.pluginId, playlistId: widget.playlist.id));
      _checkSavedState();
    });
  }

  @override
  void dispose() {
    _contentSubscription?.cancel();
    _scrollController.dispose();
    _contentBloc.close();
    super.dispose();
  }

  String _sourceName(BuildContext context) {
    for (final plugin in context.read<PluginBloc>().state.availablePlugins) {
      if (plugin.manifest.id == widget.pluginId) return plugin.manifest.name;
    }
    return widget.pluginId;
  }

  Future<void> _checkSavedState() async {
    final saved = await context
        .read<LibraryItemsCubit>()
        .isRemoteSaved(widget.playlist.id, PlaylistType.remotePlaylist);
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<void> _toggleSaveState() async {
    final cubit = context.read<LibraryItemsCubit>();
    if (_isSaved) {
      await cubit.removeRemoteSaved(
          widget.playlist.id, PlaylistType.remotePlaylist);
    } else {
      await cubit.saveRemotePlaylist(
          playlist: widget.playlist, sourceName: _sourceName(context));
    }
    await _checkSavedState();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final details = _contentBloc.state.playlistDetails;
    final nextPageToken = details?.tracks.nextPageToken;
    final status = _contentBloc.state.playlistDetailStatus;

    if (nextPageToken == null ||
        status == DetailStatus.loading ||
        status == DetailStatus.loadingMore) return;

    if (_scrollController.position.maxScrollExtent - _scrollController.offset <=
        320) {
      _contentBloc.add(LoadMorePlaylistTracks(
          pluginId: widget.pluginId,
          playlistId: widget.playlist.id,
          pageToken: nextPageToken));
    }
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
                    color: Default_Theme.primaryColor1.withValues(alpha: 0.15)),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Default_Theme.primaryColor1, size: 20),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  Widget _buildOptimizedBackground() {
    return Positioned.fill(
      child: RepaintBoundary(
        child: BlocSelector<ContentBloc, ContentState, String>(
          bloc: _contentBloc,
          selector: (state) {
            final summary = state.playlistDetails?.summary;
            return summary?.thumbnail.urlHigh ??
                summary?.thumbnail.url ??
                widget.playlist.thumbnail.urlHigh ??
                widget.playlist.thumbnail.url;
          },
          builder: (context, imageUrl) {
            return Stack(
              fit: StackFit.expand,
              children: [
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: LoadImageCached(
                    imageUrl: imageUrl,
                    fallbackUrl: widget.playlist.thumbnail.url,
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
      child: BlocBuilder<ContentBloc, ContentState>(
        bloc: _contentBloc,
        builder: (context, state) {
          final details = state.playlistDetails;
          final rawSummary = details?.summary;
          final bool isSuspiciousTitle = rawSummary != null &&
              isSuspiciousPlaylistTitle(rawSummary.title);

          final playlistSummary = (rawSummary == null || isSuspiciousTitle)
              ? widget.playlist
              : rawSummary;

          final directTracks = details?.tracks.items ?? [];
          final player = context.read<OrviaPlayerCubit>().orviaPlayer;
          final isCurrentQueue = player.queueTracks.isNotEmpty &&
              player.queueTitle.value.trim().toLowerCase() ==
                  playlistSummary.title.trim().toLowerCase();

          final tracks = directTracks.isNotEmpty
              ? directTracks
              : (_fallbackTracks.isNotEmpty
                  ? _fallbackTracks
                  : (isCurrentQueue ? player.queueTracks : const <Track>[]));
          final status = state.playlistDetailStatus;

          final imageUrl = playlistSummary.thumbnail.urlHigh ??
              playlistSummary.thumbnail.url;

          final metaParts = <String>[];
          final lowerTitle = playlistSummary.title.toLowerCase();
          final isStation = lowerTitle.contains('station') ||
              lowerTitle.contains('radio') ||
              (playlistSummary.owner?.toLowerCase().contains('station') ?? false);

          if (isStation) {
            metaParts.add('Station Playlist');
          } else {
            metaParts.add(sanitizePlaylistOwner(playlistSummary.owner));
          }

          if (tracks.isNotEmpty) {
            metaParts
                .add('${tracks.length} Track${tracks.length == 1 ? '' : 's'}');
          }

          final String? description;
          if (_cleanText(details?.description) != null) {
            description = _cleanText(details?.description);
          } else if (lowerTitle.contains('romance')) {
            description = 'Popular and trending Romantic music across genres.';
          } else if (lowerTitle.contains('carvaan')) {
            description =
                'Classic hits and timeless retro melodies from Carvaan.';
          } else if (lowerTitle.contains('90s') ||
              lowerTitle.contains('1990')) {
            description =
                'The finest nostalgic hits and classics from the 1990s.';
          } else if (lowerTitle.contains('dance')) {
            description = 'High-energy dance anthems and party chartbusters.';
          } else if (lowerTitle.contains('workout')) {
            description = 'Energizing workout beats to power your routine.';
          } else if (lowerTitle.contains('chill')) {
            description =
                'Relaxing and mellow tunes to unwind and recharge.';
          } else {
            description = null;
          }

          return CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return _PlaylistHeaderContent(
                        isMobile: constraints.maxWidth < 750,
                        constraints: constraints,
                        imageUrl: imageUrl,
                        fallbackUrl: playlistSummary.thumbnail.url,
                        title: playlistSummary.title,
                        meta: metaParts,
                        description: description,
                        pluginId: widget.pluginId,
                        playlistId: playlistSummary.id,
                        heroTag: widget.heroTag,
                        tracks: tracks,
                        isSaved: _isSaved,
                        onToggleSave: _toggleSaveState,
                        url: playlistSummary.url,
                      );
                    },
                  ),
                ),
              ),
              if ((status == DetailStatus.loaded ||
                      status == DetailStatus.loadingMore) &&
                  tracks.isNotEmpty)
                SliverPadding(
                  padding: EdgeInsets.only(
                      top: 24,
                      bottom: status == DetailStatus.loadingMore ? 0 : 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = tracks[index];
                        return AnimatedListItem(
                          index: index,
                          child: SongCardWidget(
                            song: song,
                            onOptionsTap: () => showMoreBottomSheet(
                                context, song,
                                showDelete: false, showSinglePlay: true),
                            onTap: () => context
                                .read<OrviaPlayerCubit>()
                                .orviaPlayer
                                .loadPlaylist(
                                  Playlist(
                                      tracks: tracks,
                                      title: playlistSummary.title),
                                  doPlay: true,
                                  idx: index,
                                ),
                          ),
                        );
                      },
                      childCount: tracks.length,
                      addRepaintBoundaries: true,
                    ),
                  ),
                )
              else if (status == DetailStatus.loaded && !_isSearchingFallback)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 80, bottom: 120),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(MingCute.music_2_line,
                              size: 40, color: Colors.white24),
                          const SizedBox(height: 12),
                          Text(
                            'No tracks available for ${playlistSummary.title}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              _contentBloc.add(SetActiveContentPlugin(
                                  pluginId: widget.pluginId));
                              _contentBloc.add(SearchContent(
                                query: playlistSummary.title,
                                filter: ContentSearchFilter.all,
                              ));
                            },
                            icon: const Icon(MingCute.search_2_line, size: 16),
                            label: const Text('Search for Tracks'),
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
                  ),
                )
              else if (status == DetailStatus.error && !_isSearchingFallback)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                        top: 60, bottom: 120, left: 24, right: 24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            (state.error?.contains('offline') ?? false)
                                ? MingCute.wifi_off_line
                                : MingCute.warning_line,
                            size: 44,
                            color: Default_Theme.primaryColor1
                                .withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            state.error ?? 'Failed to load playlist',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Default_Theme.primaryColor1
                                  .withValues(alpha: 0.7),
                            ).merge(Default_Theme.secondoryTextStyle),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              _contentBloc.add(LoadPlaylistDetails(
                                  pluginId: widget.pluginId,
                                  playlistId: widget.playlist.id));
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
                  ),
                )
              else
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 100, bottom: 120),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: Default_Theme.accentColor2)),
                  ),
                ),
              if (status == DetailStatus.loadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 20, bottom: 120),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: Default_Theme.accentColor2)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PlaylistHeaderContent extends StatelessWidget {
  final bool isMobile;
  final BoxConstraints constraints;
  final String imageUrl;
  final String fallbackUrl;
  final String title;
  final List<String> meta;
  final String? description;
  final String pluginId;
  final String playlistId;
  final String? heroTag;
  final List<Track> tracks;
  final bool isSaved;
  final VoidCallback onToggleSave;
  final String? url;

  const _PlaylistHeaderContent({
    required this.isMobile,
    required this.constraints,
    required this.imageUrl,
    required this.fallbackUrl,
    required this.title,
    required this.meta,
    required this.description,
    required this.pluginId,
    required this.playlistId,
    this.heroTag,
    required this.tracks,
    required this.isSaved,
    required this.onToggleSave,
    this.url,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildCover(),
            const SizedBox(height: 24),
            _buildInfo(isCentered: true),
            const SizedBox(height: 24),
            _buildActions(context, isCentered: true),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildCover(),
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

  Widget _buildCover() {
    final cover = RepaintBoundary(
      child: Container(
        height: 260,
        constraints: BoxConstraints(
            maxWidth: isMobile
                ? constraints.maxWidth * 0.85
                : constraints.maxWidth * 0.40),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 40,
                offset: const Offset(0, 20)),
            BoxShadow(
                color: Colors.white.withValues(alpha: 0.1),
                blurRadius: 1,
                offset: const Offset(0, -1)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox.square(
            child: LoadImageCached(
                imageUrl: imageUrl,
                fallbackUrl: fallbackUrl,
                fit: BoxFit.cover),
          ),
        ),
      ),
    );

    return heroTag == null ? cover : Hero(tag: heroTag!, child: cover);
  }

  Widget _buildInfo({required bool isCentered}) {
    return Column(
      crossAxisAlignment:
          isCentered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: isCentered ? TextAlign.center : TextAlign.left,
          style: const TextStyle(
            color: Default_Theme.primaryColor1,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.2,
          ).merge(Default_Theme.secondoryTextStyleMedium),
        ),
        const SizedBox(height: 10),
        if (meta.isNotEmpty)
          Text(
            meta.join(' • '),
            textAlign: isCentered ? TextAlign.center : TextAlign.left,
            style: TextStyle(
                    color: Default_Theme.primaryColor1.withValues(alpha: 0.7),
                    fontSize: 15,
                    fontWeight: FontWeight.w600)
                .merge(Default_Theme.secondoryTextStyle),
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
                    height: 1.4)
                .merge(Default_Theme.secondoryTextStyle),
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
              alignment: isCentered ? WrapAlignment.center : WrapAlignment.start,
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _PremiumPlayButton(
                  isEmpty: tracks.isEmpty,
                  isPlaying: isThisQueue && isPlaying,
                  onTap: () {
                    if (isThisQueue) {
                      if (isPlaying) {
                        player.pause();
                      } else {
                        player.play();
                      }
                    } else {
                      player.loadPlaylist(
                        Playlist(tracks: tracks, title: title),
                        doPlay: true,
                        idx: 0,
                      );
                    }
                  },
                ),
                _PremiumCircularButton(
                  icon: MingCute.shuffle_line,
                  isActive: false,
                  tooltip: 'Shuffle Play',
                  onTap: tracks.isEmpty
                      ? () {}
                      : () {
                          player.loadPlaylist(
                            Playlist(tracks: tracks, title: title),
                            doPlay: true,
                            shuffling: true,
                          );
                        },
                ),
                _PremiumCircularButton(
                  icon: MingCute.playlist_2_line,
                  isActive: false,
                  tooltip: 'Add to Up Next',
                  onTap: tracks.isEmpty
                      ? () {}
                      : () {
                          player.addQueueTracks(tracks, atLast: false);
                          SnackbarService.showMessage(
                              'Added ${tracks.length} track${tracks.length == 1 ? '' : 's'} to Up Next');
                        },
                ),
                _PremiumCircularButton(
                  icon: isSaved
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  isActive: isSaved,
                  tooltip: isSaved ? 'Remove from Library' : 'Save to Library',
                  onTap: onToggleSave,
                ),
                if (url != null)
                  _PremiumCircularButton(
                    icon: MingCute.external_link_line,
                    isActive: false,
                    tooltip: 'Open Original Link',
                    onTap: () {
                      SnackbarService.showMessage(
                          'Opening original playlist page.');
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

class _PremiumPlayButton extends StatelessWidget {
  final bool isEmpty;
  final bool isPlaying;
  final VoidCallback onTap;

  const _PremiumPlayButton({
    required this.isEmpty,
    this.isPlaying = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEmpty ? null : onTap,
        borderRadius: BorderRadius.circular(30),
        splashColor: Default_Theme.accentColor2.withValues(alpha: 0.2),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: Default_Theme.accentColor2.withValues(alpha: 0.15),
            border: Border.all(color: Default_Theme.accentColor2, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPlaying ? MingCute.pause_fill : MingCute.play_fill,
                size: 20,
                color: Default_Theme.accentColor2,
              ),
              const SizedBox(width: 8),
              Text(
                isPlaying ? 'Pause' : 'Play',
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
    );
  }
}

class _PremiumCircularButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final String tooltip;
  final VoidCallback onTap;

  const _PremiumCircularButton({
    required this.icon,
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
            child: Center(
              child: Icon(icon,
                  color: isActive
                      ? Default_Theme.accentColor2
                      : Default_Theme.primaryColor1,
                  size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

/// Checks if a fetched playlist title indicates a generic/colliding user playlist
/// (such as public user playlist collisions on JioSaavn).
bool isSuspiciousPlaylistTitle(String? title) {
  if (title == null) return true;
  final trimmed = title.trim().toLowerCase();
  return trimmed.isEmpty || trimmed == 'amit' || trimmed == 'starred songs';
}

/// Sanitizes a playlist owner string, falling back to a curated label if the
/// owner indicates a user account collision or generic membership.
String sanitizePlaylistOwner(String? rawOwner,
    {String fallback = 'Curated Collection'}) {
  final trimmed = rawOwner?.trim() ?? '';
  if (trimmed.isEmpty ||
      trimmed.toLowerCase() == 'amit' ||
      trimmed.toLowerCase() == 'member') {
    return fallback;
  }
  return trimmed;
}

