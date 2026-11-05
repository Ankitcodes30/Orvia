import 'dart:convert';

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

  test('Diwali 2026 feature is active during Diwali promotion window with 19 tracks', () {
    final duringDiwali = DateTime.utc(2026, 11, 6, 12, 0);
    final event = FestivalService.getActiveOrUpcomingFestival(testTime: duringDiwali);
    expect(event, isNotNull);
    expect(event!.id, 'diwali_2026');
    expect(event.tracks.length, 19);
  });

  test('remote timezone-offset schedule works independently of device zone',
      () async {
    final response = {
      'festivals': [
        {
          'id': 'test_special_2026',
          'name': 'Special Festive Event',
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

  test('Festival track list deduplicates repeated provider IDs', () {
    final track = kVerifiedNavratriTracks.first.track;

    expect(
      deduplicateFestivalTracks([track, track]).map((item) => item.id),
      [track.id],
    );
  });
}
