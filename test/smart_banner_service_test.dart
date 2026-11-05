import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:Orvia/services/banner/smart_banner_service.dart';
import 'package:Orvia/screens/widgets/smart_sliding_banners.dart';

void main() {
  tearDown(() {
    SmartBannerService.setMockRemoteBanners(null);
  });

  test('uses GitHub Pages banners and falls back to raw ghpage on HTTP error',
      () async {
    final requestedUrls = <Uri>[];
    final client = MockClient((request) async {
      requestedUrls.add(request.url);
      if (request.url.toString() == SmartBannerService.remoteConfigUrl) {
        return http.Response('Unavailable', 503);
      }
      if (request.url.toString() == SmartBannerService.remoteFallbackUrl) {
        return http.Response(
          '''
          {
            "banners": [{
              "id": "remote-test",
              "title": "Remote Test",
              "tracks": [{
                "rawId": "test-track",
                "title": "Test Track",
                "artist": "Test Artist",
                "durationSec": 180
              }]
            }]
          }
          ''',
          200,
        );
      }
      return http.Response('Unexpected URL', 404);
    });

    await SmartBannerService.refreshRemoteBanners(force: true, client: client);

    expect(SmartBannerService.remoteConfigUrl,
        'https://ankitcodes30.github.io/Orvia/banners.json');
    expect(SmartBannerService.remoteFallbackUrl,
        'https://raw.githubusercontent.com/Ankitcodes30/Orvia/ghpage/banners.json');
    expect(requestedUrls, [
      Uri.parse(SmartBannerService.remoteConfigUrl),
      Uri.parse(SmartBannerService.remoteFallbackUrl),
    ]);
    expect(SmartBannerService.getActiveBanners().any((b) => b.title == 'Remote Test'), isTrue);
  });

  test('keeps embedded banners when both remote endpoints are offline',
      () async {
    SmartBannerService.setMockRemoteBanners(null);
    final requestedUrls = <Uri>[];
    final client = MockClient((request) async {
      requestedUrls.add(request.url);
      throw const SocketException('Offline');
    });

    await SmartBannerService.refreshRemoteBanners(force: true, client: client);

    expect(requestedUrls, [
      Uri.parse(SmartBannerService.remoteConfigUrl),
      Uri.parse(SmartBannerService.remoteFallbackUrl),
    ]);
    expect(SmartBannerService.getActiveBanners(testTime: DateTime(2026, 10, 21, 8, 0)), isNotEmpty);
  });

  test("embedded banners exclude What's Hot and only include approved collections", () {
    final active = SmartBannerService.getActiveBanners(
      testTime: DateTime.utc(2026, 10, 19, 12),
    );

    expect(
      active.any((banner) => banner.id == 'whats_hot'),
      isFalse,
      reason: "What's Hot must be completely excluded from embedded active banners",
    );
  });

  test("source and website configs exclude What's Hot and preserve festival configs",
      () async {
    final sourceJson = jsonDecode(await File('banners.json').readAsString())
        as Map<String, dynamic>;
    final websiteJson =
        jsonDecode(await File('ghpage/static/banners.json').readAsString())
            as Map<String, dynamic>;
    final sourceBanners = sourceJson['banners'] as List<dynamic>;

    expect(websiteJson, equals(sourceJson));
    expect(
      sourceBanners.cast<Map<String, dynamic>>().any((b) => b['id'] == 'whats_hot'),
      isFalse,
      reason: "What's Hot must be completely removed from banners.json",
    );
    expect(
      sourceBanners.cast<Map<String, dynamic>>().any((b) => b['id'] == 'navratri_special_2026'),
      isFalse,
      reason: "Navratri Festive Special 2026 must be removed from banners.json",
    );
    expect(
      sourceBanners.cast<Map<String, dynamic>>().any((b) => b['id'] == 'night_calm'),
      isFalse,
      reason: "Night Calm must be completely removed from banners.json",
    );

    expect(
      sourceBanners.cast<Map<String, dynamic>>().any((b) => b['id'] == 'diwali_festive_2026'),
      isFalse,
      reason: "Diwali must be completely removed from banners.json",
    );
  });

  test('festival banner starts inclusively and expires at the end instant', () {
    final banner = SmartBannerItem(
      id: 'scheduled-festival',
      title: 'Scheduled Festival',
      subtitle: '',
      badge: 'FESTIVE',
      imageUrl: '',
      gradientColors: const [],
      tracks: const [],
      activeHours: List.generate(24, (hour) => hour),
      priority: 100,
      startDate: DateTime.utc(2026, 10, 1),
      endDate: DateTime.utc(2026, 10, 2, 23, 59, 59),
    );
    SmartBannerService.setMockRemoteBanners([banner]);

    expect(
      SmartBannerService.getActiveBanners(
        testTime: DateTime.utc(2026, 9, 30, 23, 59, 59),
      ).any((item) => item.id == banner.id),
      isFalse,
    );
    expect(
      SmartBannerService.getActiveBanners(
        testTime: banner.startDate!,
      ).any((item) => item.id == banner.id),
      isTrue,
    );
    expect(
      SmartBannerService.getActiveBanners(
        testTime: banner.endDate!,
      ).any((item) => item.id == banner.id),
      isFalse,
    );
    expect(
      SmartBannerService.getActiveBanners(
        testTime: banner.endDate!.add(const Duration(microseconds: 1)),
      ).any((item) => item.id == banner.id),
      isFalse,
    );
    expect(
      SmartBannerService.nextDateBoundary(
        testTime: DateTime.utc(2026, 9, 30, 23, 59, 59),
      ),
      equals(banner.startDate),
    );
    expect(
      SmartBannerService.nextDateBoundary(
        testTime: banner.endDate!.subtract(const Duration(microseconds: 1)),
      ),
      equals(banner.endDate),
    );
  });

  test('timezone-offset schedule timestamps compare by absolute instant', () {
    final banner = SmartBannerItem.fromJson({
      'id': 'timezone-festival',
      'startDate': '2026-10-01T00:00:00+05:30',
      'endDate': '2026-10-02T23:59:59+05:30',
      'activeHours': List.generate(24, (hour) => hour),
      'tracks': [
        {'rawId': 'track-1', 'title': 'Track'}
      ],
    });

    expect(
      banner.isEligibleAt(0, DateTime.utc(2026, 9, 30, 18, 30)),
      isTrue,
    );
    expect(
      banner.isEligibleAt(0, DateTime.utc(2026, 9, 30, 18, 29, 59)),
      isFalse,
    );
    expect(
      () => SmartBannerItem.fromJson({
        'id': 'timezone-missing',
        'startDate': '2026-10-01T00:00:00',
        'tracks': [
          {'rawId': 'track-1', 'title': 'Track'}
        ],
      }),
      throwsFormatException,
    );
  });

  test('Diwali banner is permanently disallowed and blocked from active banners', () {
    expect(SmartBannerService.kDisallowedBannerIds.contains('diwali_festive_2026'), isTrue);
    final banner = SmartBannerItem.fromJson({
      'id': 'diwali_festive_2026',
      'title': 'Diwali Festive Special',
      'startDate': '2026-11-05T00:00:00+05:30',
      'endDate': '2026-11-12T00:00:00+05:30',
      'activeHours': List.generate(24, (hour) => hour),
      'destination': 'festival_special',
      'tracks': [],
    });
    SmartBannerService.setMockRemoteBanners([banner]);

    expect(
      SmartBannerService.getActiveBanners(
        testTime: DateTime.utc(2026, 11, 4, 18, 30),
      ).any((item) => item.id == banner.id),
      isFalse,
    );
  });

  test('Navratri banner expires at 2026-10-21 00:00 IST', () {
    final banner = SmartBannerItem.fromJson({
      'id': 'navratri_special_2026',
      'startDate': '2026-09-25T00:00:00Z',
      'endDate': '2026-10-21T00:00:00+05:30',
      'activeHours': List.generate(24, (hour) => hour),
      'tracks': [
        {'rawId': 'navratri-track', 'title': 'Garba'}
      ],
    });

    expect(
      banner.isEligibleAt(0, DateTime.utc(2026, 10, 20, 18, 29, 59)),
      isTrue,
    );
    expect(
      banner.isEligibleAt(0, DateTime.utc(2026, 10, 20, 18, 30)),
      isFalse,
    );
  });

  test('remote refresh retains destination banners, filters expired ones, and disallows diwali',
      () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'banners': [
              {
                'id': 'festive_special_active',
                'title': 'Festive Special',
                'startDate': '2026-11-05T00:00:00+05:30',
                'endDate': '2026-11-12T00:00:00+05:30',
                'destination': 'festival_special',
                'priority': 100,
                'tracks': [],
              },
              {
                'id': 'diwali_festive_2026',
                'title': 'Diwali Festive Special',
                'startDate': '2026-11-05T00:00:00+05:30',
                'endDate': '2026-11-12T00:00:00+05:30',
                'destination': 'festival_special',
                'priority': 100,
                'tracks': [],
              }
            ]
          }),
          200,
        ));
    await SmartBannerService.refreshRemoteBanners(
      force: true,
      client: client,
    );

    expect(
      SmartBannerService.getActiveBanners(
        testTime: DateTime.utc(2026, 11, 4, 18, 30),
      ).map((banner) => banner.id),
      contains('festive_special_active'),
    );
    expect(
      SmartBannerService.getActiveBanners(
        testTime: DateTime.utc(2026, 11, 4, 18, 30),
      ).map((banner) => banner.id),
      isNot(contains('diwali_festive_2026')),
    );
    expect(
      SmartBannerService.getActiveBanners(
        testTime: DateTime.utc(2026, 11, 11, 18, 30),
      ).map((banner) => banner.id),
      isNot(contains('festive_special_active')),
    );
  });

  testWidgets('Festival banner tap invokes the festival-section navigation',
      (tester) async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'banners': [
              {
                'id': 'test_festive_banner',
                'title': 'Festive Special',
                'subtitle': 'Lights and music',
                'destination': 'festival_special',
                'priority': 100,
                'tracks': [],
              }
            ]
          }),
          200,
        ));
    await SmartBannerService.refreshRemoteBanners(
      force: true,
      client: client,
    );
    var navigated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartSlidingBanners(
            pluginId: 'test-provider',
            onFestivalTap: () => navigated = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Festive Special').first);
    await tester.pump();

    expect(navigated, isTrue);
  });

  test('expired in-memory remote schedule stays expired after refresh failure',
      () async {
    final banner = SmartBannerItem(
      id: 'cached-expired-festival',
      title: 'Cached expired festival',
      subtitle: '',
      badge: 'FESTIVE',
      imageUrl: '',
      gradientColors: const [],
      tracks: const [],
      activeHours: List.generate(24, (hour) => hour),
      priority: 100,
      startDate: DateTime.utc(2026, 10, 1),
      endDate: DateTime.utc(2026, 10, 2, 23, 59, 59),
    );
    SmartBannerService.setMockRemoteBanners([banner]);
    final client = MockClient((_) async {
      throw const SocketException('Offline');
    });

    await SmartBannerService.refreshRemoteBanners(
      force: true,
      client: client,
    );

    expect(
      SmartBannerService.getActiveBanners(
        testTime: DateTime.utc(2026, 10, 3),
      ).any((item) => item.id == banner.id),
      isFalse,
    );
  });

  test('valid empty remote config removes prior cached banners', () async {
    final banner = SmartBannerItem(
      id: 'removed-festival',
      title: 'Removed festival',
      subtitle: '',
      badge: 'FESTIVE',
      imageUrl: '',
      gradientColors: const [],
      tracks: const [],
      activeHours: List.generate(24, (hour) => hour),
      priority: 100,
    );
    SmartBannerService.setMockRemoteBanners([banner]);
    final client =
        MockClient((_) async => http.Response('{"banners":[]}', 200));

    await SmartBannerService.refreshRemoteBanners(
      force: true,
      client: client,
    );

    expect(
      SmartBannerService.getActiveBanners(
        testTime: DateTime(2026, 10, 19, 12),
      ).any((item) => item.id == banner.id),
      isFalse,
    );
  });

  test(
      'fresh process has no stale remote festival banner without persisted cache',
      () {
    final banner = SmartBannerItem(
      id: 'process-local-festival',
      title: 'Process-local festival',
      subtitle: '',
      badge: 'FESTIVE',
      imageUrl: '',
      gradientColors: const [],
      tracks: const [],
      activeHours: List.generate(24, (hour) => hour),
      priority: 100,
      startDate: DateTime.utc(2026, 10, 1),
      endDate: DateTime.utc(2026, 10, 2, 23, 59, 59),
    );
    SmartBannerService.setMockRemoteBanners([banner]);

    SmartBannerService.setMockRemoteBanners(null);

    expect(
      SmartBannerService.getActiveBanners(
        testTime: DateTime.utc(2026, 10, 3),
      ).any((item) => item.id == banner.id),
      isFalse,
    );
  });

  group('Morning Bhakti and Gym Energy schedule boundaries', () {
    test('Morning Bhakti schedule boundary behavior (06:00 - 10:30)', () {
      SmartBannerService.setMockRemoteBanners(null);

      // 05:59:59 - before start boundary (ineligible)
      final at559am = SmartBannerService.getActiveBanners(
        testTime: DateTime(2026, 10, 21, 5, 59, 59),
      );
      expect(at559am.any((b) => b.id == 'morning_bhakti'), isFalse);

      // 06:00:00 - start boundary inclusive
      final at6am = SmartBannerService.getActiveBanners(
        testTime: DateTime(2026, 10, 21, 6, 0, 0),
      );
      expect(at6am.any((b) => b.id == 'morning_bhakti'), isTrue);

      // 10:29:59 - before 10:30 AM (eligible)
      final at1029am = SmartBannerService.getActiveBanners(
        testTime: DateTime(2026, 10, 21, 10, 29, 59),
      );
      expect(at1029am.any((b) => b.id == 'morning_bhakti'), isTrue);

      // 10:30:00 - end boundary exclusive (ineligible)
      final at1030am = SmartBannerService.getActiveBanners(
        testTime: DateTime(2026, 10, 21, 10, 30, 0),
      );
      expect(at1030am.any((b) => b.id == 'morning_bhakti'), isFalse);

      // 16:00:00 - during evening, Gym Energy is active; Morning Bhakti is not
      final at4pm = SmartBannerService.getActiveBanners(
        testTime: DateTime(2026, 10, 21, 16, 0, 0),
      );
      expect(at4pm.any((b) => b.id == 'gym_energy'), isTrue);
      expect(at4pm.any((b) => b.id == 'morning_bhakti'), isFalse);
    });

    test('Gym Energy schedule boundary behavior (05:00 - 10:59 and 16:00 - 21:59)', () {
      SmartBannerService.setMockRemoteBanners(null);

      // Morning window: 05:00:00 - 10:59:59
      final at5am = SmartBannerService.getActiveBanners(
        testTime: DateTime(2026, 10, 21, 5, 0, 0),
      );
      expect(at5am.any((b) => b.id == 'gym_energy'), isTrue);

      final at1059am = SmartBannerService.getActiveBanners(
        testTime: DateTime(2026, 10, 21, 10, 59, 59),
      );
      expect(at1059am.any((b) => b.id == 'gym_energy'), isTrue);

      // Evening window: 16:00:00 - 21:59:59
      final at4pm = SmartBannerService.getActiveBanners(
        testTime: DateTime(2026, 10, 21, 16, 0, 0),
      );
      expect(at4pm.any((b) => b.id == 'gym_energy'), isTrue);

      final at959pm = SmartBannerService.getActiveBanners(
        testTime: DateTime(2026, 10, 21, 21, 59, 59),
      );
      expect(at959pm.any((b) => b.id == 'gym_energy'), isTrue);
    });

    test('nextDateBoundary returns hourly boundary for live auto-refresh', () {
      SmartBannerService.setMockRemoteBanners(null);

      final testTime = DateTime(2026, 10, 21, 10, 30, 0);
      final boundary = SmartBannerService.nextDateBoundary(testTime: testTime);

      expect(boundary, isNotNull);
      // The boundary must be the start of the next hour (11:00:00)
      expect(boundary, equals(DateTime(2026, 10, 21, 11, 0, 0)));
    });
  });
}
