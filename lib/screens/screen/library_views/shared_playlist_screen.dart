import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

import 'package:Orvia/blocs/media_player/orvia_player_cubit.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/screens/widgets/more_bottom_sheet.dart';
import 'package:Orvia/screens/widgets/snackbar.dart';
import 'package:Orvia/screens/widgets/song_tile.dart';
import 'package:Orvia/services/db/dao/playlist_dao.dart';
import 'package:Orvia/services/db/dao/track_dao.dart';
import 'package:Orvia/services/db/db_provider.dart';
import 'package:Orvia/utils/load_image.dart';

class SharedPlaylistScreen extends StatefulWidget {
  final Playlist playlist;

  const SharedPlaylistScreen({
    super.key,
    required this.playlist,
  });

  @override
  State<SharedPlaylistScreen> createState() => _SharedPlaylistScreenState();
}

class _SharedPlaylistScreenState extends State<SharedPlaylistScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isSaved = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _checkSavedState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkSavedState() async {
    try {
      if (!DBProvider.isInitialized) return;
      final dao = PlaylistDAO(DBProvider.db, TrackDAO(DBProvider.db));
      final saved = await dao.isPlaylistSavedWithTracks(
        widget.playlist.title,
        widget.playlist.tracks,
      );
      if (mounted) {
        setState(() => _isSaved = saved);
      }
    } catch (_) {}
  }

  Future<void> _savePlaylist() async {
    if (_isSaving) return;
    if (_isSaved) {
      SnackbarService.showMessage('"${widget.playlist.title}" is already in your Library');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final dao = PlaylistDAO(DBProvider.db, TrackDAO(DBProvider.db));
      final result = await dao.saveSharedPlaylist(widget.playlist);

      if (!mounted) return;

      if (result != null) {
        setState(() => _isSaved = true);

        if (result.alreadyExisted) {
          SnackbarService.showMessage('"${widget.playlist.title}" is already in your Library');
        } else {
          SnackbarService.showMessage('Saved "${widget.playlist.title}" to your Library!');
        }
      } else {
        SnackbarService.showMessage('Could not save playlist. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        SnackbarService.showMessage('Failed to save playlist: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _playAll({bool shuffle = false}) {
    if (widget.playlist.tracks.isEmpty) return;
    final player = context.read<OrviaPlayerCubit>().orviaPlayer;
    player.loadPlaylist(
      widget.playlist,
      doPlay: true,
      shuffling: shuffle,
      idx: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final artworkUrl = widget.playlist.thumbnail?.url ??
        (widget.playlist.tracks.isNotEmpty
            ? widget.playlist.tracks.first.thumbnail.url
            : '');

    return Scaffold(
      backgroundColor: Default_Theme.themeColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
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
                  color: Default_Theme.themeColor.withValues(alpha: 0.6),
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
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred Background Cover
          if (artworkUrl.isNotEmpty)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                child: LoadImageCached(
                  imageUrl: artworkUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Default_Theme.themeColor.withValues(alpha: 0.7),
                  Default_Theme.themeColor.withValues(alpha: 0.95),
                  Default_Theme.themeColor,
                ],
              ),
            ),
          ),

          // Scrollable Content
          SafeArea(
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Artwork
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: artworkUrl.isNotEmpty
                                ? LoadImageCached(
                                    imageUrl: artworkUrl,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: Default_Theme.accentColor2
                                        .withValues(alpha: 0.2),
                                    child: const Icon(
                                      MingCute.playlist_line,
                                      size: 64,
                                      color: Default_Theme.accentColor2,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Default_Theme.accentColor2
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Default_Theme.accentColor2
                                    .withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'SHARED PLAYLIST',
                            style: TextStyle(
                              color: Default_Theme.accentColor2,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Title
                        Text(
                          widget.playlist.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Subtitle
                        Text(
                          '${widget.playlist.tracks.length} ${widget.playlist.tracks.length == 1 ? 'song' : 'songs'}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (widget.playlist.description != null &&
                            widget.playlist.description!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.playlist.description!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Action Buttons: Play All + Shuffle + Save This Playlist
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Play All
                            ElevatedButton.icon(
                              onPressed: widget.playlist.tracks.isEmpty
                                  ? null
                                  : () => _playAll(shuffle: false),
                              icon: const Icon(Icons.play_arrow_rounded, size: 22),
                              label: const Text('Play All'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Default_Theme.accentColor2,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),

                            // Shuffle
                            OutlinedButton.icon(
                              onPressed: widget.playlist.tracks.isEmpty
                                  ? null
                                  : () => _playAll(shuffle: true),
                              icon: const Icon(MingCute.shuffle_line, size: 18),
                              label: const Text('Shuffle'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),

                            // Save This Playlist
                            ElevatedButton.icon(
                              onPressed: _isSaving ? null : _savePlaylist,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : Icon(
                                      _isSaved
                                          ? Icons.check_circle_rounded
                                          : Icons.bookmark_add_outlined,
                                      size: 18,
                                      color: _isSaved ? Colors.greenAccent : Colors.white,
                                    ),
                              label: Text(
                                _isSaved ? 'Saved in Library' : 'Save This Playlist',
                                style: TextStyle(
                                  color: _isSaved ? Colors.greenAccent : Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isSaved
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.12),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: _isSaved
                                        ? Colors.greenAccent.withValues(alpha: 0.4)
                                        : Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Track List Header
                if (widget.playlist.tracks.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Row(
                        children: [
                          Text(
                            'TRACKS',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Tap track to play',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Track items
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 120),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final track = widget.playlist.tracks[index];
                          return SongCardWidget(
                            song: track,
                            index: index,
                            showPlayBtn: true,
                            onTap: () {
                              final player = context
                                  .read<OrviaPlayerCubit>()
                                  .orviaPlayer;
                              player.loadPlaylist(
                                widget.playlist,
                                doPlay: true,
                                idx: index,
                              );
                            },
                            onOptionsTap: () {
                              showMoreBottomSheet(context, track);
                            },
                          );
                        },
                        childCount: widget.playlist.tracks.length,
                      ),
                    ),
                  ),
                ] else
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            MingCute.playlist_line,
                            size: 48,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'This shared playlist is empty.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
