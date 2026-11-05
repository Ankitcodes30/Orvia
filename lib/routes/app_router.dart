import 'package:Orvia/core/constants/route_paths.dart';
import 'package:Orvia/screens/widgets/global_footer.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:Orvia/screens/screen/common_views/add_to_playlist_screen.dart';
import 'package:Orvia/screens/screen/explore_screen.dart';
import 'package:Orvia/screens/screen/library_screen.dart';
import 'package:Orvia/screens/screen/library_views/import_media_view.dart';
import 'package:Orvia/screens/screen/library_views/import_process_screen.dart';
import 'package:Orvia/screens/screen/library_views/playlist_screen.dart';
import 'package:Orvia/screens/screen/library_views/liked_albums_screen.dart';
import 'package:Orvia/screens/screen/offline_screen.dart';
import 'package:Orvia/screens/screen/local_music_screen.dart';
import 'package:Orvia/screens/screen/search_screen.dart';
import 'package:Orvia/screens/screen/chart/chart_view.dart';

import 'package:Orvia/services/share/orvia_deep_link_service.dart';
import 'package:Orvia/routes/search_navigation.dart';

/// Canonical app router configuration.
///
/// Use [AppRouter] in new code. The [GlobalRoutes] typedef at the bottom
/// provides backward-compatible access for existing callers.
class AppRouter {
  static final globalRouterKey = GlobalKey<NavigatorState>();
  static final exploreNavigatorKey = GlobalKey<NavigatorState>();
  static final libraryNavigatorKey = GlobalKey<NavigatorState>();

  static final globalRouter = GoRouter(
    initialLocation: '/Explore',
    navigatorKey: globalRouterKey,
    routes: [
      GoRoute(
        path: '/',
        parentNavigatorKey: globalRouterKey,
        redirect: (context, state) {
          final uri = state.uri;
          if (uri.queryParameters.containsKey('id') ||
              uri.queryParameters.containsKey('v') ||
              OrviaDeepLinkService.isDeepLink(uri)) {
            OrviaDeepLinkService.setPendingDeepLink(uri);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              OrviaDeepLinkService.handleDeepLinkUri(uri);
            });
          }
          return '/Explore';
        },
      ),
      GoRoute(
        path: '/Orvia',
        parentNavigatorKey: globalRouterKey,
        redirect: (context, state) {
          final uri = state.uri;
          if (uri.queryParameters.containsKey('id') ||
              uri.queryParameters.containsKey('v') ||
              OrviaDeepLinkService.isDeepLink(uri)) {
            OrviaDeepLinkService.setPendingDeepLink(uri);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              OrviaDeepLinkService.handleDeepLinkUri(uri);
            });
          }
          return '/Explore';
        },
      ),
      GoRoute(
        path: '/track',
        parentNavigatorKey: globalRouterKey,
        redirect: (context, state) {
          OrviaDeepLinkService.setPendingDeepLink(state.uri);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            OrviaDeepLinkService.handleDeepLinkUri(state.uri);
          });
          return '/Explore';
        },
      ),
      GoRoute(
        path: '/Orvia/track',
        parentNavigatorKey: globalRouterKey,
        redirect: (context, state) {
          OrviaDeepLinkService.setPendingDeepLink(state.uri);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            OrviaDeepLinkService.handleDeepLinkUri(state.uri);
          });
          return '/Explore';
        },
      ),
      GoRoute(
        path: '/playlist',
        parentNavigatorKey: globalRouterKey,
        redirect: (context, state) {
          OrviaDeepLinkService.setPendingDeepLink(state.uri);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            OrviaDeepLinkService.handleDeepLinkUri(state.uri);
          });
          return '/Explore';
        },
      ),
      GoRoute(
        path: '/Orvia/playlist',
        parentNavigatorKey: globalRouterKey,
        redirect: (context, state) {
          OrviaDeepLinkService.setPendingDeepLink(state.uri);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            OrviaDeepLinkService.handleDeepLinkUri(state.uri);
          });
          return '/Explore';
        },
      ),
      GoRoute(
        path: '/AddToPlaylist',
        parentNavigatorKey: globalRouterKey,
        name: RoutePaths.addToPlaylistScreen,
        builder: (context, state) => const AddToPlaylistScreen(),
      ),
      StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              GlobalFooter(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(navigatorKey: exploreNavigatorKey, routes: [
              GoRoute(
                  name: RoutePaths.exploreScreen,
                  path: '/Explore',
                  builder: (context, state) => const ExploreScreen(),
                  routes: [
                    GoRoute(
                        name: RoutePaths.chartScreen,
                        path: 'ChartScreen',
                        builder: (context, state) {
                          final qp = state.uri.queryParameters;
                          return ChartScreen(
                            pluginId: qp['pluginId'] ?? '',
                            chartId: qp['chartId'] ?? '',
                            chartTitle: qp['chartTitle'] ?? 'Chart',
                          );
                        }),
                  ])
            ]),
            StatefulShellBranch(navigatorKey: libraryNavigatorKey, routes: [
              GoRoute(
                  name: RoutePaths.libraryScreen,
                  path: '/Library',
                  builder: (context, state) => const LibraryScreen(),
                  routes: [
                    GoRoute(
                      path: RoutePaths.importMediaFromPlatforms,
                      name: RoutePaths.importMediaFromPlatforms,
                      builder: (context, state) =>
                          const ImportMediaFromPlatformsView(),
                    ),
                    GoRoute(
                      path: RoutePaths.importProcess,
                      name: RoutePaths.importProcess,
                      builder: (context, state) {
                        final pluginId =
                            state.uri.queryParameters['pluginId'] ?? '';
                        return ImportProcessScreen(pluginId: pluginId);
                      },
                    ),
                    GoRoute(
                      name: RoutePaths.playlistView,
                      path: RoutePaths.playlistView,
                      builder: (context, state) {
                        final initialPlaylistName = state.extra as String?;
                        return PlaylistView(
                          initialPlaylistName: initialPlaylistName,
                        );
                      },
                    ),
                    GoRoute(
                      name: RoutePaths.likedAlbumsView,
                      path: RoutePaths.likedAlbumsView,
                      builder: (context, state) => const LikedAlbumsScreen(),
                    ),
                  ]),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                name: RoutePaths.searchScreen,
                path: '/Search',
                builder: (context, state) {
                  final input = SearchNavigation.routeInput(state.uri);
                  return SearchScreen(
                    searchQuery: input.submit ? input.query : '',
                    prefillQuery: input.submit ? '' : input.query,
                  );
                },
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                name: RoutePaths.localMusicScreen,
                path: '/LocalMusic',
                builder: (context, state) => const LocalMusicScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                name: RoutePaths.offlineScreen,
                path: '/Offline',
                builder: (context, state) => const OfflineScreen(),
              ),
            ]),
          ])
    ],
    errorBuilder: (context, state) {
      if (OrviaDeepLinkService.isDeepLink(state.uri) ||
          state.uri.queryParameters.containsKey('id') ||
          state.uri.queryParameters.containsKey('v')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          OrviaDeepLinkService.handleDeepLinkUri(state.uri);
          context.go('/Explore');
        });
      }
      return Scaffold(
        backgroundColor: const Color(0xFF0F0B13),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Colors.white70,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Page Not Found',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.error?.toString() ?? 'The requested page could not be found.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.go('/Explore'),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5252),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
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

/// Backward-compat alias for [AppRouter].
/// Prefer importing from [routes/app_router.dart] and using [AppRouter] directly.
typedef GlobalRoutes = AppRouter;
