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
import 'package:Orvia/services/banner/smart_banner_service.dart';
import 'package:Orvia/screens/widgets/navratri_special_card.dart';
import 'package:Orvia/screens/widgets/diwali_special_card.dart';
import 'package:Orvia/blocs/media_player/orvia_player_cubit.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/utils/load_image.dart';
import 'package:Orvia/plugins/utils/plugin_error_sanitizer.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

/// Chart carousel widget that displays charts from loaded chart provider plugins,
/// promotes active Indian festivals during their configured promotion window,
/// and rotates curated time-aware collections (Morning Bhakti, Gym Energy).
bool _isExcludedCarouselChart(dynamic chart) {
  final title = (chart.title ?? '').toString().trim().toLowerCase();
  final id = (chart.id ?? '').toString().trim().toLowerCase();
  if (title == 'india songs' ||
      title.contains('india song') ||
      id == 'india-songs' ||
      id == 'india_songs' ||
      id.contains('india-songs') ||
      id.contains('india_songs')) {
    return true;
  }
  return false;
}

class CaraouselWidget extends StatefulWidget {
  final VoidCallback? onFestiveTap;

  const CaraouselWidget({super.key, this.onFestiveTap});

  @override
  State<CaraouselWidget> createState() => CaraouselWidgetState();
}

class CaraouselWidgetState extends State<CaraouselWidget>
    with WidgetsBindingObserver {
  late final ChartBloc _chartBloc;
  ValueNotifier<bool> autoSlideCharts = ValueNotifier(true);
  StreamSubscription<SettingsState>? _settingsSub;
  Timer? _bannerBoundaryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chartBloc = ChartBloc(pluginService: ServiceLocator.pluginService);
    autoSlideCharts.value = context.read<SettingsCubit>().state.autoSlideCharts;
    _settingsSub = context.read<SettingsCubit>().stream.listen((event) {
      if (autoSlideCharts.value != event.autoSlideCharts) {
        autoSlideCharts.value = event.autoSlideCharts;
      }
    });
    _loadChartsFromPlugin();
    SmartBannerService.refreshRemoteBanners().then((_) {
      if (mounted) setState(() {});
    });
    _scheduleBannerBoundary();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        setState(() {});
        _scheduleBannerBoundary();
      }
    }
  }

  void _scheduleBannerBoundary() {
    _bannerBoundaryTimer?.cancel();
    final boundary = SmartBannerService.nextDateBoundary();
    if (boundary != null) {
      final delay = boundary.difference(DateTime.now());
      _bannerBoundaryTimer = Timer(
        delay.isNegative ? Duration.zero : delay,
        () {
          if (mounted) {
            setState(() {});
            _scheduleBannerBoundary();
          }
        },
      );
    }
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
            .where((c) => !_isExcludedCarouselChart(c) && (settingsState.chartMap[c.title] ?? true))
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
    WidgetsBinding.instance.removeObserver(this);
    _bannerBoundaryTimer?.cancel();
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
            .where((c) => !_isExcludedCarouselChart(c) && (settingsState.chartMap[c.title] ?? true))
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
              final activeFestival =
                  FestivalService.getActiveOrUpcomingFestival();
              final hasFestiveSlide =
                  activeFestival != null && widget.onFestiveTap != null;

              // Filter out duplicate festival banner from smart banners if active festival slide is shown
              final rawSmartBanners = SmartBannerService.getActiveBanners();
              final filteredBanners = rawSmartBanners.where((b) {
                final id = b.id.toLowerCase();
                final title = b.title.toLowerCase();
                if (id == 'india_songs' ||
                    id == 'india-songs' ||
                    id.contains('india_songs') ||
                    id.contains('india-songs') ||
                    title == 'india songs' ||
                    title.contains('india song')) {
                  return false;
                }
                if (hasFestiveSlide &&
                    (b.destination == 'festival_special' ||
                        b.id.contains('navratri') ||
                        b.id.contains('diwali'))) {
                  return false;
                }
                return true;
              }).toList();

              // UI Safeguard: Retain Creator's Choice if unexpectedly absent
              if (!filteredBanners.any((b) => b.id == 'creators_choice')) {
                filteredBanners.add(SmartBannerService.defaultCreatorsChoiceBanner);
                filteredBanners.sort((a, b) => b.priority.compareTo(a.priority));
              }

              // Deduplicate by ID before rendering
              final seenBannerIds = <String>{};
              final smartBanners = <SmartBannerItem>[];
              for (final b in filteredBanners) {
                if (seenBannerIds.add(b.id)) {
                  smartBanners.add(b);
                }
              }

              final settingsState = context.watch<SettingsCubit>().state;
              final visibleCharts = chartState.charts
                  .where((c) => !_isExcludedCarouselChart(c) && (settingsState.chartMap[c.title] ?? true))
                  .toList();

              final festiveCount = hasFestiveSlide ? 1 : 0;
              final bannerCount = smartBanners.length;
              final totalCount =
                  festiveCount + bannerCount + visibleCharts.length;
              if (totalCount == 0) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(top: 20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
                    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
                    final viewportFraction = isMobile
                        ? 0.65
                        : (isTablet ? 0.40 : 0.30);

                    // Viewport-based card width constraints based on actual carousel width
                    final carouselWidth = constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : MediaQuery.of(context).size.width;
                    final slotWidth = carouselWidth * viewportFraction;
                    // Provide 4dp breathing room on each side (8dp total) so slides do not touch or clip
                    final cardWidth = slotWidth > 16.0 ? (slotWidth - 8.0) : slotWidth;

                    // Clamped height calculations to prevent vertical distortion in compact / tall modes
                    final rawHeight = (isMobile || isTablet)
                        ? (MediaQuery.of(context).size.height * 0.36).clamp(180.0, 340.0)
                        : 250.0;
                    final maxConstraintHeight = constraints.maxHeight.isFinite
                        ? constraints.maxHeight
                        : double.infinity;
                    final carouselHeight = rawHeight.clamp(
                        160.0,
                        maxConstraintHeight.isFinite ? maxConstraintHeight : 400.0);
                    final cardHeight = (carouselHeight - 10.0).clamp(150.0, carouselHeight);

                    return ValueListenableBuilder<bool>(
                      valueListenable: autoSlideCharts,
                      builder: (context, autoPlay, child) {
                        return CarouselSlider.builder(
                          itemCount: totalCount,
                          itemBuilder: (context, index, realIndex) {
                            if (hasFestiveSlide && index == 0) {
                              return _FestiveSpecialSlide(
                                festival: activeFestival,
                                onTap: widget.onFestiveTap!,
                                cardWidth: cardWidth,
                                cardHeight: cardHeight,
                              );
                            }
                            final bannerIdx = index - festiveCount;
                            if (bannerIdx >= 0 && bannerIdx < bannerCount) {
                              return _SmartBannerSlide(
                                banner: smartBanners[bannerIdx],
                                onFestivalTap: widget.onFestiveTap,
                                cardWidth: cardWidth,
                                cardHeight: cardHeight,
                              );
                            }
                            final chartIndex = bannerIdx - bannerCount;
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
                            height: carouselHeight,
                            viewportFraction: viewportFraction,
                            autoPlay: autoPlay,
                            autoPlayInterval: const Duration(milliseconds: 2500),
                            enlargeFactor: 0.2,
                            initialPage: 0,
                            pauseAutoPlayOnTouch: true,
                            padEnds: true,
                            enlargeCenterPage: isMobile,
                          ),
                        );
                      },
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

typedef _FestiveSpecialSlide = FestiveSpecialSlide;

class FestiveSpecialSlide extends StatelessWidget {
  final FestivalEvent festival;
  final VoidCallback onTap;
  final double? cardWidth;
  final double? cardHeight;

  const FestiveSpecialSlide({
    super.key,
    required this.festival,
    required this.onTap,
    this.cardWidth,
    this.cardHeight,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = false;
        bool isTablet = false;
        try {
          isMobile = ResponsiveBreakpoints.of(context).isMobile;
          isTablet = ResponsiveBreakpoints.of(context).isTablet;
        } catch (_) {
          final w = MediaQuery.maybeOf(context)?.size.width ?? 360.0;
          isMobile = w <= 450;
          isTablet = w > 450 && w <= 800;
        }
        final viewportFraction = isMobile
            ? 0.65
            : (isTablet ? 0.40 : 0.30);

        final double effectiveWidth;
        if (cardWidth != null && cardWidth! > 0) {
          effectiveWidth = cardWidth!;
        } else if (constraints.maxWidth.isFinite && constraints.maxWidth > 0) {
          effectiveWidth = constraints.maxWidth > 16.0
              ? (constraints.maxWidth - 8.0)
              : constraints.maxWidth;
        } else {
          final slot = MediaQuery.of(context).size.width * viewportFraction;
          effectiveWidth = slot > 16.0 ? (slot - 8.0) : slot;
        }

        final double effectiveHeight;
        if (cardHeight != null && cardHeight! > 0) {
          effectiveHeight = cardHeight!;
        } else if (constraints.maxHeight.isFinite && constraints.maxHeight > 0) {
          effectiveHeight = constraints.maxHeight;
        } else {
          effectiveHeight = (isMobile || isTablet)
              ? (MediaQuery.of(context).size.height * 0.35).clamp(170.0, 320.0)
              : 230.0;
        }

        return GestureDetector(
          onTap: () {
            if (festival.id.contains('diwali') ||
                festival.name.toLowerCase().contains('diwali')) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DiwaliSpecialScreen()),
              );
              return;
            }
            if (festival.id.contains('navratri') ||
                festival.name.toLowerCase().contains('navratri')) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NavratriSpecialScreen()),
              );
              return;
            }
            onTap();
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: effectiveHeight,
              width: effectiveWidth,
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
              if (festival.id.contains('diwali'))
                const _DiwaliFestiveArtwork()
              else
                LoadImageCached(
                  imageUrl: festival.bannerUrl,
                  fit: BoxFit.cover,
                ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: festival.id.contains('diwali')
                        ? [
                            Colors.black.withValues(alpha: 0.25),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.15),
                          ]
                        : [
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: festival.id.contains('diwali')
                            ? const Color(0xFFFF9800)
                            : const Color(0xFFFF5722),
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
                          const Icon(MingCute.sparkles_fill,
                              size: 14, color: Colors.white),
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
                    if (!festival.id.contains('diwali'))
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
                              Flexible(
                                child: Text(
                                  'Explore Specials',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.amber.shade300,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_downward_rounded,
                                  size: 14, color: Colors.amber.shade300),
                            ],
                          ),
                        ],
                      )
                    else
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Tap to listen',
                                style: TextStyle(
                                  color: Colors.amber.shade200,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(MingCute.play_fill,
                                  size: 10, color: Colors.amber.shade200),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
      },
    );
  }
}

class _DiwaliFestiveArtwork extends StatelessWidget {
  const _DiwaliFestiveArtwork();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/diwali_festive_banner.webp',
      fit: BoxFit.cover,
      alignment: Alignment.center,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        'assets/images/diwali_festive_banner.png',
        fit: BoxFit.cover,
        alignment: Alignment.center,
      ),
    );
  }
}

typedef _SmartBannerSlide = SmartBannerSlide;

class SmartBannerSlide extends StatelessWidget {
  final SmartBannerItem banner;
  final VoidCallback? onFestivalTap;
  final double? cardWidth;
  final double? cardHeight;

  const SmartBannerSlide({
    super.key,
    required this.banner,
    this.onFestivalTap,
    this.cardWidth,
    this.cardHeight,
  });

  void _openBanner(BuildContext context) {
    if (banner.id.contains('diwali') ||
        banner.title.toLowerCase().contains('diwali')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DiwaliSpecialScreen()),
      );
      return;
    }

    if (banner.id == 'navratri_special_2026' ||
        banner.title.toLowerCase().contains('navratri')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NavratriSpecialScreen()),
      );
      return;
    }

    if (banner.destination == 'festival_special' && onFestivalTap != null) {
      onFestivalTap!();
      return;
    }

    if (banner.tracks.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Container(
          height: MediaQuery.of(modalContext).size.height * 0.72,
          decoration: BoxDecoration(
            color: Default_Theme.themeColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: LoadImageCached(
                          imageUrl: banner.imageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            banner.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${banner.tracks.length} tracks • ${banner.badge}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(modalContext);
                        context
                            .read<OrviaPlayerCubit>()
                            .orviaPlayer
                            .loadPlaylist(
                              Playlist(
                                tracks: banner.tracks,
                                title: banner.title,
                              ),
                              idx: 0,
                              doPlay: true,
                              isFromPlaylist: false,
                            );
                      },
                      icon: const Icon(MingCute.play_fill, size: 16),
                      label: const Text('Play All'),
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
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: banner.tracks.length,
                  itemBuilder: (context, idx) {
                    final t = banner.tracks[idx];
                    final artworkUrl = [
                      t.thumbnail.urlHigh,
                      t.thumbnail.url,
                      t.thumbnail.urlLow,
                    ].whereType<String>().map((u) => u.trim()).firstWhere(
                          (u) => u.isNotEmpty && !isGenericProviderIcon(u),
                          orElse: () => '',
                        );
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: LoadImageCached(
                            imageUrl: artworkUrl,
                            fallbackUrl: t.thumbnail.url,
                            mediaId: t.id,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      title: Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      subtitle: Text(
                        t.artists.map((a) => a.name).join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(MingCute.play_circle_line,
                          color: Colors.white38, size: 22),
                      onTap: () {
                        Navigator.pop(modalContext);
                        context
                            .read<OrviaPlayerCubit>()
                            .orviaPlayer
                            .loadPlaylist(
                              Playlist(
                                tracks: banner.tracks,
                                title: banner.title,
                              ),
                              idx: idx,
                              doPlay: true,
                              isFromPlaylist: false,
                            );
                      },
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = false;
        bool isTablet = false;
        try {
          isMobile = ResponsiveBreakpoints.of(context).isMobile;
          isTablet = ResponsiveBreakpoints.of(context).isTablet;
        } catch (_) {
          final w = MediaQuery.maybeOf(context)?.size.width ?? 360.0;
          isMobile = w <= 450;
          isTablet = w > 450 && w <= 800;
        }
        final viewportFraction = isMobile
            ? 0.65
            : (isTablet ? 0.40 : 0.30);

        final double effectiveWidth;
        if (cardWidth != null && cardWidth! > 0) {
          effectiveWidth = cardWidth!;
        } else if (constraints.maxWidth.isFinite && constraints.maxWidth > 0) {
          effectiveWidth = constraints.maxWidth > 16.0
              ? (constraints.maxWidth - 8.0)
              : constraints.maxWidth;
        } else {
          final slot = MediaQuery.of(context).size.width * viewportFraction;
          effectiveWidth = slot > 16.0 ? (slot - 8.0) : slot;
        }

        final double effectiveHeight;
        if (cardHeight != null && cardHeight! > 0) {
          effectiveHeight = cardHeight!;
        } else if (constraints.maxHeight.isFinite && constraints.maxHeight > 0) {
          effectiveHeight = constraints.maxHeight;
        } else {
          effectiveHeight = (isMobile || isTablet)
              ? (MediaQuery.of(context).size.height * 0.35).clamp(170.0, 320.0)
              : 230.0;
        }

        return GestureDetector(
          onTap: () => _openBanner(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: effectiveHeight,
              width: effectiveWidth,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: banner.gradientColors.isNotEmpty
                  ? banner.gradientColors
                  : const [Color(0xFF1E1035), Color(0xFF0F1E36)],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (banner.imageUrl.isNotEmpty)
                LoadImageCached(
                  imageUrl: banner.imageUrl,
                  fit: BoxFit.cover,
                ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.88),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            Default_Theme.accentColor2.withValues(alpha: 0.9),
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
                          const Icon(MingCute.music_2_fill,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            banner.badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          banner.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          banner.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              MingCute.play_circle_fill,
                              color: Default_Theme.accentColor2,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${banner.tracks.length} tracks • Tap to explore',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Default_Theme.accentColor2,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
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
      },
    );
  }
}
