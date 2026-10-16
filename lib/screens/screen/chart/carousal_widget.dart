import 'dart:developer';
import 'dart:async';
import 'package:Orvia/blocs/settings_cubit/cubit/settings_cubit.dart';
import 'package:Orvia/core/di/service_locator.dart';
import 'package:Orvia/plugins/blocs/chart/chart_bloc.dart';
import 'package:Orvia/plugins/blocs/chart/chart_event.dart';
import 'package:Orvia/plugins/blocs/chart/chart_state.dart';
import 'package:Orvia/plugins/blocs/plugin/plugin_bloc.dart';
import 'package:Orvia/plugins/blocs/plugin/plugin_state.dart';
import 'package:Orvia/screens/screen/chart/chart_view.dart';
import 'package:Orvia/screens/screen/chart/chart_widget.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:Orvia/services/festival/festival_service.dart';
import 'package:Orvia/utils/load_image.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

/// Chart carousel widget that displays charts from loaded chart provider plugins
/// and promotes active Indian festivals during their 10-day promotion window.
class CaraouselWidget extends StatefulWidget {
  final VoidCallback? onFestiveTap;

  const CaraouselWidget({super.key, this.onFestiveTap});

  @override
  State<CaraouselWidget> createState() => CaraouselWidgetState();
}

class CaraouselWidgetState extends State<CaraouselWidget> {
  late final ChartBloc _chartBloc;
  ValueNotifier<bool> autoSlideCharts = ValueNotifier(true);
  StreamSubscription<SettingsState>? _settingsSub;

  @override
  void initState() {
    super.initState();
    _chartBloc = ChartBloc(pluginService: ServiceLocator.pluginService);
    autoSlideCharts.value = context.read<SettingsCubit>().state.autoSlideCharts;
    _settingsSub = context.read<SettingsCubit>().stream.listen((event) {
      if (autoSlideCharts.value != event.autoSlideCharts) {
        autoSlideCharts.value = event.autoSlideCharts;
      }
    });
    _loadChartsFromPlugin();
  }

  void _loadChartsFromPlugin() {
    final chartProviders =
        context.read<PluginBloc>().state.loadedChartProviders;
    if (chartProviders.isNotEmpty) {
      final pluginId = chartProviders.first.manifest.id;
      log('Loading charts from plugin: $pluginId', name: 'ChartCarousel');
      _chartBloc.add(LoadCharts(pluginId: pluginId));
    } else {
      log('No chart provider plugins loaded — charts unavailable',
          name: 'ChartCarousel');
    }
  }

  void reloadCharts({bool bypassCache = false}) {
    final chartProviders =
        context.read<PluginBloc>().state.loadedChartProviders;
    if (chartProviders.isNotEmpty) {
      final pluginId = chartProviders.first.manifest.id;
      log('Reloading charts from plugin: $pluginId (bypassCache: $bypassCache)',
          name: 'ChartCarousel');
      _chartBloc.add(LoadCharts(pluginId: pluginId, bypassCache: bypassCache));
      if (bypassCache) {
        final settingsState = context.read<SettingsCubit>().state;
        final visibleIds = _chartBloc.state.charts
            .where((c) => settingsState.chartMap[c.title] ?? true)
            .map((c) => c.id)
            .toSet();
        if (visibleIds.isNotEmpty) {
          _chartBloc.add(PrefetchAllChartDetails(
            pluginId: pluginId,
            chartIds: visibleIds,
            forceRefresh: true,
          ));
        }
      }
    }
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    _chartBloc.close();
    autoSlideCharts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChartBloc, ChartState>(
      bloc: _chartBloc,
      listenWhen: (previous, current) =>
          previous.chartsStatus != ChartStatus.loaded &&
          current.chartsStatus == ChartStatus.loaded,
      listener: (context, chartState) {
        final pluginId = chartState.activePluginId;
        if (pluginId == null || chartState.charts.isEmpty) return;
        final settingsState = context.read<SettingsCubit>().state;
        final visibleIds = chartState.charts
            .where((c) => settingsState.chartMap[c.title] ?? true)
            .map((c) => c.id)
            .toSet();
        if (visibleIds.isNotEmpty) {
          _chartBloc.add(PrefetchAllChartDetails(
            pluginId: pluginId,
            chartIds: visibleIds,
          ));
        }
      },
      child: BlocBuilder<PluginBloc, PluginState>(
        builder: (context, pluginState) {
          if (pluginState.loadedChartProviders.isEmpty) {
            _chartBloc.add(const ClearCharts());
          } else if (_chartBloc.state.chartsStatus == ChartStatus.initial) {
            _loadChartsFromPlugin();
          }
          return BlocBuilder<ChartBloc, ChartState>(
            bloc: _chartBloc,
            builder: (context, chartState) {
              final activeFestival = FestivalService.getActiveOrUpcomingFestival();
              final hasFestiveSlide = activeFestival != null && widget.onFestiveTap != null;

              final settingsState = context.watch<SettingsCubit>().state;
              final visibleCharts = chartState.charts
                  .where((c) => settingsState.chartMap[c.title] ?? true)
                  .toList();

              final totalCount = visibleCharts.length + (hasFestiveSlide ? 1 : 0);
              if (totalCount == 0) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(top: 20),
                child: ValueListenableBuilder<bool>(
                  valueListenable: autoSlideCharts,
                  builder: (context, autoPlay, child) {
                    return CarouselSlider.builder(
                      itemCount: totalCount,
                      itemBuilder: (context, index, realIndex) {
                        if (hasFestiveSlide && index == 0) {
                          return _FestiveSpecialSlide(
                            festival: activeFestival,
                            onTap: widget.onFestiveTap!,
                          );
                        }
                        final chartIndex = hasFestiveSlide ? index - 1 : index;
                        final chart = visibleCharts[chartIndex];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChartScreen(
                                  pluginId:
                                      _chartBloc.state.activePluginId ?? '',
                                  chartId: chart.id,
                                  chartTitle: chart.title,
                                ),
                              ),
                            );
                          },
                          child: ChartWidget(
                            chart: chart,
                            pluginId: _chartBloc.state.activePluginId ?? '',
                          ),
                        );
                      },
                      options: CarouselOptions(
                        height: ResponsiveBreakpoints.of(context).isMobile ||
                                ResponsiveBreakpoints.of(context).isTablet
                            ? MediaQuery.of(context).size.height * 0.36
                            : 250,
                        viewportFraction:
                            ResponsiveBreakpoints.of(context).isMobile
                                ? 0.65
                                : ResponsiveBreakpoints.of(context).isTablet
                                    ? 0.40
                                    : 0.30,
                        autoPlay: autoPlay,
                        autoPlayInterval: const Duration(milliseconds: 2500),
                        enlargeFactor: 0.2,
                        initialPage: 0,
                        pauseAutoPlayOnTouch: true,
                        padEnds: true,
                        enlargeCenterPage:
                            ResponsiveBreakpoints.of(context).isMobile,
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FestiveSpecialSlide extends StatelessWidget {
  final FestivalEvent festival;
  final VoidCallback onTap;

  const _FestiveSpecialSlide({
    required this.festival,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: isMobile || isTablet
              ? MediaQuery.of(context).size.height * 0.35
              : MediaQuery.of(context).size.height * 0.25,
          width: isMobile
              ? MediaQuery.of(context).size.height * 0.3
              : isTablet
                  ? MediaQuery.of(context).size.width * 0.3
                  : MediaQuery.of(context).size.width * 0.25,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF9800),
                Color(0xFFE91E63),
                Color(0xFF9C27B0),
              ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              LoadImageCached(
                imageUrl: festival.bannerUrl,
                fit: BoxFit.cover,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5722),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(MingCute.sparkles_fill, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            festival.greeting,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          festival.bannerTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          festival.bannerSubtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Explore Specials',
                              style: TextStyle(
                                color: Colors.amber.shade300,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_downward_rounded, size: 14, color: Colors.amber.shade300),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
