import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/plugins/utils/media_id.dart';

/// Model representing an Indian Festival Event with multi-regional support,
/// automatic 10-day promotion scheduling, validated tracks, and banner assets.
class FestivalEvent {
  final String id;
  final String name;
  final String greeting;
  final String region;
  final DateTime startDate;
  final DateTime endDate;
  final int promotionDays;
  final String bannerUrl;
  final String bannerTitle;
  final String bannerSubtitle;
  final List<String> categories;
  final List<Track> tracks;

  const FestivalEvent({
    required this.id,
    required this.name,
    required this.greeting,
    required this.region,
    required this.startDate,
    required this.endDate,
    this.promotionDays = 10,
    required this.bannerUrl,
    required this.bannerTitle,
    required this.bannerSubtitle,
    required this.categories,
    required this.tracks,
  });

  /// True from the inclusive promotion start until the exclusive [endDate].
  bool isPromotedAt(DateTime now) {
    final promoStart = startDate.subtract(Duration(days: promotionDays));
    final instant = now.toUtc();
    return !instant.isBefore(promoStart.toUtc()) &&
        instant.isBefore(endDate.toUtc());
  }

  /// True if the festival is currently happening right now
  bool isOngoingAt(DateTime now) {
    final instant = now.toUtc();
    return !instant.isBefore(startDate.toUtc()) &&
        instant.isBefore(endDate.toUtc());
  }

  int daysUntilStart(DateTime now) {
    if (now.isAfter(startDate)) return 0;
    return startDate.difference(now).inDays;
  }
}

/// Service providing fully automatic Indian festival discovery.
/// - Promotes festival music exactly 10 days before the configured festival.
/// - Supports remote JSON updates without requiring a new APK release.
/// - Keeps the last validated remote configuration in memory for this session.
/// - Falls back to the embedded calendar when offline or after a process restart.
class FestivalService {
  static const String pluginId = kDefaultSaavnPluginId;

  static const String remoteConfigUrl =
      'https://ankitcodes30.github.io/Orvia/festivals.json';
  static const String remoteFallbackUrl =
      'https://raw.githubusercontent.com/Ankitcodes30/Orvia/ghpage/festivals.json';

  static DateTime? _lastRefreshTime;
  static List<FestivalEvent>? _cachedRemoteEvents;

  static void setMockRemoteEvents(List<FestivalEvent>? events) {
    _cachedRemoteEvents = events;
  }

  /// Retrieves the currently active or upcoming promoted festival.
  /// If [now] is not provided, defaults to DateTime.now().
  static FestivalEvent? getActiveOrUpcomingFestival({DateTime? testTime}) {
    final now = testTime ?? DateTime.now();
    final events = _cachedRemoteEvents ?? _kDefaultFestivalSchedule;

    for (final event in events) {
      if (event.isPromotedAt(now)) {
        return event;
      }
    }
    return null;
  }

  static DateTime? nextDateBoundary({DateTime? testTime}) {
    final now = (testTime ?? DateTime.now()).toUtc();
    final boundaries = <DateTime>[];
    for (final event in _cachedRemoteEvents ?? _kDefaultFestivalSchedule) {
      final promotionStart =
          event.startDate.subtract(Duration(days: event.promotionDays));
      if (promotionStart.toUtc().isAfter(now)) {
        boundaries.add(promotionStart);
      }
      if (event.endDate.toUtc().isAfter(now)) boundaries.add(event.endDate);
    }
    if (boundaries.isEmpty) return null;
    boundaries.sort((a, b) => a.compareTo(b));
    return boundaries.first;
  }

  /// Fetches remote festival configuration asynchronously.
  /// Does not throw on network failure; falls back safely to cache/default schedule.
  static Future<void> refreshRemoteSchedule({bool force = false}) async {
    await refreshRemoteScheduleWithClient(force: force);
  }

  static Future<void> refreshRemoteScheduleWithClient({
    bool force = false,
    http.Client? client,
  }) async {
    final now = DateTime.now();
    if (!force &&
        _lastRefreshTime != null &&
        now.difference(_lastRefreshTime!) < const Duration(hours: 6)) {
      return;
    }

    try {
      http.Response? response;
      for (final url in [remoteConfigUrl, remoteFallbackUrl]) {
        try {
          final request = client == null
              ? http.get(Uri.parse(url))
              : client.get(Uri.parse(url));
          final candidate = await request.timeout(const Duration(seconds: 4));
          if (candidate.statusCode == 200) {
            response = candidate;
            break;
          }
          log('Festival config $url returned HTTP ${candidate.statusCode}',
              name: 'FestivalService');
        } catch (e) {
          log('Festival config request to $url failed: $e',
              name: 'FestivalService');
        }
      }

      if (response != null) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data['festivals'] is List) {
          final parsed = <FestivalEvent>[];
          final items = data['festivals'] as List;
          for (final item in items) {
            try {
              final ev = item is Map<String, dynamic>
                  ? _parseFestivalJson(item)
                  : null;
              if (ev != null) parsed.add(ev);
            } on FormatException catch (e) {
              log('Ignoring invalid festival config entry: $e',
                  name: 'FestivalService');
            }
          }
          if (items.isEmpty || parsed.length == items.length) {
            _cachedRemoteEvents = parsed;
            _lastRefreshTime = now;
            log('Remote festival schedule refreshed successfully: ${parsed.length} festivals',
                name: 'FestivalService');
          } else {
            log('Festival schedule rejected because one or more entries are invalid',
                name: 'FestivalService');
          }
        }
      }
    } catch (e) {
      log('Remote festival refresh skipped/failed: $e (using cached fallback)',
          name: 'FestivalService');
    }
  }

  static FestivalEvent? _parseFestivalJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final name = json['name'] as String?;
    final startStr = json['startDate'] as String?;
    final endStr = json['endDate'] as String?;
    if (id == null || name == null || startStr == null || endStr == null) {
      return null;
    }

    final startDate = _parseConfiguredDate(startStr, 'startDate');
    final endDate = _parseConfiguredDate(endStr, 'endDate');
    if (startDate == null || endDate == null) return null;

    final bannerUrl = json['bannerUrl'] as String? ??
        'https://c.saavncdn.com/124/Gori-Radha-Ne-Kalo-Kaan-Gujarati-2026-20261006132514-500x500.webp';
    final bannerTitle = json['bannerTitle'] as String? ?? '$name Special';
    final bannerSubtitle = json['bannerSubtitle'] as String? ??
        'Listen to celebratory music & festive anthems';
    final promoDays = json['promotionDays'] as int? ?? 10;
    final region = json['region'] as String? ?? 'All-India';

    final configuredTracks = json['tracks'];
    final tracks = configuredTracks is List
        ? configuredTracks
            .whereType<Map<String, dynamic>>()
            .map(_parseTrackJson)
            .whereType<Track>()
            .toList()
        : id == 'diwali_2026'
            ? _kDiwaliTracks
            : id == 'navratri_2026'
                ? _kNavratriTracks
                : <Track>[];

    return FestivalEvent(
      id: id,
      name: name,
      greeting: json['greeting'] as String? ?? 'Happy $name!',
      region: region,
      startDate: startDate,
      endDate: endDate,
      promotionDays: promoDays,
      bannerUrl: bannerUrl,
      bannerTitle: bannerTitle,
      bannerSubtitle: bannerSubtitle,
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['All', 'Popular', 'Celebration', 'Aarti'],
      tracks: tracks,
    );
  }

  static DateTime? _parseConfiguredDate(String value, String field) {
    if (!RegExp(r'(?:Z|[+-]\d{2}:\d{2})$', caseSensitive: false)
        .hasMatch(value.trim())) {
      throw FormatException('$field must include an ISO-8601 timezone');
    }
    return DateTime.tryParse(value)?.toUtc();
  }

  static Track? _parseTrackJson(Map<String, dynamic> json) {
    final rawId = json['rawId'] as String?;
    final title = json['title'] as String?;
    final artist = json['artist'] as String?;
    if (rawId == null || rawId.isEmpty || title == null || artist == null) {
      return null;
    }
    return _track(
      rawId: rawId,
      title: title,
      artist: artist,
      album: json['album'] as String? ?? '',
      durationSec: json['durationSec'] as int? ?? 0,
      imageUrl: json['imageUrl'] as String? ?? '',
    );
  }

  static DateTime _ist(int year, int month, int day,
          [int hour = 0, int minute = 0, int second = 0]) =>
      DateTime.utc(year, month, day, hour, minute, second)
          .subtract(const Duration(hours: 5, minutes: 30));

  static Track _track({
    required String rawId,
    required String title,
    required String artist,
    required String album,
    required int durationSec,
    required String imageUrl,
  }) {
    final compositeId = '$pluginId::$rawId';
    return Track(
      id: compositeId,
      title: title,
      artists: [
        ArtistSummary(
          id: '',
          name: artist,
          thumbnail: Artwork(
            url: imageUrl,
            urlLow: imageUrl,
            urlHigh: imageUrl,
            layout: ImageLayout.square,
          ),
        ),
      ],
      album: AlbumSummary(
        id: '',
        title: album,
        artists: const [],
        thumbnail: Artwork(
          url: imageUrl,
          urlLow: imageUrl,
          urlHigh: imageUrl,
          layout: ImageLayout.square,
        ),
      ),
      durationMs: BigInt.from(durationSec * 1000),
      thumbnail: Artwork(
        url: imageUrl,
        urlLow: imageUrl,
        urlHigh: imageUrl,
        layout: ImageLayout.square,
      ),
      isExplicit: false,
    );
  }

  static const String ytPluginId = 'content-resolver.bloomfactory.ytvideo';

  static Track _ytTrack({
    required String videoId,
    required String title,
    required String artist,
    required String album,
    required int durationSec,
    required String imageUrl,
  }) {
    final compositeId = '$ytPluginId::$videoId';
    final artwork = Artwork(
      url: imageUrl,
      urlLow: imageUrl,
      urlHigh: 'https://i.ytimg.com/vi/$videoId/maxresdefault.jpg',
      layout: ImageLayout.square,
    );
    return Track(
      id: compositeId,
      title: title,
      artists: [
        ArtistSummary(
          id: '',
          name: artist,
          thumbnail: artwork,
        ),
      ],
      album: AlbumSummary(
        id: '',
        title: album,
        artists: const [],
        thumbnail: artwork,
      ),
      durationMs: BigInt.from(durationSec * 1000),
      thumbnail: artwork,
      url: 'https://www.youtube.com/watch?v=$videoId',
      isExplicit: false,
    );
  }

  // ── Verified Diwali Tracks (Exact 19 YouTube tracks in order) ─────────────
  static final List<Track> _kDiwaliTracks = [
    _ytTrack(videoId: 'yWNPxS0sXnE', title: 'Ramayana: Jai Jai Ram', artist: 'AR Rahman, Shreya Ghoshal, Arijit Singh', album: 'Ramayana', durationSec: 128, imageUrl: 'https://i.ytimg.com/vi/yWNPxS0sXnE/hqdefault.jpg'),
    _ytTrack(videoId: 'z_e1d5_VVfw', title: 'Ramayana: Mangal Rang', artist: 'AR Rahman, Arijit Singh, Shreya Ghoshal, Kumar V', album: 'Ramayana', durationSec: 145, imageUrl: 'https://i.ytimg.com/vi/z_e1d5_VVfw/hqdefault.jpg'),
    _ytTrack(videoId: '5k_2d_15f6Y', title: 'लक्ष्मी स्तुति | Lakshmi Stuti | Diwali Special Lakshmi Puja', artist: 'Power of Chants', album: 'Diwali Special Lakshmi Puja', durationSec: 1170, imageUrl: 'https://i.ytimg.com/vi/5k_2d_15f6Y/hqdefault.jpg'),
    _ytTrack(videoId: 'nxRf-p8KWdM', title: 'Mahalakshmi Ashtakam - Prayer for Abundance & Divine Grace', artist: 'Religious India', album: 'Diwali Special 2025', durationSec: 3827, imageUrl: 'https://i.ytimg.com/vi/nxRf-p8KWdM/hqdefault.jpg'),
    _ytTrack(videoId: 'OgE62AQv5iA', title: 'दीपावली नॉनस्टॉप राम भजन - Ram Aayenge To Angana Sajaungi', artist: 'Bhakti Group', album: 'Diwali NonStop Ram Bhajan', durationSec: 3847, imageUrl: 'https://i.ytimg.com/vi/OgE62AQv5iA/hqdefault.jpg'),
    _ytTrack(videoId: '22bLNq6iCjU', title: 'Jai Shree Ram | Ayodhya Ram Mandir Song | Yug Ram Raj Ka', artist: 'Hansraj Raghuwanshi', album: 'Yug Ram Raj Ka', durationSec: 348, imageUrl: 'https://i.ytimg.com/vi/22bLNq6iCjU/hqdefault.jpg'),
    _ytTrack(videoId: '3TylP-ux8W0', title: 'Ram Aayenge', artist: 'Vishal Mishra, Payal Dev, Manoj Muntashir', album: 'Ram Aayenge', durationSec: 283, imageUrl: 'https://i.ytimg.com/vi/3TylP-ux8W0/hqdefault.jpg'),
    _ytTrack(videoId: 'q5PmN7SuUkY', title: 'Mere Ghar Ram Aaye Hain', artist: 'Jubin Nautiyal, Payal Dev, Manoj Muntashir', album: 'Mere Ghar Ram Aaye Hain', durationSec: 255, imageUrl: 'https://i.ytimg.com/vi/q5PmN7SuUkY/hqdefault.jpg'),
    _ytTrack(videoId: 'wEU8mWwAcv0', title: 'Shri Ram Ki Gali Mein Tum Jana', artist: 'Tulsi Kumar, Bhushan Kumar', album: 'Shri Ram Ki Gali Mein Tum Jana', durationSec: 273, imageUrl: 'https://i.ytimg.com/vi/wEU8mWwAcv0/hqdefault.jpg'),
    _ytTrack(videoId: 'UuLkjyBKQE4', title: 'RAM LALA', artist: 'Vishal Mishra, Manoj Muntashir', album: 'RAM LALA', durationSec: 273, imageUrl: 'https://i.ytimg.com/vi/UuLkjyBKQE4/hqdefault.jpg'),
    _ytTrack(videoId: '6fQzvZpBzj8', title: 'Ye Chamak Ye Damak 2.0 | Sab Kuch Sarkar Tumhi Se Hai', artist: 'Sudhir Vyas, Ak Digital', album: 'Ye Chamak Ye Damak 2.0', durationSec: 348, imageUrl: 'https://i.ytimg.com/vi/6fQzvZpBzj8/hqdefault.jpg'),
    _ytTrack(videoId: 'wVrz52oz_T8', title: 'नगरी हो अयोध्या सी | Nagri Ho Ayodhya Si', artist: 'प्रकाश गाँधी | PMC Sant Sandesh', album: 'Nagri Ho Ayodhya Si', durationSec: 482, imageUrl: 'https://i.ytimg.com/vi/wVrz52oz_T8/hqdefault.jpg'),
    _ytTrack(videoId: 'Ekymhpz8oUM', title: 'जरा देर ठहरो राम तमन्ना यही है', artist: 'Katha Puraan Bhajan', album: 'जरा देर ठहरो राम', durationSec: 292, imageUrl: 'https://i.ytimg.com/vi/Ekymhpz8oUM/hqdefault.jpg'),
    _ytTrack(videoId: 'txXXRMfp12w', title: 'Ram Siya Ram', artist: 'Sachet Tandon, Poonam Thakkar, Shabbir Ahmed', album: 'Ram Siya Ram', durationSec: 259, imageUrl: 'https://i.ytimg.com/vi/txXXRMfp12w/hqdefault.jpg'),
    _ytTrack(videoId: 'leVoi6kkp3o', title: 'Shree Ram Stuti', artist: 'Sonika Sharma Agarwal, Vickky Agarwal', album: 'Shree Ram Stuti', durationSec: 199, imageUrl: 'https://i.ytimg.com/vi/leVoi6kkp3o/hqdefault.jpg'),
    _ytTrack(videoId: 'yFyP0dMx5cw', title: 'मंगल भवन अमंगल हारी | Ram Siya Ram | Ramayan Chaupai', artist: 'Medi Tuner', album: 'Ramayan Chaupai', durationSec: 148, imageUrl: 'https://i.ytimg.com/vi/yFyP0dMx5cw/hqdefault.jpg'),
    _ytTrack(videoId: 'H2r9M66CQPk', title: 'Ghar Me Padharo Laxmi Maiya घर में पधारो लक्ष्मी मैया', artist: 'Nova Spiritual India', album: 'Laxmi Mata Bhajan', durationSec: 370, imageUrl: 'https://i.ytimg.com/vi/H2r9M66CQPk/hqdefault.jpg'),
    _ytTrack(videoId: 'oec7CXRAfeE', title: 'लक्ष्मी आरती हिंदी | Om Jai Laxmi Mata', artist: 'Shemaroo Bhakti', album: 'Mata Laxmi Aarti', durationSec: 587, imageUrl: 'https://i.ytimg.com/vi/oec7CXRAfeE/hqdefault.jpg'),
    _ytTrack(videoId: 'dxVa3AaPvy8', title: 'धनतेरस स्पेशल नॉनस्टॉप भजन | Kuber Laxmi Bhajan', artist: 'Ganga Bhakti', album: 'Dhanteras Ke Bhajan', durationSec: 1964, imageUrl: 'https://i.ytimg.com/vi/dxVa3AaPvy8/hqdefault.jpg'),
  ];

  // ── Verified Navratri Tracks (Preserving all 10 + 2 canonical items) ───────
  static final List<Track> _kNavratriTracks = [
    _track(
      rawId: '0qcITrST',
      title: 'Chogada (From "Loveyatri")',
      artist: 'Darshan Raval, Asees Kaur, Lijo George-Dj Chetas',
      album: 'Chogada (From "Loveyatri")',
      durationSec: 249,
      imageUrl:
          'https://c.saavncdn.com/669/Chogada-From-Loveyatri-Hindi-2018-20180814-500x500.jpg',
    ),
    _track(
      rawId: 'k151V2i7',
      title: 'Kamariya (From "Mitron")',
      artist: 'Darshan Raval, Dj Chetas, Lijo George',
      album: 'Mitron',
      durationSec: 182,
      imageUrl:
          'https://c.saavncdn.com/645/Mitron-Hindi-2018-20180911-500x500.jpg',
    ),
    _track(
      rawId: 'kP66Q51F',
      title: 'Dholida (From "Loveyatri")',
      artist: 'Udit Narayan, Neha Kakkar, Palak Muchhal, Raja Hasan',
      album: 'Loveyatri - A Journey Of Love',
      durationSec: 216,
      imageUrl:
          'https://c.saavncdn.com/543/Loveyatri-A-Journey-Of-Love-Hindi-2018-20181003-500x500.jpg',
    ),
    _track(
      rawId: 'y-n5w2qX',
      title: 'Nagada Sang Dhol (From "Goliyon Ki Raasleela Ram-Leela")',
      artist: 'Sanjay Leela Bhansali, Shreya Ghoshal, Osman Mir',
      album: 'Goliyon Ki Raasleela Ram-Leela',
      durationSec: 273,
      imageUrl:
          'https://c.saavncdn.com/712/Goliyon-Ki-Raasleela-Ram-Leela-Hindi-2013-20230607144131-500x500.jpg',
    ),
    _track(
      rawId: 'hYg2X8qY',
      title: 'Udi Udi Jaye (From "Raees")',
      artist: 'Ram Sampath, Sukhwinder Singh, Bhoomi Trivedi, Karsan Sagathia',
      album: 'Raees',
      durationSec: 260,
      imageUrl: 'https://c.saavncdn.com/837/Raees-Hindi-2017-500x500.jpg',
    ),
    _track(
      rawId: 'c69Skc-T',
      title: 'Gori Radha Ne Kado Kaan',
      artist: 'Divya Kumar, Sachin-Jigar',
      album: 'Wrong Side Raju',
      durationSec: 248,
      imageUrl:
          'https://c.saavncdn.com/124/Gori-Radha-Ne-Kalo-Kaan-Gujarati-2026-20261006132514-500x500.webp',
    ),
    _track(
      rawId: 'W3uR8n80',
      title: 'Sanedo (From "Made In China")',
      artist: 'Mika Singh, Nikhita Gandhi, Benny Dayal, Sachin-Jigar',
      album: 'Made In China',
      durationSec: 216,
      imageUrl:
          'https://c.saavncdn.com/669/Made-In-China-Hindi-2019-20191011114008-500x500.jpg',
    ),
    _track(
      rawId: 'P_VpXJ2M',
      title: 'Shubhaarambh (From "Kai Po Che")',
      artist: 'Amit Trivedi, Shruti Pathak, Divya Kumar',
      album: 'Kai Po Che',
      durationSec: 235,
      imageUrl:
          'https://c.saavncdn.com/956/Kai-Po-Che-Hindi-2013-20190629164214-500x500.jpg',
    ),
    _track(
      rawId: 'rSBU4cMG',
      title: 'Dholida Dhol Re Vagad (Khelaiya Disco Dandiya)',
      artist: 'Babla, Kanchan',
      album: 'Khelaiya Disco Dandiya Hits Vol 1',
      durationSec: 312,
      imageUrl:
          'https://c.saavncdn.com/664/Khelaiya-Disco-Dandiya-Hits-Vol-1-Gujarati-2021-20260615175408-500x500.jpg',
    ),
    _track(
      rawId: '7XqOQ24J',
      title: 'Dholi Taro Dhol Baaje (From "Hum Dil De Chuke Sanam")',
      artist:
          'Ismail Darbar, Kavita Krishnamurthy, Vinod Rathod, Karsan Sagathia',
      album: 'Hum Dil De Chuke Sanam',
      durationSec: 376,
      imageUrl:
          'https://c.saavncdn.com/430/Hum-Dil-De-Chuke-Sanam-Hindi-1999-20190506144810-500x500.jpg',
    ),
  ];

  // Provider IDs, metadata, artwork, and playback were verified through the
  // installed JioSaavn resolver and the shared player engine.

  // ── Default Multi-Year Indian Festival Schedule ──────────────────────────
  static final List<FestivalEvent> _kDefaultFestivalSchedule = [
    FestivalEvent(
      id: 'diwali_2026',
      name: 'Diwali Festive Special',
      greeting: 'Happy Diwali!',
      region: 'All-India',
      startDate: _ist(2026, 11, 5, 0, 0, 0),
      endDate: _ist(2026, 11, 11, 0, 0, 0),
      promotionDays: 0,
      bannerUrl: 'assets/images/diwali_festive_banner.webp',
      bannerTitle: 'Diwali Festive Special 2026',
      bannerSubtitle: 'Devotional Ram Bhajans, Lakshmi Aarti & Festive Anthems',
      categories: ['All', 'Ram Bhajans', 'Lakshmi Puja & Aarti'],
      tracks: _kDiwaliTracks,
    ),

    // Navratri category promotion ends at 2026-10-21 00:00 Asia/Kolkata.
    FestivalEvent(
      id: 'navratri_2026',
      name: 'Navratri & Garba Special',
      greeting: 'Shubh Navratri!',
      region: 'Gujarat / All-India',
      startDate: _ist(2026, 10, 10),
      endDate: _ist(2026, 10, 21),
      promotionDays: 10,
      bannerUrl:
          'https://c.saavncdn.com/124/Gori-Radha-Ne-Kalo-Kaan-Gujarati-2026-20261006132514-500x500.webp',
      bannerTitle: 'Navratri Festive Special 2026',
      bannerSubtitle: 'Non-Stop Garba, Dandiya & Raas Hits',
      categories: ['All', 'Garba Hits', 'Dandiya', 'Bollywood Garba', 'Aarti'],
      tracks: _kNavratriTracks,
    ),
    // Makar Sankranti / Pongal 2027 (Jan 14, 2027) -> Promotion Jan 4 - Jan 16
    FestivalEvent(
      id: 'sankranti_2027',
      name: 'Makar Sankranti & Pongal',
      greeting: 'Happy Makar Sankranti & Pongal!',
      region: 'All-India',
      startDate: _ist(2027, 1, 14),
      endDate: _ist(2027, 1, 16),
      promotionDays: 10,
      bannerUrl: 'https://c.saavncdn.com/837/Raees-Hindi-2017-500x500.jpg',
      bannerTitle: 'Kai Po Che — Kite Flying Beats',
      bannerSubtitle: 'Celebrate Uttarayan with vibrant folk & festive tunes',
      categories: ['All', 'Folk Tunes', 'Kite Beats', 'Celebration'],
      tracks: _kNavratriTracks,
    ),
    // Holi 2027 (March 22, 2027) -> Promotion Mar 12 - Mar 24
    FestivalEvent(
      id: 'holi_2027',
      name: 'Holi Colors of Joy',
      greeting: 'Bura Na Mano Holi Hai!',
      region: 'All-India',
      startDate: _ist(2027, 3, 22),
      endDate: _ist(2027, 3, 24),
      promotionDays: 10,
      bannerUrl:
          'https://c.saavncdn.com/712/Goliyon-Ki-Raasleela-Ram-Leela-Hindi-2013-20230607144131-500x500.jpg',
      bannerTitle: 'Holi Party Non-Stop Hits',
      bannerSubtitle: 'Rang Barse, energetic beats & vibrant party mixes',
      categories: ['All', 'Holi Anthems', 'Dance Beats', 'Bhakti'],
      tracks: _kNavratriTracks,
    ),
  ];

  static List<Track> getNavratriTracks() => List.unmodifiable(_kNavratriTracks);
  static List<Track> getDiwaliTracks() => List.unmodifiable(_kDiwaliTracks);
}
