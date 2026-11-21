import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:Orvia/screens/widgets/navratri_special_card.dart';
import 'package:Orvia/services/festival/festival_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    FestivalService.setMockRemoteEvents(null);
  });

  test('Navratri category expires exactly at midnight IST', () {
    final justBeforeExpiry = DateTime.utc(2026, 10, 20, 18, 29, 59);
    final expiry = DateTime.utc(2026, 10, 20, 18, 30);

    expect(
      FestivalService.getActiveOrUpcomingFestival(
        testTime: justBeforeExpiry,
      )?.id,
      'navratri_2026',
    );
    expect(
      FestivalService.getActiveOrUpcomingFestival(testTime: expiry),
      isNull,
    );
  });

  test('Diwali category activates and expires at exact IST boundaries', () {
    final start = DateTime.utc(2026, 11, 4, 18, 30);
    final end = DateTime.utc(2026, 11, 11, 18, 30);

    expect(
      FestivalService.getActiveOrUpcomingFestival(
        testTime: start.subtract(const Duration(seconds: 1)),
      ),
      isNull,
    );
    expect(
      FestivalService.getActiveOrUpcomingFestival(testTime: start)?.id,
      'diwali_2026',
    );
    expect(
      FestivalService.getActiveOrUpcomingFestival(testTime: end),
      isNull,
    );
    expect(
      FestivalService.nextDateBoundary(
          testTime: end.subtract(const Duration(seconds: 1))),
      end,
    );
  });

  test('embedded Diwali catalogue has 15 unique provider recordings', () {
    final event = FestivalService.getActiveOrUpcomingFestival(
      testTime: DateTime.utc(2026, 11, 5, 18, 30),
    );
    final ids = event!.tracks.map((track) => track.id).toSet();

    expect(event.id, 'diwali_2026');
    expect(event.tracks, hasLength(15));
    expect(ids, hasLength(15));
    expect(
      ids,
      containsAll([
        '${FestivalService.pluginId}::6EIDGV-w',
        '${FestivalService.pluginId}::_8OlmfDF',
        '${FestivalService.pluginId}::q3ElTqvW',
        '${FestivalService.pluginId}::dBM1AsPC',
        '${FestivalService.pluginId}::8YZi9g27',
        '${FestivalService.pluginId}::3PVqxbZf',
      ]),
    );
    expect(
      event.tracks.every((track) =>
          track.durationMs != null &&
          track.durationMs! > BigInt.zero &&
          track.thumbnail.url.startsWith('https://')),
      isTrue,
    );
  });

  test('remote timezone-offset schedule works independently of device zone',
      () async {
    final response = {
      'festivals': [
        {
          'id': 'diwali_2026',
          'name': 'Diwali Dhamaka',
          'startDate': '2026-11-05T00:00:00+05:30',
          'endDate': '2026-11-12T00:00:00+05:30',
          'promotionDays': 0,
          'tracks': [
            {
              'rawId': 'remote-track',
              'title': 'Remote track',
              'artist': 'Remote artist',
              'album': 'Remote album',
              'durationSec': 60,
              'imageUrl': 'https://example.com/artwork.jpg',
            }
          ],
        }
      ]
    };
    final client =
        MockClient((_) async => http.Response(jsonEncode(response), 200));
    await FestivalService.refreshRemoteScheduleWithClient(
      force: true,
      client: client,
    );

    expect(
      FestivalService.getActiveOrUpcomingFestival(
        testTime: DateTime.utc(2026, 11, 4, 18, 30),
      )?.tracks.single.id,
      '${FestivalService.pluginId}::remote-track',
    );
    expect(
      FestivalService.getActiveOrUpcomingFestival(
        testTime: DateTime.utc(2026, 11, 11, 18, 30),
      ),
      isNull,
    );
  });

  test('remote refresh accepts an explicit empty schedule', () async {
    FestivalService.setMockRemoteEvents([]);
    final client =
        MockClient((_) async => http.Response('{"festivals":[]}', 200));

    await FestivalService.refreshRemoteScheduleWithClient(
      force: true,
      client: client,
    );

    expect(
      FestivalService.getActiveOrUpcomingFestival(
        testTime: DateTime.utc(2026, 11, 5),
      ),
      isNull,
    );
  });

  testWidgets('Diwali destination has its own section, not Navratri tracks',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DiwaliSpecialSection(tracks: []),
        ),
      ),
    );

    expect(find.text('Diwali Festive Special'), findsOneWidget);
    expect(find.textContaining('No unverified tracks have been added'),
        findsOneWidget);
    expect(find.textContaining('Navratri Special'), findsNothing);
  });

  test('Diwali track list deduplicates repeated provider IDs', () {
    final track = kVerifiedNavratriTracks.first.track;

    expect(
      deduplicateFestivalTracks([track, track]).map((item) => item.id),
      [track.id],
    );
  });
}
