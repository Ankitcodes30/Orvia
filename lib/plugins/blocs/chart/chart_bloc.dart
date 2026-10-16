import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:Orvia/core/di/service_locator.dart';
import 'package:Orvia/core/events/global_event_bus.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/plugins/blocs/chart/chart_event.dart';
import 'package:Orvia/plugins/blocs/chart/chart_state.dart';
import 'package:Orvia/plugins/errors/plugin_exceptions.dart';
import 'package:Orvia/plugins/utils/media_id.dart';
import 'package:Orvia/services/cache/plugin_cache_repository.dart';
import 'package:Orvia/services/plugin/plugin_service.dart';
import 'package:Orvia/services/plugin_cache_codec.dart';
import 'package:Orvia/plugins/utils/plugin_error_sanitizer.dart';
import 'package:Orvia/src/rust/api/plugin/commands.dart';

/// Manages chart data: listing available charts and loading chart details.
///
/// Works with chart provider plugins via [PluginService].
/// Uses Rust-generated types directly — no converter layer.
class ChartBloc extends Bloc<ChartEvent, ChartState> {
  final PluginService _pluginService;
  final PluginCacheRepository _cache = ServiceLocator.pluginCache;

  ChartBloc({
    required PluginService pluginService,
    String? initialPluginId,
  })  : _pluginService = pluginService,
        super(ChartState(activePluginId: initialPluginId)) {
    on<LoadCharts>(_onLoadCharts);
    on<LoadChartDetails>(_onLoadChartDetails);
    on<ForceRefreshChartDetails>(_onForceRefreshChartDetails);
    on<PrefetchAllChartDetails>(_onPrefetchAllChartDetails);
    on<SetActiveChartPlugin>(_onSetActivePlugin);
    on<ClearCharts>(_onClearCharts);
  }

  static bool _isGenericProviderIcon(String? url) => isGenericProviderIcon(url);

  static String? _extractTopItemArtwork(List<ChartItem> items) {
    if (items.isEmpty) return null;
    for (final chartItem in items) {
      final artworkUrl = chartItem.item.when(
        track: (t) => t.thumbnail.urlHigh ?? t.thumbnail.url,
        album: (a) => a.thumbnail?.urlHigh ?? a.thumbnail?.url,
        artist: (a) => a.thumbnail?.urlHigh ?? a.thumbnail?.url,
        playlist: (p) => p.thumbnail.urlHigh ?? p.thumbnail.url,
      );
      if (artworkUrl != null &&
          artworkUrl.trim().isNotEmpty &&
          !isGenericProviderIcon(artworkUrl)) {
        return artworkUrl.trim();
      }
    }
    return null;
  }

  Future<List<ChartSummary>> _enrichChartsWithArtwork(
    String pluginId,
    List<ChartSummary> charts,
  ) async {
    final enriched = <ChartSummary>[];
    for (final chart in charts) {
      final cacheKey = 'chart_cache::$pluginId::${chart.id}';
      try {
        final cachedDetails =
            await _cache.getCachedWithStaleness<List<ChartItem>>(
          key: cacheKey,
          type: CacheType.chart,
          decode: decodeChartItemsCacheAsync,
          stalenessThreshold: const Duration(hours: 12),
        );
        final topArtwork = cachedDetails.value != null
            ? _extractTopItemArtwork(cachedDetails.value!)
            : null;
        if (topArtwork != null && topArtwork.isNotEmpty) {
          enriched.add(ChartSummary(
            id: chart.id,
            title: chart.title,
            description: chart.description,
            thumbnail: Artwork(
              url: topArtwork,
              urlHigh: topArtwork,
              layout: ImageLayout.square,
            ),
          ));
          continue;
        }
      } catch (_) {}

      if (chart.thumbnail != null &&
          !_isGenericProviderIcon(chart.thumbnail?.url)) {
        enriched.add(chart);
        continue;
      }
      enriched.add(chart);
    }
    return enriched;
  }

  // ── Load Charts (stale-while-revalidate) ──────────────────────────────────

  Future<void> _onLoadCharts(
    LoadCharts event,
    Emitter<ChartState> emit,
  ) async {
    emit(state.copyWith(
      chartsStatus: ChartStatus.loading,
      activePluginId: event.pluginId,
      clearError: true,
    ));

    final cacheKey = 'chart_list::${event.pluginId}';
    final cached = await _cache.getCachedWithStaleness<List<ChartSummary>>(
      key: cacheKey,
      type: CacheType.chartList,
      decode: decodeChartListCacheAsync,
      stalenessThreshold: const Duration(hours: 8),
    );

    final hasCache = cached.value != null;
    if (hasCache) {
      final enrichedCached =
          await _enrichChartsWithArtwork(event.pluginId, cached.value!);
      emit(state.copyWith(
        chartsStatus: ChartStatus.loaded,
        charts: enrichedCached,
      ));
      if (!event.bypassCache && !cached.isStale) return;
      // Stale or bypassCache — continue to background network refresh (no re-emit of loading).
    }

    try {
      final response = await _pluginService.execute(
        pluginId: event.pluginId,
        request: const PluginRequest.chartProvider(
          ChartProviderCommand.getCharts(),
        ),
      );

      void unexpectedFn() {
        if (!hasCache) _unexpectedResponse(emit, 'loadCharts');
      }

      await response.when(
        charts: (charts) async {
          final enriched =
              await _enrichChartsWithArtwork(event.pluginId, charts);
          emit(state.copyWith(
            chartsStatus: ChartStatus.loaded,
            charts: enriched,
          ));
          _cache.put(
            key: cacheKey,
            value: enriched,
            type: CacheType.chartList,
            blob: encodeChartListCache(enriched),
          );
        },
        trackDetails: (_) async => unexpectedFn(),
        search: (_) async => unexpectedFn(),
        albumDetails: (_) async => unexpectedFn(),
        artistDetails: (_) async => unexpectedFn(),
        playlistDetails: (_) async => unexpectedFn(),
        streams: (_) async => unexpectedFn(),
        moreTracks: (_) async => unexpectedFn(),
        moreAlbums: (_) async => unexpectedFn(),
        homeSections: (_) async => unexpectedFn(),
        loadMoreItems: (_) async => unexpectedFn(),
        chartDetails: (_) async => unexpectedFn(),
        segments: (_) async => unexpectedFn(),
        lyricsResult: (_) async => unexpectedFn(),
        lyricsSearchResults: (_) async => unexpectedFn(),
        lyricsById: (_, __) async => unexpectedFn(),
        suggestions: (_) async => unexpectedFn(),
        canHandle: (_) async => unexpectedFn(),
        collectionInfo: (_) async => unexpectedFn(),
        importTracks: (_) async => unexpectedFn(),
        ack: () async => unexpectedFn(),
      );
    } on PluginException catch (e) {
      if (!hasCache) {
        _handlePluginError(emit, e);
      } else {
        log('Background chart refresh failed: $e', name: 'ChartBloc');
      }
    } catch (e, stack) {
      log('LoadCharts error', error: e, stackTrace: stack, name: 'ChartBloc');
      if (!hasCache) {
        emit(state.copyWith(
          chartsStatus: ChartStatus.error,
          error: formatUserFriendlyPluginError(e,
              fallback: 'Failed to load charts.'),
        ));
      }
    }
  }

  void _propagateChartLeadingArtwork({
    required String pluginId,
    required String chartId,
    required List<ChartItem> items,
    required Emitter<ChartState> emit,
  }) {
    final topArtwork = _extractTopItemArtwork(items);
    if (topArtwork != null && topArtwork.isNotEmpty && state.charts.isNotEmpty) {
      final updatedCharts = state.charts.map((c) {
        if (c.id == chartId) {
          return ChartSummary(
            id: c.id,
            title: c.title,
            description: c.description,
            thumbnail: Artwork(
              url: topArtwork,
              urlHigh: topArtwork,
              layout: ImageLayout.square,
            ),
          );
        }
        return c;
      }).toList();
      emit(state.copyWith(
        chartDetailStatus: ChartStatus.loaded,
        chartItems: items,
        charts: updatedCharts,
      ));
      final listCacheKey = 'chart_list::$pluginId';
      _cache.put(
        key: listCacheKey,
        value: updatedCharts,
        type: CacheType.chartList,
        blob: encodeChartListCache(updatedCharts),
      );
    } else {
      emit(state.copyWith(
        chartDetailStatus: ChartStatus.loaded,
        chartItems: items,
      ));
    }
  }

  // ── Load Chart Details (stale-while-revalidate) ────────────────────────────

  Future<void> _onLoadChartDetails(
    LoadChartDetails event,
    Emitter<ChartState> emit,
  ) async {
    emit(state.copyWith(
      chartDetailStatus: ChartStatus.loading,
      activeChartId: event.chartId,
      clearError: true,
    ));

    final cacheKey = 'chart_cache::${event.pluginId}::${event.chartId}';
    final cached = await _cache.getCachedWithStaleness<List<ChartItem>>(
      key: cacheKey,
      type: CacheType.chart,
      decode: decodeChartItemsCacheAsync,
      stalenessThreshold: const Duration(hours: 8),
    );

    final hasCache = cached.value != null;
    if (hasCache) {
      emit(state.copyWith(
        chartDetailStatus: ChartStatus.loaded,
        chartItems: cached.value!,
      ));
      if (!cached.isStale) return;
      // Stale — continue to background network refresh.
    }

    try {
      final localId = localIdOf(event.chartId) ?? event.chartId;
      final response = await _pluginService.execute(
        pluginId: event.pluginId,
        request: PluginRequest.chartProvider(
          ChartProviderCommand.getChartDetails(id: localId),
        ),
      );

      void unexpectedFn() {
        if (!hasCache) _unexpectedResponse(emit, 'loadChartDetails');
      }

      response.when(
        chartDetails: (items) {
          _propagateChartLeadingArtwork(
            pluginId: event.pluginId,
            chartId: event.chartId,
            items: items,
            emit: emit,
          );
          _cache.put(
            key: cacheKey,
            value: items,
            type: CacheType.chart,
            blob: encodeChartItemsCache(items),
          );
        },
        trackDetails: (_) => unexpectedFn(),
        search: (_) => unexpectedFn(),
        albumDetails: (_) => unexpectedFn(),
        artistDetails: (_) => unexpectedFn(),
        playlistDetails: (_) => unexpectedFn(),
        streams: (_) => unexpectedFn(),
        moreTracks: (_) => unexpectedFn(),
        moreAlbums: (_) => unexpectedFn(),
        homeSections: (_) => unexpectedFn(),
        loadMoreItems: (_) => unexpectedFn(),
        charts: (_) => unexpectedFn(),
        segments: (_) => unexpectedFn(),
        lyricsResult: (_) => unexpectedFn(),
        lyricsSearchResults: (_) => unexpectedFn(),
        lyricsById: (_, __) => unexpectedFn(),
        suggestions: (_) => unexpectedFn(),
        canHandle: (_) => unexpectedFn(),
        collectionInfo: (_) => unexpectedFn(),
        importTracks: (_) => unexpectedFn(),
        ack: () => unexpectedFn(),
      );
    } on PluginException catch (e) {
      if (!hasCache) {
        _handlePluginError(emit, e, chartDetail: true);
      } else {
        log('Background chart detail refresh failed: $e', name: 'ChartBloc');
      }
    } catch (e, stack) {
      log('LoadChartDetails error',
          error: e, stackTrace: stack, name: 'ChartBloc');
      if (!hasCache) {
        emit(state.copyWith(
          chartDetailStatus: ChartStatus.error,
          error: formatUserFriendlyPluginError(e,
              fallback: 'Failed to load chart details.'),
        ));
      }
    }
  }

  // ── Force-Refresh Chart Details ────────────────────────────────────────────

  Future<void> _onForceRefreshChartDetails(
    ForceRefreshChartDetails event,
    Emitter<ChartState> emit,
  ) async {
    emit(state.copyWith(
      chartDetailStatus: ChartStatus.loading,
      clearError: true,
    ));

    try {
      final localId = localIdOf(event.chartId) ?? event.chartId;
      final response = await _pluginService.execute(
        pluginId: event.pluginId,
        request: PluginRequest.chartProvider(
          ChartProviderCommand.getChartDetails(id: localId),
        ),
      );

      response.when(
        chartDetails: (items) {
          _propagateChartLeadingArtwork(
            pluginId: event.pluginId,
            chartId: event.chartId,
            items: items,
            emit: emit,
          );
          _cache.put(
            key: 'chart_cache::${event.pluginId}::${event.chartId}',
            value: items,
            type: CacheType.chart,
            blob: encodeChartItemsCache(items),
          );
        },
        trackDetails: (_) =>
            _unexpectedResponse(emit, 'forceRefreshChartDetails'),
        search: (_) => _unexpectedResponse(emit, 'forceRefreshChartDetails'),
        albumDetails: (_) =>
            _unexpectedResponse(emit, 'forceRefreshChartDetails'),
        artistDetails: (_) =>
            _unexpectedResponse(emit, 'forceRefreshChartDetails'),
        playlistDetails: (_) =>
            _unexpectedResponse(emit, 'forceRefreshChartDetails'),
        streams: (_) => _unexpectedResponse(emit, 'forceRefreshChartDetails'),
        moreTracks: (_) =>
            _unexpectedResponse(emit, 'forceRefreshChartDetails'),
        moreAlbums: (_) =>
            _unexpectedResponse(emit, 'forceRefreshChartDetails'),
        homeSections: (_) =>
            _unexpectedResponse(emit, 'forceRefreshChartDetails'),
        loadMoreItems: (_) =>
            _unexpectedResponse(emit, 'forceRefreshChartDetails'),
        charts: (_) => _unexpectedResponse(emit, 'forceRefreshChartDetails'),
        segments: (_) => _unexpectedResponse(emit, 'forceRefreshChartDetails'),
        lyricsResult: (_) =>
            _unexpectedResponse(emit, 'forceRefreshChartDetails'),
        lyricsSearchResults: (_) =>
            _unexpectedResponse(emit, 'forceRefreshChartDetails'),
        lyricsById: (_, __) =>
            _unexpectedResponse(emit, 'forceRefreshChartDetails'),
        suggestions: (_) =>
            _unexpectedResponse(emit, 'forceRefreshChartDetails'),
        canHandle: (_) => _unexpectedResponse(emit, 'forceRefreshChartDetails'),
        collectionInfo: (_) =>
            _unexpectedResponse(emit, 'forceRefreshChartDetails'),
        importTracks: (_) =>
            _unexpectedResponse(emit, 'forceRefreshChartDetails'),
        ack: () => _unexpectedResponse(emit, 'forceRefreshChartDetails'),
      );
    } on PluginException catch (e) {
      _handlePluginError(emit, e, chartDetail: true);
    } catch (e, stack) {
      log('ForceRefreshChartDetails error',
          error: e, stackTrace: stack, name: 'ChartBloc');
      emit(state.copyWith(
        chartDetailStatus: ChartStatus.error,
        error: 'Failed to refresh chart: $e',
      ));
    }
  }

  // ── Prefetch All Chart Details (silent background) ─────────────────────────

  Future<void> _onPrefetchAllChartDetails(
    PrefetchAllChartDetails event,
    Emitter<ChartState> emit,
  ) async {
    for (final chartId in event.chartIds) {
      if (isClosed) break;

      final cacheKey = 'chart_cache::${event.pluginId}::$chartId';
      try {
        final cached = await _cache.getCachedWithStaleness<List<ChartItem>>(
          key: cacheKey,
          type: CacheType.chart,
          decode: decodeChartItemsCacheAsync,
          stalenessThreshold: const Duration(hours: 8),
        );

        List<ChartItem>? chartItems = cached.value;

        // Skip network fetch if fresh and not force-refreshing
        if (cached.value == null || cached.isStale || event.forceRefresh) {
          if (isClosed) break;

          final localId = localIdOf(chartId) ?? chartId;
          final response = await _pluginService.execute(
            pluginId: event.pluginId,
            request: PluginRequest.chartProvider(
              ChartProviderCommand.getChartDetails(id: localId),
            ),
          );

          response.when(
            chartDetails: (items) {
              chartItems = items;
              _cache.put(
                key: cacheKey,
                value: items,
                type: CacheType.chart,
                blob: encodeChartItemsCache(items),
              );
            },
            trackDetails: (_) {},
            search: (_) {},
            albumDetails: (_) {},
            artistDetails: (_) {},
            playlistDetails: (_) {},
            streams: (_) {},
            moreTracks: (_) {},
            moreAlbums: (_) {},
            homeSections: (_) {},
            loadMoreItems: (_) {},
            charts: (_) {},
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
        }

        // Enrich the corresponding chart summary with the genuine top-item artwork
        if (chartItems != null && chartItems!.isNotEmpty) {
          final topArtwork = _extractTopItemArtwork(chartItems!);
          if (topArtwork != null && topArtwork.isNotEmpty) {
            final currentCharts = state.charts;
            var updated = false;
            final updatedCharts = currentCharts.map((c) {
              if (c.id == chartId &&
                  (c.thumbnail == null ||
                      _isGenericProviderIcon(c.thumbnail?.url) ||
                      c.thumbnail?.url != topArtwork)) {
                updated = true;
                return ChartSummary(
                  id: c.id,
                  title: c.title,
                  description: c.description,
                  thumbnail: Artwork(
                    url: topArtwork,
                    urlHigh: topArtwork,
                    layout: ImageLayout.square,
                  ),
                );
              }
              return c;
            }).toList();

            if (updated && !isClosed) {
              emit(state.copyWith(charts: updatedCharts));
              _cache.put(
                key: 'chart_list::${event.pluginId}',
                value: updatedCharts,
                type: CacheType.chartList,
                blob: encodeChartListCache(updatedCharts),
              );
            }
          }
        }
      } catch (e) {
        log('Prefetch failed for chart $chartId: $e', name: 'ChartBloc');
        // Continue with next chart on failure.
      }
    }
  }

  // ── Set Active Plugin ──────────────────────────────────────────────────────

  void _onSetActivePlugin(
    SetActiveChartPlugin event,
    Emitter<ChartState> emit,
  ) {
    emit(ChartState(activePluginId: event.pluginId));
  }

  // ── Clear ──────────────────────────────────────────────────────────────────

  void _onClearCharts(ClearCharts event, Emitter<ChartState> emit) {
    emit(const ChartState.initial());
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _unexpectedResponse(Emitter<ChartState> emit, String context) {
    log('Unexpected response type for $context', name: 'ChartBloc');
    // Transition any currently-loading status to error so the UI
    // never gets stuck in a permanent loading state.
    emit(state.copyWith(
      error: 'Unexpected response from plugin',
      chartsStatus:
          state.chartsStatus == ChartStatus.loading ? ChartStatus.error : null,
      chartDetailStatus: state.chartDetailStatus == ChartStatus.loading
          ? ChartStatus.error
          : null,
    ));
  }

  void _handlePluginError(
    Emitter<ChartState> emit,
    PluginException e, {
    bool chartDetail = false,
  }) {
    if (e is PluginNotLoadedException) {
      GlobalEventBus.instance.emitError(
        AppError.pluginNotLoaded(pluginId: e.pluginId ?? 'unknown'),
      );
    } else if (e is PluginNotFoundException) {
      GlobalEventBus.instance.emitError(
        AppError.pluginError(
          pluginId: e.pluginId ?? 'unknown',
          message: 'Chart plugin not found: ${e.pluginId}',
        ),
      );
    }

    emit(state.copyWith(
      chartsStatus: chartDetail ? null : ChartStatus.error,
      chartDetailStatus: chartDetail ? ChartStatus.error : null,
      error: formatUserFriendlyPluginError(e.message),
    ));
  }
}
