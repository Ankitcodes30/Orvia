import 'package:flutter_test/flutter_test.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/plugins/blocs/chart/chart_bloc.dart';

void main() {
  group('Chart artwork refresh', () {
    test('fresh provider artwork takes precedence over stale cached artwork',
        () {
      const chart = ChartSummary(
        id: 'daily',
        title: 'Daily',
        thumbnail: Artwork(
          url: 'https://cdn.example.com/fresh-artwork.jpg',
          layout: ImageLayout.square,
        ),
      );

      final result = preferFreshChartArtwork(
        chart,
        'https://cdn.example.com/stale-artwork.jpg',
      );

      expect(result.thumbnail?.url,
          equals('https://cdn.example.com/fresh-artwork.jpg'));
    });

    test('cached track artwork still enriches a chart without provider artwork',
        () {
      const chart = ChartSummary(id: 'daily', title: 'Daily');

      final result = preferFreshChartArtwork(
        chart,
        'https://cdn.example.com/cached-track-artwork.jpg',
      );

      expect(
        result.thumbnail?.url,
        equals('https://cdn.example.com/cached-track-artwork.jpg'),
      );
    });
  });
}
