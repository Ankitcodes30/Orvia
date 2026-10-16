import 'package:Orvia/blocs/media_player/orvia_player_cubit.dart';
import 'package:Orvia/core/di/service_locator.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/services/discovery/discovery_context_service.dart';
import 'package:Orvia/src/rust/api/plugin/commands.dart';
import 'package:Orvia/utils/load_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

/// Section displaying location-aware and regional music trends.
/// Supports non-blocking permission handling with India-wide fallback.
class WhatsHotNearYouSection extends StatefulWidget {
  final String pluginId;

  const WhatsHotNearYouSection({super.key, required this.pluginId});

  @override
  State<WhatsHotNearYouSection> createState() => _WhatsHotNearYouSectionState();
}

class _WhatsHotNearYouSectionState extends State<WhatsHotNearYouSection> {
  final List<Track> _tracks = [];
  bool _isLoading = true;
  String _currentRegion = DiscoveryContextService.currentRegionLabel;

  @override
  void initState() {
    super.initState();
    _fetchRegionalTracks();
  }

  Future<void> _fetchRegionalTracks() async {
    setState(() => _isLoading = true);

    try {
      final daypart = DiscoveryContextService.getCurrentDaypart();
      final query = DiscoveryContextService.getDaypartQuery(daypart);

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
          setState(() {
            _tracks
              ..clear()
              ..addAll(deduplicated.take(15));
            _isLoading = false;
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
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onLocationTap() async {
    final updated = await DiscoveryContextService.checkOrRequestLocationRegion();
    if (mounted && updated != _currentRegion) {
      setState(() => _currentRegion = updated);
      _fetchRegionalTracks();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading && _tracks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Text(
                "What's Hot Near You",
                style: Default_Theme.primaryTextStyle.merge(
                  const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Default_Theme.primaryColor1,
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _onLocationTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Default_Theme.accentColor2.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Default_Theme.accentColor2.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(MingCute.location_fill, size: 12, color: Default_Theme.accentColor2),
                      const SizedBox(width: 4),
                      Text(
                        _currentRegion,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Default_Theme.accentColor2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 195,
          child: _isLoading
              ? const Center(
                  child: SizedBox(
                    height: 30,
                    width: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Default_Theme.accentColor2,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _tracks.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final track = _tracks[index];
                    final imgUrl = track.thumbnail.urlHigh ??
                        (track.thumbnail.url.isNotEmpty
                            ? track.thumbnail.url
                            : (track.thumbnail.urlLow ?? ''));
                    final artistName = track.artists.isNotEmpty
                        ? track.artists.first.name
                        : '';

                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        context.read<OrviaPlayerCubit>().orviaPlayer.loadPlaylist(
                              Playlist(
                                tracks: _tracks,
                                title: "What's Hot Near You",
                              ),
                              idx: index,
                              doPlay: true,
                            );
                      },
                      child: SizedBox(
                        width: 130,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: AspectRatio(
                                aspectRatio: 1.0,
                                child: LoadImageCached(
                                  imageUrl: imgUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Default_Theme.primaryColor1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Default_Theme.primaryColor1.withValues(alpha: 0.6),
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
