import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:Orvia/core/constants/route_paths.dart';

typedef SearchRouteInput = ({String query, bool submit});

class SearchNavigation {
  SearchNavigation._();

  static SearchRouteInput routeInput(Uri uri) {
    final query = uri.queryParameters['query'];
    if (query != null) {
      return (query: query, submit: true);
    }
    return (query: uri.queryParameters['prefill'] ?? '', submit: false);
  }

  static void openWithPrefill(BuildContext context, String query) {
    context.pushNamed(
      RoutePaths.searchScreen,
      queryParameters: {'prefill': query},
    );
  }
}
