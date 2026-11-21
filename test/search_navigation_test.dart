import 'package:flutter_test/flutter_test.dart';
import 'package:Orvia/routes/search_navigation.dart';

void main() {
  group('Search navigation input', () {
    test('prefill query is decoded and remains unsubmitted', () {
      const query = 'Mata Rani & Lakshmi + 100% Bhakti 🎵';
      final uri = Uri(
        path: '/Search',
        queryParameters: {'prefill': query},
      );

      expect(
        SearchNavigation.routeInput(uri),
        (query: query, submit: false),
      );
    });

    test('existing query parameter remains an immediate search request', () {
      const query = 'Arijit Singh & Friends';
      final uri = Uri(
        path: '/Search',
        queryParameters: {'query': query},
      );

      expect(
        SearchNavigation.routeInput(uri),
        (query: query, submit: true),
      );
    });

    test('submitted query takes precedence when both parameters are present',
        () {
      final uri = Uri(
        path: '/Search',
        queryParameters: {'query': 'submitted', 'prefill': 'draft'},
      );

      expect(
        SearchNavigation.routeInput(uri),
        (query: 'submitted', submit: true),
      );
    });
  });
}
