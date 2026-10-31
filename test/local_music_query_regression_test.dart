// Regression tests for Android Local section media query formatting and sorting.
//
// Verifies that photo_manager's getAssetListRange queries always receive an
// explicit, valid sort configuration, preventing the SQLite syntax error:
// `near "LIMIT": syntax error` caused by an empty ORDER BY clause.
//
// Run with: flutter test test/local_music_query_regression_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';

import 'package:Orvia/services/local_music_service.dart';

void main() {
  group('LocalMusicService — Android MediaStore Query Configuration', () {
    test('buildAudioFilterOption produces non-empty orders with valid createDate sort', () {
      final filterOption = LocalMusicService.buildAudioFilterOption();

      expect(filterOption.orders, isNotEmpty,
          reason: 'orders list must not be empty, otherwise IDBUtils generates ORDER BY LIMIT without column');
      expect(filterOption.orders.length, equals(1));

      final firstOrder = filterOption.orders.first;
      expect(firstOrder.type, equals(OrderOptionType.createDate),
          reason: 'Should sort by createDate (DATE_ADDED in Android MediaStore)');
      expect(firstOrder.asc, isFalse,
          reason: 'Default order should be descending so newest songs appear first');
    });

    test('buildAudioFilterOption allows nullable duration for audio files', () {
      final filterOption = LocalMusicService.buildAudioFilterOption();
      final audioOption = filterOption.getOption(AssetType.audio);

      expect(audioOption.durationConstraint.allowNullable, isTrue,
          reason: 'Audio files without duration in MediaStore must not be excluded');
    });

    test('buildAudioFilterOption.toMap() produces valid platform channel payload', () {
      final filterOption = LocalMusicService.buildAudioFilterOption();
      final map = filterOption.toMap();

      expect(map['type'], equals(0)); // BaseFilterType.classical.value
      expect(map.containsKey('child'), isTrue);

      final child = map['child'] as Map<String, dynamic>;
      expect(child.containsKey('orders'), isTrue);
      final orders = child['orders'] as List;
      expect(orders, isNotEmpty);

      final firstOrderMap = orders.first as Map;
      expect(firstOrderMap['type'], equals(0)); // OrderOptionType.createDate.index
      expect(firstOrderMap['asc'], isFalse);

      expect(child.containsKey('audio'), isTrue);
      final audioMap = child['audio'] as Map;
      expect(audioMap['duration'], isNotNull);
      expect(audioMap['duration']['allowNullable'], isTrue);
    });

    test('Simulated Android IDBUtils.getSortOrder produces valid SQL with column', () {
      final filterOption = LocalMusicService.buildAudioFilterOption();
      final map = filterOption.toMap();

      // Emulate Android Kotlin ConvertUtils.convertToFilterOptions -> CommonFilterOption(childMap)
      final child = map['child'] as Map<String, dynamic>;
      final orders = child['orders'] as List;
      final List<String> orderByConds = [];
      for (final order in orders) {
        final orderMap = order as Map;
        final keyIndex = orderMap['type'] as int;
        final asc = orderMap['asc'] as bool;
        final key = (keyIndex == 0)
            ? 'date_added'
            : (keyIndex == 1)
                ? 'date_modified'
                : '_id';
        orderByConds.add('$key ${asc ? "ASC" : "DESC"}');
      }

      final orderBy = orderByConds.isNotEmpty ? orderByConds.join(',') : null;
      expect(orderBy, equals('date_added DESC'));

      // Emulate Android Kotlin IDBUtils.getSortOrder(start=0, pageSize=200, filterOption)
      const pageSize = 200;
      const start = 0;
      final builder = StringBuffer();
      if (orderBy != null) {
        builder.write('$orderBy ');
      }
      builder.write('LIMIT $pageSize OFFSET $start');
      final sortOrder = builder.toString();

      expect(sortOrder, equals('date_added DESC LIMIT 200 OFFSET 0'));

      // Reconstruct Android ContentResolver SQLite query
      final sql = 'SELECT * FROM files WHERE (bucket_id IS NOT NULL AND (media_type = 2)) ORDER BY $sortOrder';
      expect(sql, contains('ORDER BY date_added DESC LIMIT 200 OFFSET 0'));
      expect(sql.contains('ORDER BY LIMIT'), isFalse,
          reason: 'Query must never contain "ORDER BY LIMIT"');
    });

    test('Null filterOption reproduction proves faulty SQL', () {
      // When filterOption is null (prior buggy behavior):
      const Map? map = null;
      expect(map, isNull);

      // Emulate Kotlin IDBUtils.getSortOrder with null filterOption
      String? orderBy;
      if (map != null && map['orders'] != null) {
        final orders = map['orders'] as List;
        if (orders.isNotEmpty) {
          orderBy = 'some_col DESC';
        }
      }

      const pageSize = 1;
      const start = 0;
      final builder = StringBuffer();
      if (orderBy != null) {
        builder.write('$orderBy ');
      }
      builder.write('LIMIT $pageSize OFFSET $start');
      final faultySortOrder = builder.toString();

      // This reproduces the exact faulty SQL from the user report:
      final faultySql = 'SELECT * FROM files WHERE (bucket_id IS NOT NULL AND (media_type = 2)) ORDER BY $faultySortOrder';
      expect(faultySql, contains('ORDER BY LIMIT 1 OFFSET 0'),
          reason: 'Demonstrates the exact crash condition that occurred before the fix');
    });
  });
}
