import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

import 'package:Orvia/blocs/media_player/orvia_player_cubit.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/screens/screen/library_views/cubit/current_playlist_cubit.dart';
import 'package:Orvia/screens/screen/library_views/more_opts_sheet.dart';
import 'package:Orvia/blocs/downloader/cubit/downloader_cubit.dart';
import 'package:Orvia/blocs/library/cubit/library_items_cubit.dart';
import 'package:Orvia/screens/widgets/multi_select_bar.dart';
import 'package:Orvia/screens/widgets/more_bottom_sheet.dart';
import 'package:Orvia/screens/widgets/bulk_download_sheet.dart';
import 'package:Orvia/screens/widgets/confirmation_dialog.dart';
import 'package:Orvia/screens/widgets/animated_list_item.dart';
import 'package:Orvia/screens/widgets/play_pause_widget.dart';
import 'package:Orvia/screens/widgets/sign_board_widget.dart';
import 'package:Orvia/screens/widgets/snackbar.dart';
import 'package:Orvia/screens/widgets/song_tile.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/services/catalogue/creators_choice_service.dart';
import 'package:Orvia/utils/load_image.dart';
import 'package:Orvia/l10n/app_localizations.dart';

part 'playlist_info_dialog.dart';

class PlaylistView extends StatefulWidget {
  final String? initialPlaylistName;

  const PlaylistView({super.key, this.initialPlaylistName});

  @override
  State<PlaylistView> createState() => _PlaylistViewState();
}

class _PlaylistViewState extends State<PlaylistView> {
  late final ScrollController _scrollController;
  bool _didTriggerInitialLoad = false;
  String? _targetPlaylistName;

  // Multi-Select Mode
  bool _isMultiSelect = false;
  final Set<String> _selectedTrackIds = {};

  void _exitMultiSelect() {
    setState(() {
      _isMultiSelect = false;
      _selectedTrackIds.clear();
    });
  }

  void _toggleSelectAll(List<Track> tracks) {
    setState(() {
      if (_selectedTrackIds.length == tracks.length) {
        _selectedTrackIds.clear();
      } else {
        _selectedTrackIds.addAll(tracks.map((t) => t.id));
      }
    });
  }

  Future<void> _handleMultiLike(List<Track> tracks) async {
    final selected = tracks.where((t) => _selectedTrackIds.contains(t.id)).toList();
    if (selected.isEmpty) return;
    await context.read<LibraryItemsCubit>().likeTracks(selected);
    _exitMultiSelect();
  }

  Future<void> _handleMultiDownload(List<Track> tracks) async {
    final selected = tracks.where((t) => _selectedTrackIds.contains(t.id)).toList();
    if (selected.isEmpty) return;
    final downloader = context.read<DownloaderCubit>();
    int queued = 0;
    for (final t in selected) {
      if (!downloader.isDownloaded(t.id)) {
        await downloader.downloadSong(t, showSnackbar: false);
        queued++;
      }
    }
    SnackbarService.showMessage('Added $queued song${queued == 1 ? '' : 's'} to download queue');
    _exitMultiSelect();
  }

  Future<void> _handleMultiRemoveFromPlaylist(
      BuildContext context, CurrentPlaylistState state) async {
    if (CreatorsChoiceService.isCreatorsChoice(state.playlist.title)) return;
    final count = _selectedTrackIds.length;
    if (count == 0) return;

    final confirmed = await showConfirmDestructiveDialog(
      context,
      title: 'Remove $count Songs from Playlist?',
      message: 'Remove $count songs from "${state.playlist.title}"?',
      confirmLabel: 'Remove',
    );
    if (confirmed && mounted) {
      final cubit = context.read<CurrentPlaylistCubit>();
      final selected = state.playlist.tracks
          .where((t) => _selectedTrackIds.contains(t.id))
          .toList();
      for (final t in selected) {
        cubit.removeTrack(t);
      }
      SnackbarService.showMessage(
          'Removed $count song${count == 1 ? '' : 's'} from "${state.playlist.title}"');
      _exitMultiSelect();
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);

    if (widget.initialPlaylistName != null &&
        widget.initialPlaylistName!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startInitialLoad(widget.initialPlaylistName!);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didTriggerInitialLoad) return;

    final playlistName = _targetPlaylistName ??
        widget.initialPlaylistName ??
        context.read<CurrentPlaylistCubit>().currentPlaylistName;
    if (playlistName == null || playlistName.trim().isEmpty) return;

    _didTriggerInitialLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startInitialLoad(playlistName);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 500) {
      context.read<CurrentPlaylistCubit>().loadMoreTracks();
    }
  }

  Future<void> _startInitialLoad(String playlistName) async {
    if (!mounted) return;
    _targetPlaylistName = playlistName;
    final cubit = context.read<CurrentPlaylistCubit>();

    await cubit.openPlaylist(playlistName, deferFirstPage: true);
    if (!mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    await cubit.loadMoreTracks();
    if (mounted) {
      setState(() {
        _targetPlaylistName = null;
      });
    }
  }

  Future<void> _playFromPlaylist(
      BuildContext context, CurrentPlaylistState state,
      {int? index, bool shuffle = false}) async {
    final fullPlaylist =
        await context.read<CurrentPlaylistCubit>().ensureAllTracksLoaded();
    if (!mounted || fullPlaylist.tracks.isEmpty) return;

    context.read<OrviaPlayerCubit>().orviaPlayer.loadPlaylist(
          Playlist(tracks: fullPlaylist.tracks, title: fullPlaylist.title),
          idx: index ?? 0,
          doPlay: true,
          shuffling: shuffle,
        );
  }

  List<Color> _getOptimizedPalette(BuildContext context) {
    final pallete =
        context.read<CurrentPlaylistCubit>().getCurrentPlaylistPallete();
    Color fgColor = pallete?.lightVibrantColor?.color ?? Colors.white;
    Color bgColor = pallete?.dominantColor?.color ??
        pallete?.darkMutedColor?.color ??
        Default_Theme.themeColor;

    if (bgColor.computeLuminance() / fgColor.computeLuminance() > 0.05) {
      fgColor = HSLColor.fromColor(fgColor)
          .withLightness(
              (HSLColor.fromColor(fgColor).lightness + 0.1).clamp(0.0, 1.0))
          .toColor();
      bgColor = HSLColor.fromColor(bgColor)
          .withLightness(
              (HSLColor.fromColor(bgColor).lightness - 0.1).clamp(0.0, 1.0))
          .toColor();
    }
    return [fgColor, bgColor];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Default_Theme.themeColor,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      bottomNavigationBar: _isMultiSelect
          ? BlocBuilder<CurrentPlaylistCubit, CurrentPlaylistState>(
              builder: (context, state) {
                final isCreatorsChoice =
                    CreatorsChoiceService.isCreatorsChoice(state.playlist.title);
                return MultiSelectActionBar(
                  selectedCount: _selectedTrackIds.length,
                  totalCount: state.playlist.tracks.length,
                  onToggleSelectAll: () =>
                      _toggleSelectAll(state.playlist.tracks),
                  onClose: _exitMultiSelect,
                  contextType: isCreatorsChoice
                      ? MultiSelectContext.discovery
                      : MultiSelectContext.userPlaylist,
                  onLike: () => _handleMultiLike(state.playlist.tracks),
                  onDownload: () => _handleMultiDownload(state.playlist.tracks),
                  onRemoveFromPlaylist: isCreatorsChoice
                      ? null
                      : () => _handleMultiRemoveFromPlaylist(context, state),
                );
              },
            )
          : null,
      body: BlocBuilder<CurrentPlaylistCubit, CurrentPlaylistState>(
        builder: (context, state) {
          final waitingForTarget = _targetPlaylistName != null &&
              state.playlist.title != _targetPlaylistName;

          if (waitingForTarget ||
              state.status == CurrentPlaylistLoadStatus.initial ||
              state.status == CurrentPlaylistLoadStatus.loading) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Default_Theme.accentColor2));
          }

          if (state.status == CurrentPlaylistLoadStatus.error) {
            return Center(
                child: SignBoardWidget(
                    message: state.errorMessage ?? 'Failed to load playlist',
                    icon: MingCute.alert_line));
          }

          final colors = _getOptimizedPalette(context);
          final fgColor = colors[0];
          final bgColor = colors[1];
          final tracks = state.playlist.tracks;
          final playlistThumb = state.playlist.thumbnail?.url;
          final imageUrl = (playlistThumb != null && playlistThumb.isNotEmpty)
              ? playlistThumb
              : (tracks.isNotEmpty
                  ? (tracks.first.thumbnail.urlHigh ?? tracks.first.thumbnail.url)
                  : '');

          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 850;
              return Stack(
                fit: StackFit.expand,
                children: [
                  _buildAmbientBackground(imageUrl, bgColor, isMobile),
                  if (isMobile)
                    _buildMobileLayout(
                        state, fgColor, bgColor, imageUrl, l10n, constraints)
                  else
                    _buildDesktopLayout(
                        state, fgColor, bgColor, imageUrl, l10n, constraints),
                ],
              );
            },
          );
        },
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
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 20),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  Widget _buildAmbientBackground(
      String imageUrl, Color dominantColor, bool isMobile) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Default_Theme.themeColor),
            Positioned(
              top: isMobile ? -100 : -200,
              left: isMobile ? -50 : -200,
              width: 800,
              height: 800,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      dominantColor.withValues(alpha: 0.45),
                      Colors.transparent
                    ],
                  ),
                ),
              ),
            ),
            if (imageUrl.isNotEmpty)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.35,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                    child:
                        LoadImageCached(imageUrl: imageUrl, fit: BoxFit.cover),
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Default_Theme.themeColor.withValues(alpha: 0.1),
                    Default_Theme.themeColor.withValues(alpha: 0.85),
                    Default_Theme.themeColor,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Pro-Desktop Layout (Perfectly Centered Left Panel) ───

  Widget _buildDesktopLayout(
      CurrentPlaylistState state,
      Color fgColor,
      Color bgColor,
      String imageUrl,
      AppLocalizations l10n,
      BoxConstraints constraints) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // FIXED LEFT PANEL: Centered content, elegant flex scaling
        SizedBox(
          width: math.max(340, constraints.maxWidth * 0.35),
          child: Padding(
            // Optically balanced padding so it sits perfectly in the center of its space
            padding: const EdgeInsets.fromLTRB(40, 90, 20, 40),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.center, // Centered alignment
              children: [
                const Spacer(flex: 1), // Top breathing room

                // Intelligently scaling cover art
                Flexible(
                  flex: 10,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: _buildIntelligentCover(imageUrl, bgColor),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Meta Info (Centered)
                _buildInfo(state, l10n, isCentered: true),

                const SizedBox(height: 24),

                // Single-Line Forced Actions (Centered)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child:
                      _buildActions(state, fgColor, bgColor, isCentered: true),
                ),

                const Spacer(flex: 2), // Bottom breathing room
              ],
            ),
          ),
        ),

        // SCROLLABLE RIGHT PANEL: The track list
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(
                20, 90, 40, 40), // Matches left panel gap
            decoration: BoxDecoration(
              color: Default_Theme.themeColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 40,
                    offset: const Offset(0, 15)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  if (state.playlist.tracks.isEmpty && !state.isLoadingMore)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                          child: SignBoardWidget(
                              message: l10n.playlistEmptyState,
                              icon: MingCute.playlist_line)),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 24, horizontal: 16),
                      sliver: _buildTrackList(state),
                    ),
                  if (state.isLoadingMore || state.hasMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: Default_Theme.accentColor2)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Mobile Layout (Scrolling Canvas) ───

  Widget _buildMobileLayout(
      CurrentPlaylistState state,
      Color fgColor,
      Color bgColor,
      String imageUrl,
      AppLocalizations l10n,
      BoxConstraints constraints) {
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 100, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: constraints.maxWidth * 0.65,
                  height: constraints.maxWidth * 0.65,
                  child: _buildIntelligentCover(imageUrl, bgColor),
                ),
                const SizedBox(height: 32),
                _buildInfo(state, l10n, isCentered: true),
                const SizedBox(height: 28),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child:
                      _buildActions(state, fgColor, bgColor, isCentered: true),
                ),
              ],
            ),
          ),
        ),
        if (state.playlist.tracks.isEmpty && !state.isLoadingMore)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
                child: SignBoardWidget(
                    message: l10n.playlistEmptyState,
                    icon: MingCute.playlist_line)),
          )
        else
          SliverPadding(
            padding: EdgeInsets.only(bottom: state.isLoadingMore ? 0 : 120),
            sliver: _buildTrackList(state),
          ),
        if (state.isLoadingMore || state.hasMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: CircularProgressIndicator(
                      color: Default_Theme.accentColor2)),
            ),
          ),
      ],
    );
  }

  Widget _buildIntelligentCover(String imageUrl, Color dominantColor) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.black.withValues(alpha: 0.2),
          boxShadow: [
            BoxShadow(
                color: dominantColor.withValues(alpha: 0.35),
                blurRadius: 60,
                offset: const Offset(0, 20)),
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10)),
            BoxShadow(
                color: Colors.white.withValues(alpha: 0.1),
                blurRadius: 1,
                offset: const Offset(0, -1)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: imageUrl.isEmpty
              ? FractionallySizedBox(
                  widthFactor: 0.3,
                  heightFactor: 0.3,
                  child: Icon(MingCute.music_2_line,
                      color: Colors.white.withValues(alpha: 0.3)),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                      child: LoadImageCached(
                          imageUrl: imageUrl, fit: BoxFit.cover),
                    ),
                    Container(color: Colors.black.withValues(alpha: 0.3)),
                    LoadImageCached(imageUrl: imageUrl, fit: BoxFit.contain),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildInfo(CurrentPlaylistState state, AppLocalizations l10n,
      {required bool isCentered}) {
    final isCreatorsChoice =
        CreatorsChoiceService.isCreatorsChoice(state.playlist.title);
    final creatorName = isCreatorsChoice
        ? 'A.K.'
        : (state.playlist.artists?.map((a) => a.name).join(', ') ??
            l10n.playlistYou);
    final creatorText = l10n.playlistByCreator(creatorName);

    return Column(
      crossAxisAlignment:
          isCentered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          state.playlist.title,
          textAlign: isCentered ? TextAlign.center : TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: 36,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.playlistSongCount(state.totalTracks),
          textAlign: isCentered ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          creatorText,
          textAlign: isCentered ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActions(CurrentPlaylistState state, Color fgColor, Color bgColor,
      {required bool isCentered}) {
    final isEmpty = state.playlist.tracks.isEmpty;
    final l10n = AppLocalizations.of(context)!;

    return RepaintBoundary(
      child: Row(
        mainAxisAlignment:
            isCentered ? MainAxisAlignment.center : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, // Hug contents tightly
        children: [
          _buildActionIcon(
              MingCute.shuffle_line,
              l10n.playlistShuffle,
              isEmpty
                  ? null
                  : () => _playFromPlaylist(context, state, shuffle: true)),
          const SizedBox(width: 12),

          Builder(builder: (ctx) {
            final downloaded = ctx.watch<DownloaderCubit>().state.downloaded;
            final allDownloaded = !isEmpty &&
                state.playlist.tracks
                    .every((s) => downloaded.any((d) => d.id == s.id));

            if (allDownloaded) {
              return Tooltip(
                message: l10n.playlistAvailableOffline,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          Default_Theme.accentColor2.withValues(alpha: 0.15)),
                  child: const Icon(Icons.offline_pin_rounded,
                      color: Default_Theme.accentColor2, size: 20),
                ),
              );
            }
            return _buildActionIcon(
                MingCute.download_2_fill,
                l10n.buttonDownload,
                isEmpty ? null : () => _handleDownload(context, state, l10n));
          }),

          const SizedBox(width: 12),

          // Big Center Play Button
          StreamBuilder<String>(
              stream:
                  context.watch<OrviaPlayerCubit>().orviaPlayer.queueTitle,
              builder: (context, snapshot) {
                final isCurrent =
                    snapshot.hasData && snapshot.data == state.playlist.title;
                return StreamBuilder<bool>(
                    stream: context
                        .read<OrviaPlayerCubit>()
                        .orviaPlayer
                        .engine
                        .playingStream,
                    builder: (context, playingSnapshot) {
                      final isPlaying =
                          isCurrent && (playingSnapshot.data ?? false);
                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Default_Theme.accentColor2
                                    .withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8)),
                          ],
                        ),
                        child: PlayPauseButton(
                          isPlaying: isPlaying,
                          size: 60,
                          onPlay: isEmpty
                              ? () {}
                              : () => isCurrent
                                  ? context
                                      .read<OrviaPlayerCubit>()
                                      .orviaPlayer
                                      .play()
                                  : _playFromPlaylist(context, state),
                          onPause: () => context
                              .read<OrviaPlayerCubit>()
                              .orviaPlayer
                              .pause(),
                        ),
                      );
                    });
              }),

          const SizedBox(width: 12),
          _buildActionIcon(
              MingCute.information_line,
              l10n.buttonInfo,
              () => showPlaylistInfo(context, state,
                  fgColor: fgColor, bgColor: bgColor)),

          const SizedBox(width: 12),
          _buildActionIcon(MingCute.more_2_line, l10n.buttonMore,
              () => showPlaylistOptsInrSheet(context, state.playlist)),
        ],
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, String tooltip, VoidCallback? onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          splashColor: Colors.white.withValues(alpha: 0.1),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          child: Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Icon(icon,
                color: Colors.white.withValues(alpha: 0.85), size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackList(CurrentPlaylistState state) {
    final tracks = state.playlist.tracks;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final track = tracks[index];
          final isSelected = _selectedTrackIds.contains(track.id);

          return AnimatedListItem(
            index: index,
            child: SongCardWidget(
              index: index + 1,
              key: ValueKey(track.id),
              song: track,
              showOptions: !_isMultiSelect,
              isSelectMode: _isMultiSelect,
              isSelected: isSelected,
              onSelectChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedTrackIds.add(track.id);
                  } else {
                    _selectedTrackIds.remove(track.id);
                    if (_selectedTrackIds.isEmpty) {
                      _isMultiSelect = false;
                    }
                  }
                });
              },
              onLongPress: () {
                setState(() {
                  _isMultiSelect = true;
                  _selectedTrackIds.add(track.id);
                });
              },
              onTap: () {
                if (_isMultiSelect) {
                  setState(() {
                    if (isSelected) {
                      _selectedTrackIds.remove(track.id);
                      if (_selectedTrackIds.isEmpty) {
                        _isMultiSelect = false;
                      }
                    } else {
                      _selectedTrackIds.add(track.id);
                    }
                  });
                  return;
                }
                _playFromPlaylist(context, state, index: index);
              },
              onOptionsTap: () => showMoreBottomSheet(
                context,
                track,
                onDelete: () => _removeTrack(context, track),
                showDelete: !CreatorsChoiceService.isCreatorsChoice(
                    state.playlist.title),
                showSinglePlay: true,
              ),
            ),
          );
        },
        childCount: tracks.length,
        addRepaintBoundaries: true,
      ),
    );
  }

  Future<void> _removeTrack(BuildContext context, Track track) async {
    final cubit = context.read<CurrentPlaylistCubit>();
    if (CreatorsChoiceService.isCreatorsChoice(cubit.state.playlist.title)) {
      return;
    }
    final confirmed = await showConfirmDestructiveDialog(
      context,
      title: 'Remove from Playlist?',
      message: 'Remove "${track.title}" from "${cubit.state.playlist.title}"?',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !context.mounted) return;

    final l10n = AppLocalizations.of(context)!;
    cubit.removeTrack(track);
    SnackbarService.showMessage(
        l10n.playlistRemovedTrack(track.title, cubit.state.playlist.title));
  }

  Future<void> _handleDownload(BuildContext context, CurrentPlaylistState state,
      AppLocalizations l10n) async {
    final items =
        (await context.read<CurrentPlaylistCubit>().ensureAllTracksLoaded())
            .tracks;
    if (items.isEmpty) return;

    final rawId = state.playlist.remotePlaylist?.id ??
        state.playlist.album?.id ??
        state.playlist.title.toLowerCase().replaceAll(' ', '_');
    final collectionId = 'playlist_$rawId';

    showBulkDownloadSheet(
      context: context,
      collectionId: collectionId,
      title: state.playlist.title,
      type: 'playlist',
      coverUrl: state.playlist.thumbnail?.url ??
          (items.isNotEmpty
              ? (items.first.thumbnail.urlHigh ?? items.first.thumbnail.url)
              : null),
      tracks: items,
    );
  }
}

