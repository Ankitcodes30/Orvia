import 'dart:async';
import 'dart:developer';
import 'package:Orvia/blocs/explore/cubit/explore_cubits.dart';
import 'package:Orvia/blocs/internet_connectivity/cubit/connectivity_cubit.dart';
import 'package:Orvia/blocs/lastdotfm/lastdotfm_cubit.dart';
import 'package:Orvia/blocs/media_player/orvia_player_cubit.dart';
import 'package:Orvia/blocs/notification/notification_cubit.dart';
import 'package:Orvia/blocs/settings_cubit/cubit/settings_cubit.dart';
import 'package:Orvia/screens/widgets/snackbar.dart';
import 'package:Orvia/utils/load_image.dart';
import 'package:Orvia/core/di/service_locator.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/plugins/blocs/content/content_bloc.dart';
import 'package:Orvia/plugins/blocs/content/content_event.dart';
import 'package:Orvia/plugins/blocs/content/content_state.dart';
import 'package:Orvia/plugins/blocs/plugin/plugin_bloc.dart';
import 'package:Orvia/plugins/blocs/plugin/plugin_state.dart';
import 'package:Orvia/screens/screen/home_views/recents_view.dart';
import 'package:Orvia/screens/screen/home_views/setting_views/about.dart';
import 'package:Orvia/screens/widgets/more_bottom_sheet.dart';
import 'package:Orvia/screens/widgets/sign_board_widget.dart';
import 'package:Orvia/screens/widgets/song_tile.dart';
import 'package:flutter/material.dart';
import 'package:Orvia/screens/screen/home_views/notification_view.dart';
import 'package:Orvia/screens/screen/home_views/setting_view.dart';
import 'package:Orvia/screens/screen/home_views/timer_view.dart';
import 'package:Orvia/core/theme/app_theme.dart';
import 'package:Orvia/l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'chart/carousal_widget.dart';
import '../widgets/horizontal_card_view.dart';
import '../widgets/tab_list_widget.dart';
import 'package:badges/badges.dart' as badges;
import 'package:collection/collection.dart';
import 'package:Orvia/screens/widgets/bhakti_section.dart';
import 'package:Orvia/screens/widgets/featured_artists_section.dart';
import 'package:Orvia/screens/widgets/indian_browse_categories.dart';
import 'package:Orvia/screens/widgets/instrumental_section.dart';
import 'package:Orvia/screens/widgets/navratri_special_card.dart';
import 'package:Orvia/screens/widgets/whats_hot_near_you.dart';
import 'package:Orvia/screens/widgets/year_collections_section.dart';
import 'package:Orvia/services/festival/festival_service.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  bool isUpdateChecked = false;
  late final ContentBloc _homeContentBloc;
  Future<List<Track>> lFMData = Future.value(const []);
  final GlobalKey<CaraouselWidgetState> _carouselKey =
      GlobalKey<CaraouselWidgetState>();
  final GlobalKey _festiveSectionKey = GlobalKey();
  bool _isRefreshing = false;
  DateTime? _lastReconnectRefreshTime;

  @override
  void initState() {
    super.initState();
    _homeContentBloc = ContentBloc(pluginService: ServiceLocator.pluginService);
    _tryLoadHomeSections();
    FestivalService.refreshRemoteSchedule();
  }

  void _scrollToFestiveSpecial() {
    final ctx = _festiveSectionKey.currentContext;
    if (ctx != null) {
      final disableAnim = MediaQuery.of(context).disableAnimations;
      Scrollable.ensureVisible(
        ctx,
        duration: disableAnim ? Duration.zero : const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
        alignment: 0.08,
      );
    }
  }

  Future<void> _handleRefresh({bool isAutoReconnect = false}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      // 1. Reset failed image cache so previously failing thumbnails can retry
      LoadImageCached.clearFailedUrls();

      if (isAutoReconnect) {
        SnackbarService.showMessage(
          "You're back online. Refreshing content…",
          duration: const Duration(seconds: 3),
        );
      }

      // 2. Refresh top chart carousel with cache bypass
      _carouselKey.currentState?.reloadCharts(bypassCache: true);

      // 3. Refresh home sections with cache bypass
      final contentResolvers =
          context.read<PluginBloc>().state.loadedContentResolvers;
      if (contentResolvers.isNotEmpty) {
        final pluginId = _effectiveHomePluginId(contentResolvers);
        final completer = Completer<void>();

        late final StreamSubscription sub;
        sub = _homeContentBloc.stream.listen((state) {
          if (state.homeSectionsStatus == DetailStatus.loaded ||
              state.homeSectionsStatus == DetailStatus.error) {
            if (!completer.isCompleted) completer.complete();
          }
        });

        _homeContentBloc.add(
          GetHomeSections(pluginId: pluginId, bypassCache: true),
        );

        // Await with timeout so indicator never gets stuck
        await completer.future.timeout(
          const Duration(seconds: 8),
          onTimeout: () {},
        );
        await sub.cancel();
      }

      // 4. Refresh Last.fm picks if enabled
      if (mounted && context.read<SettingsCubit>().state.lFMPicks) {
        setState(() {
          lFMData = fetchLFMPicks(true, context);
        });
      }
    } catch (e) {
      log('Home refresh error: $e', name: 'ExploreScreen');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      } else {
        _isRefreshing = false;
      }
    }
  }

  /// Only loads home sections when both settings are ready and plugins are loaded.
  void _tryLoadHomeSections() {
    final settingsState = context.read<SettingsCubit>().state;
    if (!settingsState.settingsReady) return;

    final pluginState = context.read<PluginBloc>().state;
    final contentResolvers = pluginState.loadedContentResolvers;
    if (contentResolvers.isEmpty) return;

    final preferredId = settingsState.homePluginId;
    // If the user's preferred plugin is installed but not yet loaded, wait for it.
    // This prevents flashing the wrong plugin's home page on startup.
    if (preferredId.isNotEmpty) {
      final isAlreadyLoaded =
          contentResolvers.any((p) => p.manifest.id == preferredId);
      if (!isAlreadyLoaded) {
        final isInstalled = pluginState.availablePlugins
            .any((p) => p.manifest.id == preferredId);
        if (isInstalled) return; // Preferred plugin is loading — wait for it
      }
    }

    final pluginId = _effectiveHomePluginId(contentResolvers);

    // Don't reload if we're already showing content from this plugin.
    if (_homeContentBloc.state.activePluginId == pluginId &&
        _homeContentBloc.state.homeSections != null) {
      return;
    }

    _homeContentBloc.add(GetHomeSections(pluginId: pluginId));
  }

  String _effectiveHomePluginId(List<dynamic> loadedResolvers) {
    final preferredId = context.read<SettingsCubit>().state.homePluginId;
    final hasPreferred = preferredId.isNotEmpty &&
        loadedResolvers.any((plugin) => plugin.manifest.id == preferredId);
    return hasPreferred ? preferredId : loadedResolvers.first.manifest.id;
  }

  @override
  void dispose() {
    _homeContentBloc.close();
    super.dispose();
  }

  Future<List<Track>> fetchLFMPicks(bool state, BuildContext ctx) async {
    if (state) {
      try {
        final data = await lFMData;
        if (data.isNotEmpty) return data;
        if (ctx.mounted) {
          final pluginState = ctx.read<PluginBloc>().state;
          final priority = ctx.read<SettingsCubit>().state.resolverPriority;
          final allIds = pluginState.loadedContentResolvers
              .map((p) => p.manifest.id)
              .toList();
          final resolverIds = [
            ...priority.where(allIds.contains),
            ...allIds.where((id) => !priority.contains(id)),
          ];
          lFMData = ctx.read<LastdotfmCubit>().getRecommendedTracks(
                resolverPluginIds: resolverIds,
              );
        }
        return (await lFMData);
      } catch (e) {
        log(e.toString(), name: "ExploreScreen");
      }
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: MultiBlocListener(
        listeners: [
          BlocListener<SettingsCubit, SettingsState>(
            listenWhen: (previous, current) =>
                previous.homePluginId != current.homePluginId ||
                (!previous.settingsReady && current.settingsReady),
            listener: (context, state) {
              _homeContentBloc.add(const ClearHomeSections());
              _tryLoadHomeSections();
            },
          ),
          BlocListener<PluginBloc, PluginState>(
            listenWhen: (previous, current) {
              return previous.loadedContentResolvers !=
                      current.loadedContentResolvers ||
                  previous.loadedPluginIds != current.loadedPluginIds;
            },
            listener: (context, state) {
              if (state.loadedContentResolvers.isEmpty) {
                _homeContentBloc.add(const ClearHomeSections());
                return;
              }

              final activePluginId = _homeContentBloc.state.activePluginId;
              if (activePluginId != null &&
                  !state.loadedPluginIds.contains(activePluginId)) {
                // Active plugin was unloaded — reload from preferred.
                _homeContentBloc.add(const ClearHomeSections());
                _tryLoadHomeSections();
                return;
              }

              // Plugin list changed — check if preferred plugin is different.
              _tryLoadHomeSections();
            },
          ),
          BlocListener<ConnectivityCubit, ConnectivityState>(
            listenWhen: (previous, current) =>
                previous == ConnectivityState.disconnected &&
                current == ConnectivityState.connected,
            listener: (context, state) {
              final now = DateTime.now();
              if (_lastReconnectRefreshTime != null &&
                  now.difference(_lastReconnectRefreshTime!) <
                      const Duration(seconds: 5)) {
                return; // Debounce rapid connectivity flip-flops
              }
              _lastReconnectRefreshTime = now;
              _handleRefresh(isAutoReconnect: true);
            },
          ),
        ],
        child: Scaffold(
          body: RefreshIndicator(
            onRefresh: () => _handleRefresh(isAutoReconnect: false),
            child: CustomScrollView(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                const CustomDiscoverBar(),
                SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      CaraouselWidget(
                        key: _carouselKey,
                        onFestiveTap: _scrollToFestiveSpecial,
                      ),
                      // 2. Recently Played directly beneath the carousel
                      Padding(
                        padding: const EdgeInsets.only(top: 15.0),
                        child: BlocBuilder<RecentlyCubit, RecentlyCubitState>(
                          builder: (context, state) {
                            if (state is RecentlyCubitInitial) {
                              return const Center(
                                child: SizedBox(
                                  height: 60,
                                  width: 60,
                                  child: CircularProgressIndicator(
                                    color: Default_Theme.accentColor2,
                                  ),
                                ),
                              );
                            }
                            if (state.tracks.isNotEmpty) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0, vertical: 4.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          AppLocalizations.of(context)!
                                              .exploreRecently,
                                          style: Default_Theme.primaryTextStyle
                                              .merge(
                                            const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  Default_Theme.primaryColor1,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const HistoryView(),
                                              ),
                                            );
                                          },
                                          child: const Text(
                                            'See All',
                                            style: TextStyle(
                                              color: Default_Theme.accentColor2,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TabSongListWidget(
                                    list: state.tracks.map((e) {
                                      return SongCardWidget(
                                        song: e,
                                        onTap: () {
                                          context
                                              .read<OrviaPlayerCubit>()
                                              .orviaPlayer
                                              .loadPlaylist(
                                                Playlist(
                                                  tracks: state.tracks,
                                                  title: 'Recently',
                                                ),
                                                idx: state.tracks.indexOf(e),
                                                doPlay: true,
                                              );
                                        },
                                        onOptionsTap: () => showMoreBottomSheet(
                                          context,
                                          e,
                                          showSinglePlay: true,
                                          showRemoveFromHistory: true,
                                          onRemoveFromHistory: () {
                                            context
                                                .read<RecentlyCubit>()
                                                .removeTrack(e.id);
                                            SnackbarService.showMessage(
                                                'Removed from Recently Played');
                                          },
                                        ),
                                      );
                                    }).toList(),
                                    category: '',
                                    columnSize: 3,
                                  ),
                                ],
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      BlocBuilder<SettingsCubit, SettingsState>(
                        builder: (context, state) {
                          if (state.lFMPicks) {
                            return FutureBuilder(
                              future: fetchLFMPicks(state.lFMPicks, context),
                              builder: (context, snapshot) {
                                if (snapshot.hasData &&
                                    (snapshot.data?.isNotEmpty ?? false)) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 15.0),
                                    child: TabSongListWidget(
                                      list: snapshot.data!.map((e) {
                                        return SongCardWidget(
                                          song: e,
                                          onTap: () {
                                            context
                                                .read<OrviaPlayerCubit>()
                                                .orviaPlayer
                                                .loadPlaylist(
                                                  Playlist(
                                                    tracks: snapshot.data!,
                                                    title: 'Last.Fm Picks',
                                                  ),
                                                  idx: snapshot.data!.indexOf(e),
                                                  doPlay: true,
                                                );
                                          },
                                          onOptionsTap: () =>
                                              showMoreBottomSheet(
                                                  context,
                                                  showSinglePlay: true,
                                                  e),
                                        );
                                      }).toList(),
                                      category: AppLocalizations.of(context)!
                                          .exploreLastFmPicks,
                                      columnSize: 3,
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      // 3-13. Master homepage structured sections
                      BlocBuilder<PluginBloc, PluginState>(
                        builder: (context, pluginState) {
                          final resolvers = pluginState.loadedContentResolvers;
                          if (resolvers.isEmpty) {
                            return const SignBoardWidget(
                              message:
                                  'No content plugin loaded.\nLoad a Content Resolver in Plugin Manager.',
                              icon: MingCute.plugin_2_line,
                            );
                          }
                          final pluginId = _effectiveHomePluginId(resolvers);

                          return BlocBuilder<ContentBloc, ContentState>(
                            bloc: _homeContentBloc,
                            builder: (context, state) {
                              final sections = state.homeSections ?? const [];
                              return _StructuredHomeSections(
                                pluginId: pluginId,
                                sections: sections,
                                contentBloc: _homeContentBloc,
                                state: state,
                                festiveSectionKey: _festiveSectionKey,
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: Default_Theme.themeColor,
        ),
      ),
    );
  }
}

/// Structured layout enforcing normal homepage ordering:
/// 3. Trending Now (only once)
/// 4. New Releases
/// 5. What's Hot Near You
/// 6. Indian First Discovery
/// 7. Iconic Indian Artists
/// 8. Festive Special (with automatic schedule promotion)
/// 9. Best of 90s and year-based collections (2025, 2026)
/// 10. Additional regular discovery, genre and mood sections
/// 11. Bhakti & Spiritual
/// 12. Instrumental Discovery
/// 13. Radio/stations and remaining sections
class _StructuredHomeSections extends StatelessWidget {
  final String pluginId;
  final List<Section> sections;
  final ContentBloc contentBloc;
  final ContentState state;
  final GlobalKey festiveSectionKey;

  const _StructuredHomeSections({
    required this.pluginId,
    required this.sections,
    required this.contentBloc,
    required this.state,
    required this.festiveSectionKey,
  });

  @override
  Widget build(BuildContext context) {
    // Partition sections cleanly
    final trending = sections.firstWhereOrNull(
        (s) => s.title.toLowerCase().contains('trend'));
    final newReleases = sections.firstWhereOrNull((s) =>
        s != trending &&
        (s.title.toLowerCase().contains('new') ||
            s.title.toLowerCase().contains('release') ||
            s.title.toLowerCase().contains('album')));
    final radio = sections
        .where((s) =>
            s.title.toLowerCase().contains('radio') ||
            s.title.toLowerCase().contains('station'))
        .toList();
    final otherSections = sections
        .where((s) => s != trending && s != newReleases && !radio.contains(s))
        .toList();

    final activeFestival = FestivalService.getActiveOrUpcomingFestival();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 3. Trending Now — only once
        if (trending != null) ...[
          const SizedBox(height: 10),
          _HomeSectionCard(
            section: trending,
            contentBloc: contentBloc,
            state: state,
          ),
        ] else if (state.homeSectionsStatus == DetailStatus.loading) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Default_Theme.accentColor2,
                ),
              ),
            ),
          ),
        ],

        // 4. New Releases
        if (newReleases != null) ...[
          const SizedBox(height: 10),
          _HomeSectionCard(
            section: newReleases,
            contentBloc: contentBloc,
            state: state,
          ),
        ],

        // 5. What's Hot Near You
        const SizedBox(height: 14),
        WhatsHotNearYouSection(pluginId: pluginId),

        // 6. Indian First Discovery
        const SizedBox(height: 14),
        IndianBrowseCategories(pluginId: pluginId),

        // 7. Iconic Indian Artists
        const SizedBox(height: 14),
        FeaturedArtistsSection(pluginId: pluginId),

        // 8. Festive Special (Automatic 10-day promotion window)
        if (activeFestival != null) ...[
          const SizedBox(height: 14),
          KeyedSubtree(
            key: festiveSectionKey,
            child: const NavratriSpecialSection(),
          ),
        ],

        // 9. Best of 90s and year-based collections (2025, 2026)
        const SizedBox(height: 14),
        YearCollectionsSection(pluginId: pluginId),

        // 10. Additional regular discovery, genre and mood sections
        for (final sec in otherSections) ...[
          const SizedBox(height: 10),
          _HomeSectionCard(
            section: sec,
            contentBloc: contentBloc,
            state: state,
          ),
        ],

        // 11. Bhakti & Spiritual
        const SizedBox(height: 14),
        BhaktiSpiritualSection(pluginId: pluginId),

        // 12. Instrumental Discovery
        const SizedBox(height: 14),
        InstrumentalSection(pluginId: pluginId),

        // 13. Radio/stations and remaining sections
        for (final sec in radio) ...[
          const SizedBox(height: 10),
          _HomeSectionCard(
            section: sec,
            contentBloc: contentBloc,
            state: state,
          ),
        ],
      ],
    );
  }
}

class _HomeSectionCard extends StatelessWidget {
  final Section section;
  final ContentBloc contentBloc;
  final ContentState state;

  const _HomeSectionCard({
    required this.section,
    required this.contentBloc,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 275,
      child: HorizontalCardView(
        section: section,
        pluginId: contentBloc.state.activePluginId ?? '',
        canLoadMore: section.moreLink != null,
        isLoadingMore: state.isHomeSectionLoading(section.id),
        onLoadMore: section.moreLink == null
            ? null
            : () {
                contentBloc.add(
                  LoadMoreHomeSectionItems(
                    pluginId: contentBloc.state.activePluginId ?? '',
                    sectionId: section.id,
                    moreLink: section.moreLink!,
                  ),
                );
              },
      ),
    );
  }
}

class CustomDiscoverBar extends StatelessWidget {
  const CustomDiscoverBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      surfaceTintColor: Default_Theme.themeColor,
      backgroundColor: Default_Theme.themeColor,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            AppLocalizations.of(context)!.exploreDiscover,
            style: Default_Theme.primaryTextStyle.merge(
              const TextStyle(
                fontSize: 34,
                color: Default_Theme.primaryColor1,
              ),
            ),
          ),
          const Spacer(),
          const NotificationIcon(),
          const SiteIcon(),
          const TimerIcon(),
          const SettingsIcon(),
        ],
      ),
    );
  }
}

class NotificationIcon extends StatelessWidget {
  const NotificationIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationCubit, NotificationState>(
      builder: (context, state) {
        if (state is NotificationInitial || state.notifications.isEmpty) {
          return IconButton(
            padding: const EdgeInsets.all(5),
            constraints: const BoxConstraints(),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationView(),
                ),
              );
            },
            icon: const Icon(
              MingCute.notification_line,
              color: Default_Theme.primaryColor1,
              size: 30.0,
            ),
          );
        }
        return badges.Badge(
          badgeContent: Padding(
            padding: const EdgeInsets.all(1.5),
            child: Text(
              state.notifications.length.toString(),
              style: Default_Theme.primaryTextStyle.merge(
                const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Default_Theme.primaryColor2,
                ),
              ),
            ),
          ),
          badgeStyle: const badges.BadgeStyle(
            badgeColor: Default_Theme.accentColor2,
            shape: badges.BadgeShape.circle,
          ),
          position: badges.BadgePosition.topEnd(top: -10, end: -5),
          child: IconButton(
            padding: const EdgeInsets.all(5),
            constraints: const BoxConstraints(),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationView(),
                ),
              );
            },
            icon: const Icon(
              MingCute.notification_line,
              color: Default_Theme.primaryColor1,
              size: 30.0,
            ),
          ),
        );
      },
    );
  }
}

class TimerIcon extends StatelessWidget {
  const TimerIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: const EdgeInsets.all(5),
      constraints: const BoxConstraints(),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TimerView()),
        );
      },
      icon: const Icon(
        MingCute.stopwatch_line,
        color: Default_Theme.primaryColor1,
        size: 30.0,
      ),
    );
  }
}

class SettingsIcon extends StatelessWidget {
  const SettingsIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: const EdgeInsets.all(5),
      constraints: const BoxConstraints(),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsView()),
        );
      },
      icon: const Icon(
        MingCute.settings_3_line,
        color: Default_Theme.primaryColor1,
        size: 30.0,
      ),
    );
  }
}

class SiteIcon extends StatelessWidget {
  const SiteIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: const EdgeInsets.all(5),
      constraints: const BoxConstraints(),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const About()),
        );
      },
      icon: const Icon(
        MingCute.flower_4_fill,
        color: Default_Theme.primaryColor1,
        size: 28.0,
      ),
    );
  }
}

