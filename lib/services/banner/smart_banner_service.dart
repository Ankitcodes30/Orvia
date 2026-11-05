import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/plugins/utils/media_id.dart';
import 'package:Orvia/services/catalogue/creators_choice_service.dart';

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
    'india_songs',
    'india-songs',
    'india_songs_hotw',
    'india-songs-hotw',
    'diwali_festive_2026',
    'diwali_2026',
  };

  static SmartBannerItem get defaultCreatorsChoiceBanner => _defaultBanners.firstWhere(
        (b) => b.id == 'creators_choice',
      );

  /// Returns banners eligible at [testTime], with date windows compared as instants.
  static List<SmartBannerItem> getActiveBanners({DateTime? testTime}) {
    final now = testTime ?? DateTime.now();
    final hour = now.hour;

    final baseList = _cachedRemoteBanners ?? _defaultBanners;
    final allBanners = List<SmartBannerItem>.from(baseList);

    // Core service guarantee: ensure Creator's Choice is present in candidate pool
    if (!allBanners.any((b) => b.id == 'creators_choice')) {
      allBanners.add(defaultCreatorsChoiceBanner);
    }

    final eligible = allBanners
        .where((b) => !kDisallowedBannerIds.contains(b.id))
        .where((b) => b.isEligibleAt(hour, now))
        .toList();

    // Deduplicate by banner ID (keeping first occurrence)
    final seen = <String>{};
    final uniqueEligible = <SmartBannerItem>[];
    for (final banner in eligible) {
      if (seen.add(banner.id)) {
        uniqueEligible.add(banner);
      }
    }

    // Sort by priority descending (higher number = higher priority)
    uniqueEligible.sort((a, b) => b.priority.compareTo(a.priority));

    // Ensure fallback banner if list would otherwise be empty, but NEVER force
    // a dated festival banner or a time-restricted banner (like Morning Bhakti)
    // outside its scheduled window.
    if (uniqueEligible.isEmpty && allBanners.isNotEmpty) {
      try {
        final fallback = allBanners.firstWhere(
          (b) =>
              !kDisallowedBannerIds.contains(b.id) &&
              b.startDate == null &&
              b.endDate == null &&
              b.id != 'morning_bhakti' &&
              b.activeHours.length == 24,
        );
        uniqueEligible.add(fallback);
      } catch (_) {}
    }

    // Final safety guarantee: Creator's Choice must never be dropped
    if (!uniqueEligible.any((b) => b.id == 'creators_choice')) {
      uniqueEligible.add(defaultCreatorsChoiceBanner);
      uniqueEligible.sort((a, b) => b.priority.compareTo(a.priority));
    }

    return List.unmodifiable(uniqueEligible);
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
                // Guarantee Creator's Choice retains verified tracks & local asset fallback
                if (b.id == 'creators_choice') {
                  final def = defaultCreatorsChoiceBanner;
                  return SmartBannerItem(
                    id: def.id,
                    title: b.title.isNotEmpty ? b.title : def.title,
                    subtitle: b.subtitle.isNotEmpty ? b.subtitle : def.subtitle,
                    badge: b.badge.isNotEmpty ? b.badge : def.badge,
                    imageUrl: (b.imageUrl.isNotEmpty && !b.imageUrl.startsWith('assets/'))
                        ? b.imageUrl
                        : def.imageUrl,
                    gradientColors: b.gradientColors.isNotEmpty
                        ? b.gradientColors
                        : def.gradientColors,
                    tracks: b.tracks.isNotEmpty ? b.tracks : def.tracks,
                    activeHours: def.activeHours,
                    priority: b.priority > 0 ? b.priority : def.priority,
                    destination: def.destination,
                  );
                }
                return b;
              })
              .where((b) => b.tracks.isNotEmpty || b.destination != null)
              .toList();

          // Deduplicate by ID
          final seenIds = <String>{};
          final deduplicated = <SmartBannerItem>[];
          for (final banner in parsed) {
            if (seenIds.add(banner.id)) {
              deduplicated.add(banner);
            }
          }

          // Core guarantee: If remote response omits creators_choice, preserve/inject defaultCreatorsChoiceBanner
          if (!deduplicated.any((b) => b.id == 'creators_choice')) {
            deduplicated.add(defaultCreatorsChoiceBanner);
          }

          _cachedRemoteBanners = deduplicated;
          _lastRefreshTime = now;
          log('Successfully refreshed remote banners (${deduplicated.length} items)',
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
    _ytTrack(
      videoId: 'SMv8gp3I4Ao',
      title: 'शिव स्तुति: आशुतोष शशाँक शेखर (Shiv Stuti)',
      artist: 'HM Bhakti sagar',
      album: 'Shiv Stuti',
      durationSec: 1012,
      imageUrl: 'https://i.ytimg.com/vi/SMv8gp3I4Ao/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'bd8I6Ss5GNA',
      title: 'Shiv Swarnamala Stuti',
      artist: 'Harish Sagane, Religious India',
      album: 'Shiv Swarnamala Stuti',
      durationSec: 362,
      imageUrl: 'https://i.ytimg.com/vi/bd8I6Ss5GNA/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'G_4b9m6boTw',
      title: 'Namami Shamishan',
      artist: 'Harish Sagane, Religious India',
      album: 'Namami Shamishan',
      durationSec: 336,
      imageUrl: 'https://i.ytimg.com/vi/G_4b9m6boTw/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'kj7L8eEOTZE',
      title: 'राम सिया राम | Ram Siya Ram Bhajan',
      artist: 'NMF BHAKTI',
      album: 'Ram Siya Ram Bhajan',
      durationSec: 360,
      imageUrl: 'https://i.ytimg.com/vi/kj7L8eEOTZE/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: '9w9SVujBfxo',
      title: 'MAIYA TERI JAI JAIKAAR',
      artist: 'Arijit Singh, Jeet Gannguli, T-Series',
      album: 'Maiya Teri Jai Jaikaar',
      durationSec: 276,
      imageUrl: 'https://i.ytimg.com/vi/9w9SVujBfxo/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: '30YNd5fEGMo',
      title: 'Narayan Mil Jayega',
      artist: 'Jubin Nautiyal, Payal Dev, T-Series',
      album: 'Narayan Mil Jayega',
      durationSec: 300,
      imageUrl: 'https://i.ytimg.com/vi/30YNd5fEGMo/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'Njyx5ZuwEHI',
      title: 'Har Har Gange',
      artist: 'Arijit Singh, T-Series',
      album: 'Batti Gul Meter Chalu',
      durationSec: 197,
      imageUrl: 'https://i.ytimg.com/vi/Njyx5ZuwEHI/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: '4CKpFcQdJXk',
      title: 'अयि गिरिनन्दिनि - महिषासुर मर्दिनी स्तोत्र',
      artist: 'Madhubanti Bagchi, Tilak Bhakti Sangrah',
      album: 'Mahishasura Mardini Stotram',
      durationSec: 362,
      imageUrl: 'https://i.ytimg.com/vi/4CKpFcQdJXk/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'VAdQcL_Xgoc',
      title: 'Maine Tere Hi Bharose Hanuman',
      artist: 'PSS MUSIC',
      album: 'Hanuman Ansh',
      durationSec: 470,
      imageUrl: 'https://i.ytimg.com/vi/VAdQcL_Xgoc/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'eL-iQ3VHxwA',
      title: 'Adharam Madhuram Lofi - Krishna Bhajan',
      artist: 'Khusi Ki Dhun',
      album: 'Krishna Bhajan',
      durationSec: 269,
      imageUrl: 'https://i.ytimg.com/vi/eL-iQ3VHxwA/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: '4DkNCgUXbig',
      title: 'Parvati Boli Shankar Se - O Bholenath Ji',
      artist: 'Hansraj Raghuwanshi, NAV Records',
      album: 'Parvati Boli Shankar Se',
      durationSec: 439,
      imageUrl: 'https://i.ytimg.com/vi/4DkNCgUXbig/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'Tl4bQBfOtbg',
      title: 'Ram Siya Ram (Adipurush)',
      artist: 'Sachet-Parampara, Manoj Muntashir, T-Series',
      album: 'Adipurush',
      durationSec: 250,
      imageUrl: 'https://i.ytimg.com/vi/Tl4bQBfOtbg/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'ne3Mjg1M-Uo',
      title: 'श्री कृष्णा गोविंद हरे मुरारी',
      artist: 'Spiritual Mantra',
      album: 'Krishna Bhajan',
      durationSec: 341,
      imageUrl: 'https://i.ytimg.com/vi/ne3Mjg1M-Uo/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'gdKm1fZzMgI',
      title: 'Om Tryambakam Yajamahe (Mahamrityunjaya Mantra)',
      artist: 'Rajshri Soul',
      album: 'Shiva Maha Mantra',
      durationSec: 181,
      imageUrl: 'https://i.ytimg.com/vi/gdKm1fZzMgI/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: '2yhvCgpNJiA',
      title: 'Om Namo Bhagavate Vasudevaya',
      artist: 'Mahavtar Narsimha, Ishtar Music',
      album: 'Mahavtar Narsimha',
      durationSec: 205,
      imageUrl: 'https://i.ytimg.com/vi/2yhvCgpNJiA/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'mXNudXlAEjw',
      title: 'शिव स्तुति: | Powerful Shiva Mantra',
      artist: 'ShivOhm',
      album: 'Shiv Stuti',
      durationSec: 400,
      imageUrl: 'https://i.ytimg.com/vi/mXNudXlAEjw/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'GePN4-Cajvk',
      title: 'Vedic Chanting',
      artist: 'Manish Vyas',
      album: 'Vedic Chanting',
      durationSec: 275,
      imageUrl: 'https://i.ytimg.com/vi/GePN4-Cajvk/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'JX1_7HZGfeA',
      title: 'KRISHANAYA VASUDEVAYA 108 Times',
      artist: 'Meditative India',
      album: 'Krishna Mantra',
      durationSec: 3647,
      imageUrl: 'https://i.ytimg.com/vi/JX1_7HZGfeA/hqdefault.jpg',
    ),
    _ytTrack(
      videoId: 'GEVvyIrQZnA',
      title: 'GAYATRI MANTRA 108 Times CHANTING',
      artist: 'Meditative India',
      album: 'Gayatri Mantra',
      durationSec: 4567,
      imageUrl: 'https://i.ytimg.com/vi/GEVvyIrQZnA/hqdefault.jpg',
    ),
  ];

  static List<Track> get morningBhaktiTracks =>
      List.unmodifiable(_morningBhaktiTracks);

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
      id: 'creators_choice',
      title: "Creator's Choice",
      subtitle: "Where Melodies Meet Memories.",
      badge: "CREATOR'S CHOICE",
      imageUrl: 'assets/images/creators_choice_banner.webp',
      gradientColors: const [
        Color(0xFF2C1B4D),
        Color(0xFF673AB7),
        Color(0xFF8E24AA),
      ],
      tracks: CreatorsChoiceService.getVerifiedTracks(),
      destination: 'creators_choice',
      activeHours: List.generate(24, (hour) => hour),
      priority: 95,
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
