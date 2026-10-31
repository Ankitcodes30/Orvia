import 'dart:developer';
import 'dart:math' as math;

import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/plugins/utils/media_id.dart';
import 'package:Orvia/services/meta_resolver/cross_plugin_resolver.dart';
import 'package:Orvia/services/plugin/plugin_service.dart';
import 'package:Orvia/src/rust/api/plugin/commands.dart';

class ChartResolveResult {
  final Track resolvedTrack;
  final String resolverPluginId;

  /// Confidence in [0, 100] range (kept for backward compat with UI).
  final double confidence;

  /// Optional track list when an album or playlist chart item is resolved.
  final List<Track>? albumTracks;

  const ChartResolveResult({
    required this.resolvedTrack,
    required this.resolverPluginId,
    required this.confidence,
    this.albumTracks,
  });
}

class ChartItemResolver {
  final CrossPluginResolver _resolver;
  final PluginService? _pluginService;

  static const double _kMinViable = 45;
  static const double _kCorroborationBonus = 6.0;

  const ChartItemResolver({
    required CrossPluginResolver resolver,
    PluginService? pluginService,
  })  : _resolver = resolver,
        _pluginService = pluginService;

  factory ChartItemResolver.create(PluginService pluginService) =>
      ChartItemResolver(
        resolver: CrossPluginResolver(
          pluginService: pluginService,
          pluginTimeout: const Duration(seconds: 12),
          maxResultsPerQuery: 15,
        ),
        pluginService: pluginService,
      );

  String fallbackQuery(ChartItem chartItem) {
    final target = _targetFromChartItem(chartItem);
    if (target != null) {
      return _resolver.joinNonEmpty([target.title, target.allArtists]);
    }
    return _rawFallback(chartItem);
  }

  bool isStrongTrackMatch({
    required ChartItem chartItem,
    required Track resolvedTrack,
  }) {
    return switch (chartItem.item) {
      MediaItem_Track(:final field0) =>
        _resolver.isStrongMatch(TrackMatchTarget.fromTrack(field0), resolvedTrack),
      MediaItem_Album(:final field0) =>
        _isStrongAlbumTrackMatch(field0, resolvedTrack),
      _ => false,
    };
  }

  static final _kCompilationPatterns = RegExp(
    r'\b(various artists|soundtrack|original soundtrack|ost|motion picture|original motion picture soundtrack)\b',
    caseSensitive: false,
  );

  static bool _isCompilation(List<ArtistSummary> artists, String title) {
    if (_kCompilationPatterns.hasMatch(title)) return true;
    for (final a in artists) {
      if (_kCompilationPatterns.hasMatch(a.name)) return true;
    }
    return false;
  }

  bool _isArtistCompatible(AlbumSummary target, AlbumSummary candidate) {
    if (target.artists.isEmpty) return true;
    if (_isCompilation(target.artists, target.title)) return true;
    if (_isCompilation(candidate.artists, candidate.title)) return true;

    // Check artist summary similarity (handles featured artists & group members)
    if (candidate.artists.isNotEmpty) {
      final artistSim =
          _resolver.artistSummarySimilarity(target.artists, candidate.artists);
      if (artistSim >= 0.25) return true;
    }

    // Check candidate subtitle (e.g. YTM puts "Album • Artist • Year" in subtitle)
    if (candidate.subtitle != null && candidate.subtitle!.isNotEmpty) {
      final subNorm = _resolver.normalized(candidate.subtitle);
      for (final a in target.artists) {
        final aNorm = _resolver.normalized(a.name);
        if (aNorm.isNotEmpty && subNorm.contains(aNorm)) return true;
      }
    }

    // Check candidate title for embedded target artist prefix/suffix (e.g. "Artist - Album")
    final candTitleNorm = _resolver.normalized(candidate.title);
    for (final a in target.artists) {
      final aNorm = _resolver.normalized(a.name);
      if (aNorm.isNotEmpty && candTitleNorm.contains(aNorm)) return true;
    }

    // If candidate explicitly provided artists and none matched, candidate is incompatible.
    if (candidate.artists.isNotEmpty) return false;

    // If candidate has no artists and no subtitle, allow only if candidate title is highly specific
    final titleSim = _resolver.blendedTextSimilarity(target.title, candidate.title);
    return titleSim >= 0.85;
  }

  bool _isStrongAlbumTrackMatch(AlbumSummary album, Track track) {
    if (_isCompilation(album.artists, album.title)) {
      if (track.album != null) {
        final albumScore =
            _resolver.blendedTextSimilarity(album.title, track.album!.title);
        if (albumScore >= 0.75) return true;
      }
      return _resolver.blendedTextSimilarity(album.title, track.title) >= 0.75;
    }

    final artistScore =
        _resolver.artistSummarySimilarity(album.artists, track.artists);
    // If target album specifies artists and it is not a compilation,
    // a non-matching artist (< 0.35) can NEVER be a strong match.
    if (album.artists.isNotEmpty && artistScore < 0.35) {
      return false;
    }

    final trackAlbum = track.album?.title ?? '';
    final albumScore = trackAlbum.isNotEmpty
        ? _resolver.blendedTextSimilarity(album.title, trackAlbum)
        : 0.0;

    if (albumScore >= 0.75) return true;

    final titleScore =
        _resolver.blendedTextSimilarity(album.title, track.title);
    return titleScore >= 0.75 && artistScore >= 0.50;
  }

  Future<ChartResolveResult?> resolve({
    required ChartItem chartItem,
    required Iterable<String> resolverPluginIds,
  }) async {
    final pluginIds = resolverPluginIds.toList(growable: false);
    if (pluginIds.isEmpty) return null;

    // Track-type items use the shared resolver directly.
    final target = _targetFromChartItem(chartItem);
    if (target != null) {
      return _resolveTrackItem(target, pluginIds);
    }

    // Non-track types use searchMedia with custom scoring.
    return _resolveNonTrackItem(chartItem, pluginIds);
  }

  // ── Track resolution (Phase 1 → 2 → 3) ─────────────────────────────────

  Future<ChartResolveResult?> _resolveTrackItem(
    TrackMatchTarget target,
    List<String> pluginIds,
  ) async {
    // Phase 1: sequential, typed filter, high early-accept bar.
    var candidates = await _resolver.resolveTrack(
      target: target,
      pluginIds: pluginIds,
      sequential: true,
      earlyAcceptThreshold: 0.94,
      minConfidence: _kMinViable / 100,
      limit: 30,
    );

    // Phase 2: if nothing viable, broaden with ContentSearchFilter.all.
    final best1 = candidates.isEmpty ? 0.0 : candidates.first.confidence;
    if (best1 < _kMinViable / 100) {
      log('Phase 1 best ${(best1 * 100).toStringAsFixed(1)}%. Broadening.',
          name: 'ChartItemResolver');

      final fallback =
          _resolver.joinNonEmpty([target.title, target.allArtists]);
      if (fallback.isNotEmpty) {
        final phase2 = await _resolver.resolveTrack(
          target: target,
          pluginIds: pluginIds,
          sequential: false,
          minConfidence: _kMinViable / 100,
          queries: [fallback],
          searchFilter: ContentSearchFilter.all,
          limit: 30,
        );
        candidates = _mergeLists(candidates, phase2);
      }
    }

    // Phase 3: cross-plugin corroboration.
    _applyCorroboration(candidates);

    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    if (candidates.isEmpty) return null;

    final winner = candidates.first;
    final conf100 = winner.confidence * 100;
    if (conf100 < _kMinViable) {
      log('No viable: best ${conf100.toStringAsFixed(1)}%',
          name: 'ChartItemResolver');
      return null;
    }

    log('Resolved ${conf100.toStringAsFixed(1)}% from ${winner.pluginId}',
        name: 'ChartItemResolver');
    return ChartResolveResult(
      resolvedTrack: winner.track,
      resolverPluginId: winner.pluginId,
      confidence: conf100,
    );
  }

  // ── Non-track resolution ────────────────────────────────────────────────

  Future<ChartResolveResult?> _resolveNonTrackItem(
    ChartItem chartItem,
    List<String> pluginIds,
  ) async {
    final queries = _buildNonTrackQueries(chartItem);
    final filter = _filterFor(chartItem);
    if (queries.isEmpty) return null;

    final allResults = <_NonTrackScored>[];

    for (final pluginId in pluginIds) {
      try {
        final results = await _resolver.searchMedia(
          pluginId: pluginId,
          queries: queries,
          filter: filter,
        );
        for (final r in results) {
          if (!_compatibleType(chartItem.item, r.item)) continue;
          final score = _scoreNonTrack(chartItem.item, r.item, r.rank);
          if (score > 0) {
            allResults.add(_NonTrackScored(
              result: r,
              confidence: score,
            ));
          }
        }
      } catch (e) {
        log('Non-track search failed for $pluginId: $e',
            name: 'ChartItemResolver');
      }
    }

    // Broaden search to ContentSearchFilter.all if searching with album filter
    // yielded no viable matches (confidence >= _kMinViable / 100).
    if (chartItem.item is MediaItem_Album &&
        !allResults.any((r) => r.confidence >= _kMinViable / 100)) {
      for (final pluginId in pluginIds) {
        try {
          final results = await _resolver.searchMedia(
            pluginId: pluginId,
            queries: queries,
            filter: ContentSearchFilter.all,
          );
          for (final r in results) {
            if (!_compatibleType(chartItem.item, r.item)) continue;
            final score = _scoreNonTrack(chartItem.item, r.item, r.rank);
            if (score > 0) {
              allResults.add(_NonTrackScored(
                result: r,
                confidence: score,
              ));
            }
          }
        } catch (e) {
          log('Broadened non-track search failed for $pluginId: $e',
              name: 'ChartItemResolver');
        }
      }
    }

    if (allResults.isEmpty && chartItem.item is! MediaItem_Album) return null;
    allResults.sort((a, b) => b.confidence.compareTo(a.confidence));

    if (allResults.isNotEmpty) {
      final best = allResults.first;
      final conf100 = best.confidence * 100;

      if (best.result.item case MediaItem_Track(:final field0)) {
        if (conf100 >= _kMinViable) {
          return ChartResolveResult(
            resolvedTrack: field0,
            resolverPluginId: best.result.pluginId,
            confidence: conf100,
          );
        }
      }
    }

    final service = _pluginService;

    if (chartItem.item case MediaItem_Album(:final field0)) {
      if (service != null) {
        // Phase 1: Try to fetch the full album details across viable candidates in descending confidence order.
        final viableCandidates = allResults
            .where((r) =>
                r.result.item is MediaItem_Album &&
                (r.confidence * 100) >= 48.0 &&
                _isArtistCompatible(field0, (r.result.item as MediaItem_Album).field0))
            .toList();

        for (final candidate in viableCandidates) {
          final candAlbum =
              (candidate.result.item as MediaItem_Album).field0;
          final candConfidence = candidate.confidence * 100;
          final localId = localIdOf(candAlbum.id) ?? candAlbum.id;
          final idsToTry = [
            localId,
            if (candAlbum.id != localId) candAlbum.id,
          ];

          for (final albumId in idsToTry) {
            try {
              final response = await service.execute(
                pluginId: candidate.result.pluginId,
                request: PluginRequest.contentResolver(
                  ContentResolverCommand.getAlbumDetails(id: albumId),
                ),
              );
              final tracks = response.whenOrNull(
                albumDetails: (details) => details.tracks.items,
              );
              if (tracks != null && tracks.isNotEmpty) {
                final seenIds = <String>{};
                final sanitizedTracks = tracks.where((t) {
                  return t.id.trim().isNotEmpty &&
                      t.title.trim().isNotEmpty &&
                      seenIds.add(t.id);
                }).toList(growable: false);

                final titleSim = _resolver.blendedTextSimilarity(field0.title, candAlbum.title);
                final strongMatch = sanitizedTracks.isNotEmpty &&
                    _isStrongAlbumTrackMatch(field0, sanitizedTracks.first);

                if (sanitizedTracks.isNotEmpty &&
                    _isArtistCompatible(field0, candAlbum) &&
                    (candConfidence >= _kMinViable || strongMatch || titleSim >= 0.75)) {
                  log('Resolved album "${field0.title}" with ${sanitizedTracks.length} tracks from ${candidate.result.pluginId}',
                      name: 'ChartItemResolver');
                  return ChartResolveResult(
                    resolvedTrack: sanitizedTracks.first,
                    resolverPluginId: candidate.result.pluginId,
                    confidence: candConfidence,
                    albumTracks: sanitizedTracks,
                  );
                }
              }
            } catch (e) {
              log('Failed getAlbumDetails on ${candidate.result.pluginId} for id $albumId: $e',
                  name: 'ChartItemResolver');
            }
          }
        }

        // Phase 2: If direct album candidates failed, search track candidates for canonical album IDs.
        for (final pluginId in pluginIds) {
          try {
            final trackResults = await _resolver.searchMedia(
              pluginId: pluginId,
              queries: queries.take(3).toList(),
              filter: ContentSearchFilter.track,
            );

            for (final tr in trackResults) {
              if (tr.item case MediaItem_Track(:final field0)) {
                final candAlbum = field0.album;
                if (candAlbum != null && candAlbum.id.trim().isNotEmpty) {
                  final targetAlbumTitle =
                      chartItem.item.whenOrNull(album: (a) => a.title) ?? '';
                  final titleSim = _resolver.blendedTextSimilarity(
                    candAlbum.title,
                    targetAlbumTitle,
                  );
                  if (titleSim >= 0.68) {
                    final candLocalId =
                        localIdOf(candAlbum.id) ?? candAlbum.id;
                    final albumIdsToTry = [
                      candLocalId,
                      if (candAlbum.id != candLocalId) candAlbum.id,
                    ];
                    for (final albumId in albumIdsToTry) {
                      try {
                        final response = await service.execute(
                          pluginId: pluginId,
                          request: PluginRequest.contentResolver(
                            ContentResolverCommand.getAlbumDetails(
                                id: albumId),
                          ),
                        );
                        final tracks = response.whenOrNull(
                          albumDetails: (details) => details.tracks.items,
                        );
                        if (tracks != null && tracks.isNotEmpty) {
                          final seenIds = <String>{};
                          final sanitized = tracks.where((t) {
                            return t.id.trim().isNotEmpty &&
                                t.title.trim().isNotEmpty &&
                                seenIds.add(t.id);
                          }).toList(growable: false);
                          if (sanitized.isNotEmpty) {
                            log('Resolved album "$targetAlbumTitle" via track-derived album details with ${sanitized.length} tracks from $pluginId',
                                name: 'ChartItemResolver');
                            return ChartResolveResult(
                              resolvedTrack: sanitized.first,
                              resolverPluginId: pluginId,
                              confidence: 85.0,
                              albumTracks: sanitized,
                            );
                          }
                        }
                      } catch (_) {}
                    }
                  }
                }
              }
            }

            // Fallback: If getAlbumDetails couldn't be loaded, collect matching track items.
            final matchingTracks = <Track>[];
            final seenIds = <String>{};
            final targetAlbumTitle =
                chartItem.item.whenOrNull(album: (a) => a.title) ?? '';
            for (final tr in trackResults) {
              if (tr.item case MediaItem_Track(:final field0)) {
                final albumTitle = field0.album?.title ?? '';
                if (albumTitle.isNotEmpty &&
                    _resolver.blendedTextSimilarity(
                            albumTitle, targetAlbumTitle) >=
                        0.78) {
                  if (seenIds.add(field0.id)) {
                    matchingTracks.add(field0);
                  }
                }
              }
            }
            if (matchingTracks.length >= 2) {
              log('Resolved album "$targetAlbumTitle" via ${matchingTracks.length} matching track items from $pluginId',
                  name: 'ChartItemResolver');
              return ChartResolveResult(
                resolvedTrack: matchingTracks.first,
                resolverPluginId: pluginId,
                confidence: 75.0,
                albumTracks: matchingTracks,
              );
            }
          } catch (e) {
            log('Phase 2 track fallback failed for $pluginId: $e',
                name: 'ChartItemResolver');
          }
        }
      }

      // Preserve album queue semantics: do NOT return a single track with null albumTracks.
      log('Could not resolve tracklist for album ${field0.title}',
          name: 'ChartItemResolver');
      return null;
    }

    if (allResults.isNotEmpty) {
      final best = allResults.first;
      final conf100 = best.confidence * 100;

      if (best.result.item case MediaItem_Playlist(:final field0)) {
        if (service != null) {
          try {
            final localId = localIdOf(field0.id) ?? field0.id;
            final response = await service.execute(
              pluginId: best.result.pluginId,
              request: PluginRequest.contentResolver(
                ContentResolverCommand.getPlaylistDetails(id: localId),
              ),
            );
            final tracks = response.whenOrNull(
              playlistDetails: (details) => details.tracks.items,
            );
            if (tracks != null && tracks.isNotEmpty) {
              return ChartResolveResult(
                resolvedTrack: tracks.first,
                resolverPluginId: best.result.pluginId,
                confidence: conf100,
                albumTracks: tracks,
              );
            }
          } catch (e) {
            log('Failed to fetch playlist details from ${best.result.pluginId}: $e',
                name: 'ChartItemResolver');
          }
        }
      }

      if (best.result.item case MediaItem_Artist(:final field0)) {
        if (service != null) {
          try {
            final localId = localIdOf(field0.id) ?? field0.id;
            final response = await service.execute(
              pluginId: best.result.pluginId,
              request: PluginRequest.contentResolver(
                ContentResolverCommand.getArtistDetails(id: localId),
              ),
            );
            final tracks = response.whenOrNull(
              artistDetails: (details) => details.topTracks,
            );
            if (tracks != null && tracks.isNotEmpty) {
              return ChartResolveResult(
                resolvedTrack: tracks.first,
                resolverPluginId: best.result.pluginId,
                confidence: conf100,
                albumTracks: tracks,
              );
            }
          } catch (e) {
            log('Failed to fetch artist details from ${best.result.pluginId}: $e',
                name: 'ChartItemResolver');
          }
        }
      }
    }

    return null;
  }

  // ── Corroboration ───────────────────────────────────────────────────────

  void _applyCorroboration(List<ScoredTrackCandidate> candidates) {
    if (candidates.length < 2) return;
    final fps = <String, Set<String>>{};
    for (final c in candidates) {
      final fp = _trackFingerprint(c.track);
      fps.putIfAbsent(fp, () => {}).add(c.pluginId);
    }

    for (var i = 0; i < candidates.length; i++) {
      final fp = _trackFingerprint(candidates[i].track);
      if ((fps[fp]?.length ?? 0) >= 2) {
        candidates[i] = ScoredTrackCandidate(
          track: candidates[i].track,
          pluginId: candidates[i].pluginId,
          confidence: math.min(
            candidates[i].confidence + _kCorroborationBonus / 100,
            1.0,
          ),
        );
      }
    }
  }

  String _trackFingerprint(Track track) =>
      '${_resolver.normalized(track.title)}||'
      '${_resolver.artistKeyFromSummaries(track.artists)}';

  // ── Non-track scoring ───────────────────────────────────────────────────

  double _scoreNonTrack(MediaItem target, MediaItem candidate, int rank) {
    final rankBonus = (0.08 - rank * 0.006).clamp(0.0, 0.08);

    return switch ((target, candidate)) {
      (
        MediaItem_Album(:final field0),
        MediaItem_Album(field0: final c),
      ) =>
        _scoreAlbum(field0, c, rankBonus),
      (
        MediaItem_Artist(:final field0),
        MediaItem_Artist(field0: final c),
      ) =>
        _scoreArtist(field0, c, rankBonus),
      (
        MediaItem_Playlist(:final field0),
        MediaItem_Playlist(field0: final c),
      ) =>
        _scorePlaylist(field0, c, rankBonus),
      _ => 0,
    };
  }

  double _scoreAlbum(AlbumSummary t, AlbumSummary c, double rankBonus) {
    var s = _resolver.blendedTextSimilarity(t.title, c.title) * 0.65 +
        _resolver.artistSummarySimilarity(t.artists, c.artists) * 0.22 +
        rankBonus;
    if (t.year != null && c.year != null) {
      final d = (t.year! - c.year!).abs();
      s += d == 0 ? 0.08 : (d == 1 ? 0.04 : 0.0);
    }
    final tn = _resolver.normalized(t.title);
    final cn = _resolver.normalized(c.title);
    if (tn.isNotEmpty && tn == cn) s += 0.08;

    final tSimp = _resolver.simplifyTitle(t.title);
    final cSimp = _resolver.simplifyTitle(c.title);
    if (tSimp.isNotEmpty && tSimp == cSimp) s += 0.08;

    if (c.artists.isEmpty && c.subtitle != null && t.artists.isNotEmpty) {
      final subNorm = _resolver.normalized(c.subtitle);
      for (final a in t.artists) {
        final aNorm = _resolver.normalized(a.name);
        if (aNorm.isNotEmpty && subNorm.contains(aNorm)) {
          s += 0.18;
          break;
        }
      }
    }

    // Artist mismatch penalty: if target and candidate both specify artists,
    // neither is a compilation/soundtrack, and artists completely mismatch (< 25%),
    // penalize heavily to prevent same-title/different-artist albums from scoring high.
    if (t.artists.isNotEmpty &&
        c.artists.isNotEmpty &&
        !_isCompilation(t.artists, t.title) &&
        !_isCompilation(c.artists, c.title)) {
      final artSim = _resolver.artistSummarySimilarity(t.artists, c.artists);
      final subNorm = c.subtitle != null ? _resolver.normalized(c.subtitle) : '';
      final hasSubMatch = t.artists.any((a) =>
          a.name.trim().isNotEmpty && subNorm.contains(_resolver.normalized(a.name)));
      final candTitleNorm = _resolver.normalized(c.title);
      final hasTitleMatch = t.artists.any((a) =>
          a.name.trim().isNotEmpty && candTitleNorm.contains(_resolver.normalized(a.name)));
      if (artSim < 0.25 && !hasSubMatch && !hasTitleMatch) {
        s -= 0.35;
      }
    }

    return s.clamp(0.0, 1.0);
  }

  double _scoreArtist(ArtistSummary t, ArtistSummary c, double rankBonus) {
    var s = _resolver.blendedTextSimilarity(t.name, c.name) * 0.82 +
        _resolver.blendedTextSimilarity(t.subtitle, c.subtitle) * 0.08 +
        rankBonus;
    final tn = _resolver.normalized(t.name);
    final cn = _resolver.normalized(c.name);
    if (tn.isNotEmpty && tn == cn) s += 0.12;
    return s.clamp(0.0, 1.0);
  }

  double _scorePlaylist(
    PlaylistSummary t,
    PlaylistSummary c,
    double rankBonus,
  ) {
    var s = _resolver.blendedTextSimilarity(t.title, c.title) * 0.68 +
        _resolver.blendedTextSimilarity(t.owner, c.owner) * 0.18 +
        rankBonus;
    final tt = _resolver.normalized(t.title);
    final ct = _resolver.normalized(c.title);
    if (tt.isNotEmpty && tt == ct) s += 0.10;
    final to = _resolver.normalized(t.owner);
    final co = _resolver.normalized(c.owner);
    if (to.isNotEmpty && to == co) s += 0.06;
    return s.clamp(0.0, 1.0);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  TrackMatchTarget? _targetFromChartItem(ChartItem chartItem) {
    return switch (chartItem.item) {
      MediaItem_Track(:final field0) => TrackMatchTarget.fromTrack(field0),
      _ => null,
    };
  }

  String _rawFallback(ChartItem chartItem) {
    return switch (chartItem.item) {
      MediaItem_Track(:final field0) => _resolver.joinNonEmpty(
          [field0.title, _resolver.artistNamesJoined(field0.artists)]),
      MediaItem_Album(:final field0) => _resolver.joinNonEmpty(
          [field0.title, _resolver.artistNamesJoined(field0.artists)]),
      MediaItem_Artist(:final field0) => field0.name.trim(),
      MediaItem_Playlist(:final field0) =>
        _resolver.joinNonEmpty([field0.title, field0.owner]),
    };
  }

  List<String> _buildNonTrackQueries(ChartItem chartItem) {
    return switch (chartItem.item) {
      MediaItem_Album(:final field0) => () {
          final simplified = _resolver.simplifyTitle(field0.title);
          final artistsJoined = _resolver.artistNamesJoined(field0.artists);
          final primaryArtist = field0.artists.isNotEmpty
              ? field0.artists.first.name.trim()
              : '';
          return _resolver.uniqueQueries([
            _resolver.joinNonEmpty([field0.title, artistsJoined]),
            if (simplified.isNotEmpty &&
                simplified != _resolver.normalized(field0.title)) ...[
              _resolver.joinNonEmpty([simplified, artistsJoined]),
              if (primaryArtist.isNotEmpty && primaryArtist != artistsJoined)
                _resolver.joinNonEmpty([simplified, primaryArtist]),
              simplified,
            ],
            if (primaryArtist.isNotEmpty && primaryArtist != artistsJoined)
              _resolver.joinNonEmpty([field0.title, primaryArtist]),
            field0.title,
          ]);
        }(),
      MediaItem_Artist(:final field0) => [field0.name.trim()],
      MediaItem_Playlist(:final field0) => _resolver.uniqueQueries([
          _resolver.joinNonEmpty([field0.title, field0.owner]),
          field0.title,
        ]),
      _ => const [],
    };
  }

  ContentSearchFilter _filterFor(ChartItem chartItem) {
    return switch (chartItem.item) {
      MediaItem_Track() => ContentSearchFilter.track,
      MediaItem_Album() => ContentSearchFilter.album,
      MediaItem_Artist() => ContentSearchFilter.artist,
      MediaItem_Playlist() => ContentSearchFilter.playlist,
    };
  }

  bool _compatibleType(MediaItem t, MediaItem c) => switch ((t, c)) {
        (MediaItem_Track(), MediaItem_Track()) => true,
        (MediaItem_Album(), MediaItem_Album()) => true,
        (MediaItem_Artist(), MediaItem_Artist()) => true,
        (MediaItem_Playlist(), MediaItem_Playlist()) => true,
        _ => false,
      };

  List<ScoredTrackCandidate> _mergeLists(
    List<ScoredTrackCandidate> a,
    List<ScoredTrackCandidate> b,
  ) {
    final map = <String, ScoredTrackCandidate>{};
    for (final c in [...a, ...b]) {
      final existing = map[c.track.id];
      if (existing == null || c.confidence > existing.confidence) {
        map[c.track.id] = c;
      }
    }
    return map.values.toList();
  }
}

class _NonTrackScored {
  final MediaSearchResult result;
  final double confidence;
  const _NonTrackScored({required this.result, required this.confidence});
}
