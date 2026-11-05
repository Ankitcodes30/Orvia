import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:Orvia/services/banner/smart_banner_service.dart';
import 'package:Orvia/services/catalogue/creators_choice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Reset cached remote banners before each test
    SmartBannerService.setMockRemoteBanners(null);
  });

  tearDown(() {
    SmartBannerService.setMockRemoteBanners(null);
  });

  group("Creator's Choice Banner Visibility & Resilience Tests", () {
    test("1. Remote response containing only Morning Bhakti & Gym Energy preserves Creator's Choice", () async {
      final mockJson = json.encode({
        "version": 1,
        "banners": [
          {
            "id": "morning_bhakti",
            "title": "Morning Bhakti",
            "subtitle": "Sacred Chants & A.K. Music World Piano",
            "badge": "DEVOTIONAL",
            "imageUrl": "https://c.saavncdn.com/034/Beta-Bulaye-Hindi-1998-20230807153827-500x500.jpg",
            "activeHours": [6, 7, 8, 9, 10],
            "priority": 85,
            "tracks": [
              {
                "rawId": "7CwLvXc6",
                "title": "Shree Hanuman Chalisa",
                "artist": "Hariharan",
                "album": "Hanuman Chalisa",
                "durationSec": 582,
                "imageUrl": "https://c.saavncdn.com/256/art.jpg"
              }
            ]
          },
          {
            "id": "gym_energy",
            "title": "Gym Energy & Cardio",
            "subtitle": "High BPM Beats",
            "badge": "WORKOUT",
            "imageUrl": "https://i.ytimg.com/vi/iiBeBFRsCSQ/hqdefault.jpg",
            "activeHours": [5, 6, 7, 8, 9, 10, 16, 17, 18, 19, 20, 21],
            "priority": 80,
            "tracks": [
              {
                "videoId": "iiBeBFRsCSQ",
                "title": "Bollywood Workout Mix",
                "artist": "Various Artists",
                "album": "Gym Songs",
                "durationSec": 180,
                "imageUrl": "https://i.ytimg.com/vi/iiBeBFRsCSQ/hqdefault.jpg"
              }
            ]
          }
        ]
      });

      final mockClient = MockClient((request) async {
        return http.Response(mockJson, 200, headers: {'content-type': 'application/json'});
      });

      // Execute remote refresh with client returning only morning_bhakti and gym_energy
      await SmartBannerService.refreshRemoteBanners(force: true, client: mockClient);

      final active = SmartBannerService.getActiveBanners();
      expect(active.any((b) => b.id == 'creators_choice'), isTrue,
          reason: "Creator's Choice must be injected/preserved even when remote config omits it");

      final cc = active.firstWhere((b) => b.id == 'creators_choice');
      expect(cc.title, equals("Creator's Choice"));
      expect(cc.destination, equals('creators_choice'));
      expect(cc.imageUrl, equals('assets/images/creators_choice_banner.webp'));
      expect(cc.tracks.length, equals(70));
    });

    test("2. Creator's Choice visibility at 1:00 PM (13:00) when Morning Bhakti & Gym Energy are inactive", () {
      final afternoonTime = DateTime(2026, 11, 3, 13, 0); // 1:00 PM

      // Set mock remote banners that omit Creator's Choice
      const mockBhakti = SmartBannerItem(
        id: 'morning_bhakti',
        title: 'Morning Bhakti',
        subtitle: 'Devotional Chants',
        badge: 'DEVOTIONAL',
        imageUrl: 'https://c.saavncdn.com/art.jpg',
        gradientColors: [Color(0xFF381504), Color(0xFF5A2608)],
        tracks: [],
        activeHours: [6, 7, 8, 9, 10],
        priority: 85,
      );

      const mockGym = SmartBannerItem(
        id: 'gym_energy',
        title: 'Gym Energy',
        subtitle: 'Workout Beats',
        badge: 'WORKOUT BEATS',
        imageUrl: 'https://i.ytimg.com/vi/art.jpg',
        gradientColors: [Color(0xFF300A18), Color(0xFF1C0938)],
        tracks: [],
        activeHours: [5, 6, 7, 8, 9, 10, 16, 17, 18, 19, 20, 21],
        priority: 80,
      );

      SmartBannerService.setMockRemoteBanners([mockBhakti, mockGym]);

      final activeAt1pm = SmartBannerService.getActiveBanners(testTime: afternoonTime);
      expect(activeAt1pm.isNotEmpty, isTrue,
          reason: "At 1:00 PM, Creator's Choice must remain active and prevent an empty carousel");
      expect(activeAt1pm.any((b) => b.id == 'creators_choice'), isTrue);
      expect(activeAt1pm.first.id, equals('creators_choice'));
    });

    test("3. Duplicate prevention: Exactly one Creator's Choice banner exists if remote response already includes it", () async {
      final mockJson = json.encode({
        "version": 1,
        "banners": [
          {
            "id": "creators_choice",
            "title": "Creator's Choice",
            "subtitle": "Where Melodies Meet Memories.",
            "badge": "CREATOR'S CHOICE",
            "imageUrl": "https://ankitcodes30.github.io/Orvia/assets/creators_choice_banner.webp",
            "activeHours": List.generate(24, (i) => i),
            "priority": 95,
            "destination": "creators_choice",
            "tracks": []
          },
          {
            "id": "creators_choice", // Duplicate entry in remote
            "title": "Creator's Choice (Duplicate)",
            "subtitle": "Duplicate",
            "badge": "DUPLICATE",
            "imageUrl": "",
            "activeHours": List.generate(24, (i) => i),
            "priority": 95,
            "destination": "creators_choice",
            "tracks": []
          }
        ]
      });

      final mockClient = MockClient((request) async {
        return http.Response(mockJson, 200, headers: {'content-type': 'application/json'});
      });

      await SmartBannerService.refreshRemoteBanners(force: true, client: mockClient);

      final active = SmartBannerService.getActiveBanners();
      final ccMatches = active.where((b) => b.id == 'creators_choice').toList();
      expect(ccMatches.length, equals(1),
          reason: "Deduplication must guarantee exactly one Creator's Choice banner");
      expect(ccMatches.first.tracks.length, equals(70),
          reason: "Verified 70 tracks must be preserved even if remote sent empty tracks array");
    });

    test("4. Failed or malformed remote response leaves local default configuration intact", () async {
      // 1. HTTP 500 error
      final errorClient = MockClient((request) async {
        return http.Response("Internal Server Error", 500);
      });
      await SmartBannerService.refreshRemoteBanners(force: true, client: errorClient);
      expect(SmartBannerService.getActiveBanners().any((b) => b.id == 'creators_choice'), isTrue);

      // 2. Malformed JSON
      final malformedClient = MockClient((request) async {
        return http.Response("{invalid_json: true", 200);
      });
      await SmartBannerService.refreshRemoteBanners(force: true, client: malformedClient);
      expect(SmartBannerService.getActiveBanners().any((b) => b.id == 'creators_choice'), isTrue);

      // 3. Empty banners array
      final emptyClient = MockClient((request) async {
        return http.Response('{"banners": []}', 200);
      });
      await SmartBannerService.refreshRemoteBanners(force: true, client: emptyClient);
      final active = SmartBannerService.getActiveBanners();
      expect(active.any((b) => b.id == 'creators_choice'), isTrue);
    });

    test("5. Local artwork asset reference and playlist navigation integrity", () {
      final defaultCc = SmartBannerService.defaultCreatorsChoiceBanner;
      expect(defaultCc.id, equals('creators_choice'));
      expect(defaultCc.imageUrl, equals('assets/images/creators_choice_banner.webp'));
      expect(defaultCc.destination, equals('creators_choice'));
      expect(defaultCc.priority, equals(95));
      expect(defaultCc.tracks.length, equals(70));

      // Verify first track and boundary tracks
      final verified = CreatorsChoiceService.getVerifiedTracks();
      expect(verified.length, equals(70));
      expect(defaultCc.tracks.first.id, equals(verified.first.id));
      expect(defaultCc.tracks.last.id, equals(verified.last.id));
    });

    test("6. 24-hour eligibility: Creator's Choice is eligible at every hour of the day", () {
      final banner = SmartBannerService.defaultCreatorsChoiceBanner;
      for (int h = 0; h < 24; h++) {
        final time = DateTime(2026, 11, 3, h, 30);
        expect(banner.isEligibleAt(h, time), isTrue,
            reason: "Creator's Choice must be eligible at hour $h");
      }
    });
  });
}
