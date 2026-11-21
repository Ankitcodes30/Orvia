import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/plugins/utils/media_id.dart';

class SmartBannerItem {
  final String id;
  final String title;
  final String subtitle;
  final String badge;
  final String imageUrl;
  final List<Color> gradientColors;
  final List<Track> tracks;
  final List<int> activeHours;
  final int priority;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? destination;
  final int? startMinute;
  final int? endMinute;

  const SmartBannerItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.imageUrl,
    required this.gradientColors,
    required this.tracks,
    required this.activeHours,
    required this.priority,
    this.startDate,
    this.endDate,
    this.destination,
    this.startMinute,
    this.endMinute,
  });

  bool isEligibleAt(int hour, [DateTime? testDate]) {
    final now = testDate ?? DateTime.now();
    if (startDate != null && now.toUtc().isBefore(startDate!.toUtc())) {
      return false;
    }
    if (endDate != null && !now.toUtc().isBefore(endDate!.toUtc())) {
      return false;
    }

    // Explicit daily schedule for Morning Bhakti: 6:00 AM inclusive to 10:30 AM exclusive
    if (id == 'morning_bhakti') {
      final minuteOfDay = now.hour * 60 + now.minute;
      // 6:00 AM = 360, 10:30 AM = 630
      return minuteOfDay >= 360 && minuteOfDay < 630;
    }

    if (startMinute != null && endMinute != null) {
      final minuteOfDay = now.hour * 60 + now.minute;
      if (startMinute! < endMinute!) {
        if (minuteOfDay < startMinute! || minuteOfDay >= endMinute!) {
          return false;
        }
      } else {
        if (minuteOfDay < startMinute! && minuteOfDay >= endMinute!) {
          return false;
        }
      }
    }

    return activeHours.contains(hour);
  }

  static DateTime? _parseConfiguredDate(Object? value, String field) {
    if (value == null) return null;
    if (value is! String ||
        !RegExp(r'(?:Z|[+-]\d{2}:\d{2})$', caseSensitive: false)
            .hasMatch(value.trim())) {
      throw FormatException(
          '$field must be an ISO-8601 timestamp with a timezone');
    }

    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('$field is not a valid ISO-8601 timestamp');
    }
    return parsed;
  }

  factory SmartBannerItem.fromJson(Map<String, dynamic> json) {
    final colorsList =
        (json['gradientColors'] as List? ?? ['#1E1035', '#0F1E36'])
            .map((c) => _parseHexColor(c.toString()))
            .toList();

    final tracksList = (json['tracks'] as List? ?? [])
        .map((t) {
          if (t is Map<String, dynamic>) {
            final videoId = t['videoId'] as String?;
            if (videoId != null && videoId.isNotEmpty) {
              return SmartBannerService._ytTrack(
                videoId: videoId,
                title: t['title'] as String? ?? 'Instrumental Track',
                artist: t['artist'] as String? ?? 'A.K. MUSIC WORLD',
                album: t['album'] as String? ?? 'Piano Covers',
                durationSec: t['durationSec'] as int? ?? 120,
                imageUrl: t['imageUrl'] as String? ??
                    'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
              );
            } else {
              return SmartBannerService._t(
                rawId: t['rawId'] as String? ?? '',
                title: t['title'] as String? ?? 'Song',
                artist: t['artist'] as String? ?? 'Various Artists',
                album: t['album'] as String? ?? '',
                durationSec: t['durationSec'] as int? ?? 200,
                imageUrl: t['imageUrl'] as String? ?? '',
              );
            }
          }
          return null;
        })
        .whereType<Track>()
        .toList();

    return SmartBannerItem(
      id: json['id'] as String? ??
          'banner_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      badge: json['badge'] as String? ?? 'FEATURED',
      imageUrl: json['imageUrl'] as String? ?? '',
      gradientColors: colorsList,
      tracks: tracksList,
      activeHours: (json['activeHours'] as List? ?? List.generate(24, (i) => i))
          .map((h) => (h as num).toInt())
          .toList(),
      priority: json['priority'] as int? ?? 50,
      startDate: _parseConfiguredDate(json['startDate'], 'startDate'),
      endDate: _parseConfiguredDate(json['endDate'], 'endDate'),
      destination: json['destination'] as String?,
      startMinute: (json['startMinute'] as num?)?.toInt(),
      endMinute: (json['endMinute'] as num?)?.toInt(),
    );
  }

  static Color _parseHexColor(String hex) {
    String clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) clean = 'FF$clean';
    return Color(int.tryParse(clean, radix: 16) ?? 0xFF1E1035);
  }
}

class SmartBannerService {
  SmartBannerService._();

  static const String remoteConfigUrl =
      'https://ankitcodes30.github.io/Orvia/banners.json';
  static const String remoteFallbackUrl =
      'https://raw.githubusercontent.com/Ankitcodes30/Orvia/ghpage/banners.json';

  static DateTime? _lastRefreshTime;
  static List<SmartBannerItem>? _cachedRemoteBanners;

  static void setMockRemoteBanners(List<SmartBannerItem>? banners) {
    _cachedRemoteBanners = banners;
  }

  static DateTime? nextDateBoundary({DateTime? testTime}) {
    final now = testTime ?? DateTime.now();
    final boundaries = <DateTime>[];
    final banners = _cachedRemoteBanners ?? _defaultBanners;

    for (final banner in banners) {
      if (kDisallowedBannerIds.contains(banner.id)) continue;

      final start = banner.startDate;
      if (start != null && start.toUtc().isAfter(now.toUtc())) {
        boundaries.add(start);
      }

      final end = banner.endDate;
      if (end != null) {
        if (end.toUtc().isAfter(now.toUtc())) boundaries.add(end);
      }
    }

    final hasHourlySchedules = banners.any((b) =>
        !kDisallowedBannerIds.contains(b.id) && b.activeHours.length < 24);
    if (hasHourlySchedules) {
      final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
      boundaries.add(nextHour);
    }

    // Explicit morning_bhakti boundaries: 6:00 AM (start) and 10:30 AM (end)
    final today6am = DateTime(now.year, now.month, now.day, 6, 0);
    final today1030am = DateTime(now.year, now.month, now.day, 10, 30);
    final tomorrow6am = DateTime(now.year, now.month, now.day + 1, 6, 0);
    if (today6am.isAfter(now)) boundaries.add(today6am);
    if (today1030am.isAfter(now)) boundaries.add(today1030am);
    if (tomorrow6am.isAfter(now)) boundaries.add(tomorrow6am);

    if (boundaries.isEmpty) return null;
    boundaries.sort();
    return boundaries.first;
  }

  /// Banners explicitly and permanently removed from carousel rotation.
  /// Prevents stale remote caches or fallbacks from re-introducing them.
  static const Set<String> kDisallowedBannerIds = {
    'night_calm',
    'whats_hot',
    'navratri_special_2026',
  };

  /// Returns banners eligible at [testTime], with date windows compared as instants.
  static List<SmartBannerItem> getActiveBanners({DateTime? testTime}) {
    final now = testTime ?? DateTime.now();
    final hour = now.hour;

    final allBanners = _cachedRemoteBanners ?? _defaultBanners;
    final eligible = allBanners
        .where((b) => !kDisallowedBannerIds.contains(b.id))
        .where((b) => b.isEligibleAt(hour, now))
        .toList();

    // Sort by priority descending (higher number = higher priority)
    eligible.sort((a, b) => b.priority.compareTo(a.priority));

    // Ensure fallback banner if list would otherwise be empty, but NEVER force
    // a dated festival banner or a time-restricted banner (like Morning Bhakti)
    // outside its scheduled window.
    if (eligible.isEmpty && allBanners.isNotEmpty) {
      try {
        final fallback = allBanners.firstWhere(
          (b) =>
              !kDisallowedBannerIds.contains(b.id) &&
              b.startDate == null &&
              b.endDate == null &&
              b.id != 'morning_bhakti' &&
              b.activeHours.length == 24,
        );
        eligible.add(fallback);
      } catch (_) {}
    }

    return List.unmodifiable(eligible);
  }

  /// Refreshes remote banner configuration in background without blocking UI.
  static Future<void> refreshRemoteBanners({
    bool force = false,
    http.Client? client,
  }) async {
    final now = DateTime.now();
    if (!force &&
        _lastRefreshTime != null &&
        now.difference(_lastRefreshTime!) < const Duration(hours: 4)) {
      return;
    }

    try {
      final response = await _fetchRemoteConfig(client);
      if (response == null) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data['banners'] is List) {
          final parsed = (data['banners'] as List)
              .map((b) => SmartBannerItem.fromJson(b as Map<String, dynamic>))
              .where((b) => !kDisallowedBannerIds.contains(b.id))
              .map((b) {
                // Prevent stale remote config from downgrading gym_energy to old 7-track baseline
                if (b.id == 'gym_energy' && b.tracks.length < 18) {
                  return _defaultBanners
                      .firstWhere((def) => def.id == 'gym_energy');
                }
                return b;
              })
              .where((b) => b.tracks.isNotEmpty || b.destination != null)
              .toList();
          _cachedRemoteBanners = parsed;
          _lastRefreshTime = now;
          log('Successfully refreshed remote banners (${parsed.length} items)',
              name: 'SmartBannerService');
        }
      }
    } catch (e) {
      log('Remote banner sync: using embedded fallback ($e)',
          name: 'SmartBannerService');
    }
  }

  static Future<http.Response?> _fetchRemoteConfig(http.Client? client) async {
    for (final url in [remoteConfigUrl, remoteFallbackUrl]) {
      try {
        final uri = Uri.parse(url);
        final response =
            await (client == null ? http.get(uri) : client.get(uri))
                .timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) return response;
        log('Banner config $url returned HTTP ${response.statusCode}',
            name: 'SmartBannerService');
      } catch (e) {
        log('Banner config request to $url failed: $e',
            name: 'SmartBannerService');
      }
    }
    return null;
  }

  static Track _t({
    required String rawId,
    required String title,
    required String artist,
    required String album,
    required int durationSec,
    required String imageUrl,
  }) {
    const pluginId = kDefaultSaavnPluginId;
    return Track(
      id: '$pluginId::$rawId',
      title: title,
      artists: [ArtistSummary(id: '', name: artist)],
      album: AlbumSummary(id: '', title: album, artists: const []),
      durationMs: BigInt.from(durationSec * 1000),
      thumbnail: Artwork(
        url: imageUrl,
        urlHigh: imageUrl,
        layout: ImageLayout.square,
      ),
      isExplicit: false,
    );
  }

  static Track _ytTrack({
    required String videoId,
    required String title,
    required String artist,
    required String album,
    required int durationSec,
    required String imageUrl,
  }) {
    const pluginId = 'content-resolver.bloomfactory.ytvideo';
    return Track(
      id: '$pluginId::$videoId',
      title: title,
      artists: [ArtistSummary(id: '', name: artist)],
      album: AlbumSummary(id: '', title: album, artists: const []),
      durationMs: BigInt.from(durationSec * 1000),
      thumbnail: Artwork(
        url: imageUrl,
        urlHigh: imageUrl,
        layout: ImageLayout.square,
      ),
      isExplicit: false,
    );
  }

  // ── Default Curated Collections ──────────────────────────────────────────

  /// A. Morning Bhakti / Hanuman Chalisa (05:00 - 10:00)
  static final List<Track> _morningBhaktiTracks = [
    _t(
      rawId: '7CwLvXc6',
      title: 'Shree Hanuman Chalisa',
      artist: 'Hariharan, Traditional',
      album: 'Shree Hanuman Chalisa (Hanuman Ashtak)',
      durationSec: 582,
      imageUrl:
          'https://c.saavncdn.com/256/Shree-Hanuman-Chalisa-Hanuman-Ashtak-Hindi-1992-20260324161030-500x500.webp',
    ),
    _t(
      rawId: 'Br3sv0l4',
      title: 'Dulhaniya Re',
      artist: 'Shahnaaz Akhtar',
      album: 'Dulhaniya Re',
      durationSec: 858,
      imageUrl:
          'https://c.saavncdn.com/580/Dulhaniya-Re-Hindi-2023-20250511164359-500x500.jpg',
    ),
    _t(
      rawId: '__MfaQW6',
      title: 'Aalha Ki Dhwaja Nahin Aayi',
      artist: 'Shahnaz Akhtar',
      album: 'Maiyya Pav Paijaniya',
      durationSec: 787,
      imageUrl:
          'https://c.saavncdn.com/066/Maiya-Paav-Paijaniya-Vol-1-Hindi-2009-20260608212622-500x500.jpg',
    ),
    _t(
      rawId: 'r5yioR-M',
      title: 'Bigdi Meri Bana De Oo Sherawali Maiya',
      artist: 'Lakhbir Singh Lakkha',
      album: 'Bigdi Meri Bana De',
      durationSec: 417,
      imageUrl:
          'https://c.saavncdn.com/034/Beta-Bulaye-Hindi-1998-20230807153827-500x500.jpg',
    ),
    _t(
      rawId: '6o2XH_yQ',
      title: 'Nach Rahi Hai Kali Angana Mein',
      artist: 'Sandeep Karosiya',
      album: 'Nach Rahi Hai Kali Angana Mein',
      durationSec: 391,
      imageUrl:
          'https://c.saavncdn.com/311/Nach-Rahi-Hai-Kali-Angana-Mein-Hindi-2025-20251007144002-500x500.jpg',
    ),
    _t(
      rawId: 'Ft5IeMlT',
      title: 'Angna Padharo Maharani',
      artist: 'Manish Agrawal',
      album: 'Angna Padharo Maharani',
      durationSec: 568,
      imageUrl:
          'https://c.saavncdn.com/734/Angna-Padharo-Maharani-Hindi-2023-20260420210240-500x500.jpg',
    ),
    _ytTrack(
      videoId: 'Ha5QlyycMhM',
      title: 'Har Shambhu (Piano Devotional)',
      artist: 'A.K. MUSIC WORLD',
      album: 'A.K. Music World Piano Covers',
      durationSec: 114,
      imageUrl: 'https://i.ytimg.com/vi/Ha5QlyycMhM/hqdefault.jpg',
    ),
  ];

  /// C. Gym Energy & Cardio (18 Verified Distinct Playable Source Tracks)
  static final List<Track> _gymEnergyTracks = [
    _ytTrack(
      videoId: 'iiBeBFRsCSQ',
      title: 'Bollywood Workout Mix',
      artist: 'Various Artists',
      album: 'Gym Songs Mashup',
      durationSec: 180,
      imageUrl: 'https://i.ytimg.com/vi/iiBeBFRsCSQ/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'dHsV56I1GwE',
      title: 'Dope Shope',
      artist: 'Yo Yo Honey Singh, Deep Money',
      album: 'International Villager',
      durationSec: 192,
      imageUrl: 'https://i.ytimg.com/vi/dHsV56I1GwE/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'uFGreSkTMck',
      title: 'Jaan Se Guzarte Hain',
      artist: 'Shashwat Sachdev, Khan Saab',
      album: 'Dhurandhar The Revenge',
      durationSec: 183,
      imageUrl: 'https://i.ytimg.com/vi/uFGreSkTMck/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'D2CKOIiabfg',
      title: 'Gym Motivation Music',
      artist: '7 Power Fitness',
      album: 'Best Gym Workout Songs',
      durationSec: 215,
      imageUrl: 'https://i.ytimg.com/vi/D2CKOIiabfg/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'ELrwFR4NkLk',
      title: 'UNSUNG Fast Rap Workout Mix 2026',
      artist: 'Motivational Gym Music',
      album: 'Fast Rap Workout',
      durationSec: 195,
      imageUrl: 'https://i.ytimg.com/vi/ELrwFR4NkLk/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: '6SFfS9QMloU',
      title: 'Ultimate Workout Anthem Non-Stop Mashup',
      artist: 'Kedrock, SD Style',
      album: 'Bollywood Motivational Mashup',
      durationSec: 328,
      imageUrl: 'https://i.ytimg.com/vi/6SFfS9QMloU/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'skhUNWhX2UY',
      title: 'BEST WORKOUT MUSIC 2026',
      artist: 'Fitness Mix',
      album: 'Gym Motivation Songs',
      durationSec: 210,
      imageUrl: 'https://i.ytimg.com/vi/skhUNWhX2UY/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'REaoaFTiMTs',
      title: 'I like the way you kiss me',
      artist: 'Dani Vidi, Yes Yes, Ezton',
      album: 'Hyper Techno',
      durationSec: 141,
      imageUrl: 'https://i.ytimg.com/vi/REaoaFTiMTs/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'fQWNeIiFf_s',
      title: 'Thank You (Not So Bad)',
      artist: 'Dimitri Vegas & Like Mike, Tiësto, Dido, W&W',
      album: 'Thank You (Not So Bad)',
      durationSec: 140,
      imageUrl: 'https://i.ytimg.com/vi/fQWNeIiFf_s/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'tKXp27BBz6U',
      title: 'Freestyler (Rock The Microphone)',
      artist: 'Lost Frequencies, Bomfunk MC\'s',
      album: 'Freestyler',
      durationSec: 174,
      imageUrl: 'https://i.ytimg.com/vi/tKXp27BBz6U/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'wQ9ifRPfP8A',
      title: 'Need Your Love',
      artist: 'Ilkay Sencan, Kaluma, Adam Woods',
      album: 'Need Your Love',
      durationSec: 134,
      imageUrl: 'https://i.ytimg.com/vi/wQ9ifRPfP8A/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: '4HeMSUVpMFc',
      title: 'Let It Happen (Techno)',
      artist: 'Lucas Estrada, Clmd, Braaheim',
      album: 'Let It Happen (Techno)',
      durationSec: 123,
      imageUrl: 'https://i.ytimg.com/vi/4HeMSUVpMFc/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: '90h5GMM4iB8',
      title: 'Be My Lover (2023 Mix)',
      artist: 'Hypaton, David Guetta, La Bouche',
      album: 'Be My Lover (2023 Mix)',
      durationSec: 170,
      imageUrl: 'https://i.ytimg.com/vi/90h5GMM4iB8/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'j5ZBs64cHTE',
      title: 'Love With Workout Mashup #4',
      artist: 'DJ DALAL LONDON, VDJ Mahe',
      album: 'Motivational Mashup',
      durationSec: 188,
      imageUrl: 'https://i.ytimg.com/vi/j5ZBs64cHTE/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'BVnIWAuCv7M',
      title: 'Jo Tere Sang X Tere Liye (Synthwave Remix)',
      artist: 'ROHAN',
      album: 'Indian Bollywood Synthwave',
      durationSec: 174,
      imageUrl: 'https://i.ytimg.com/vi/BVnIWAuCv7M/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'DoK2iKDCaMI',
      title: 'Aarambh Hai Prachand X NF\'s Hope',
      artist: 'Beatzhacker',
      album: 'Instagram Viral Original Mashup',
      durationSec: 165,
      imageUrl: 'https://i.ytimg.com/vi/DoK2iKDCaMI/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'Ard-_9pCyzA',
      title: 'Bande',
      artist: 'Sivam, Sam C.S.',
      album: 'Vikram Vedha',
      durationSec: 195,
      imageUrl: 'https://i.ytimg.com/vi/Ard-_9pCyzA/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'Jyst8oIHOAY',
      title: 'Mercy',
      artist: 'Badshah',
      album: 'ONE (Original Never Ends)',
      durationSec: 177,
      imageUrl: 'https://i.ytimg.com/vi/Jyst8oIHOAY/hqdefault.jpg',
    ),
  ];

  static final List<SmartBannerItem> _defaultBanners = [
    SmartBannerItem(
      id: 'diwali_festive_2026',
      title: 'Diwali Festive Special',
      subtitle: 'A festival of lights, devotion & celebration',
      badge: 'DIWALI • 2026',
      imageUrl: '',
      gradientColors: const [
        Color(0xFF6D1B00),
        Color(0xFFB84A00),
        Color(0xFF3B123B)
      ],
      tracks: const [],
      activeHours: List.generate(24, (hour) => hour),
      priority: 100,
      startDate: DateTime.utc(2026, 11, 4, 18, 30),
      endDate: DateTime.utc(2026, 11, 11, 18, 30),
      destination: 'festival_special',
    ),
    // 1. Morning Bhakti (6:00 AM inclusive to 10:30 AM exclusive)
    SmartBannerItem(
      id: 'morning_bhakti',
      title: 'Morning Bhakti',
      subtitle: 'Shree Hanuman Chalisa & Aarti',
      badge: 'DIVINE MORNING',
      imageUrl:
          'https://c.saavncdn.com/034/Beta-Bulaye-Hindi-1998-20230807153827-500x500.jpg',
      gradientColors: [const Color(0xFF381504), const Color(0xFF5A2608)],
      tracks: _morningBhaktiTracks,
      activeHours: const [6, 7, 8, 9, 10],
      startMinute: 360,
      endMinute: 630,
      priority: 85,
    ),

    // 2. Gym Energy
    SmartBannerItem(
      id: 'gym_energy',
      title: 'Gym Energy',
      subtitle: 'High-Impact Indian Beats & Hip-Hop',
      badge: 'WORKOUT BEATS',
      imageUrl: 'https://i.ytimg.com/vi/iiBeBFRsCSQ/hqdefault.jpg',
      gradientColors: [const Color(0xFF300A18), const Color(0xFF1C0938)],
      tracks: _gymEnergyTracks,
      activeHours: const [5, 6, 7, 8, 9, 10, 16, 17, 18, 19, 20, 21],
      priority: 80,
    ),
  ];
}
