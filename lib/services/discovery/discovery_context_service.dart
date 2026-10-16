import 'dart:developer';
import 'package:permission_handler/permission_handler.dart';

/// Enumeration of daypart time slots for context-aware discovery.
enum Daypart {
  morning,   // 6:00 AM - 11:00 AM (Devotional, Energetic Hindi, Morning Classical)
  afternoon, // 11:00 AM - 5:00 PM (Trending, New Releases, Regional Chartbusters)
  evening,   // 5:00 PM - 9:00 PM (90s Hits, Radio, Familiar Favorites, Relaxed Mixes)
  night,     // 9:00 PM - 2:00 AM (Lo-fi, Acoustic, Romance, Chillout)
  lateNight, // 2:00 AM - 6:00 AM (Ambient, Sleep, Instrumental)
}

/// Service providing non-blocking Location-Aware recommendations and
/// Time-Aware daypart contextual heuristics.
class DiscoveryContextService {
  static Daypart getCurrentDaypart({DateTime? testTime}) {
    final now = testTime ?? DateTime.now();
    final hour = now.hour;

    if (hour >= 6 && hour < 11) {
      return Daypart.morning;
    } else if (hour >= 11 && hour < 17) {
      return Daypart.afternoon;
    } else if (hour >= 17 && hour < 21) {
      return Daypart.evening;
    } else if (hour >= 21 || hour < 2) {
      return Daypart.night;
    } else {
      return Daypart.lateNight;
    }
  }

  static String getDaypartTitle(Daypart daypart) {
    switch (daypart) {
      case Daypart.morning:
        return 'Morning Melodies & Energy';
      case Daypart.afternoon:
        return 'Afternoon Hits & Regional Trends';
      case Daypart.evening:
        return 'Evening Favorites & 90s Classics';
      case Daypart.night:
        return 'Late Night Chill & Lo-fi';
      case Daypart.lateNight:
        return 'Peaceful Night & Ambient';
    }
  }

  static String getDaypartQuery(Daypart daypart) {
    switch (daypart) {
      case Daypart.morning:
        return 'Morning Hindi Bhakti Energetic Hits';
      case Daypart.afternoon:
        return 'Latest Trending Hindi Punjabi Chartbusters';
      case Daypart.evening:
        return 'Best of 90s Bollywood Evergreen Hits';
      case Daypart.night:
        return 'Hindi Lofi Acoustic Chill Midnight Beats';
      case Daypart.lateNight:
        return 'Deep Sleep Ambient Instrumental Relaxing';
    }
  }

  // ── Location Awareness ───────────────────────────────────────────────────

  static bool _hasPromptedLocation = false;
  static String _cachedRegion = 'India (National)';

  /// Returns the current regional label for "What's Hot Near You".
  /// Falls back to "India (National)" without ever blocking the homepage.
  static String get currentRegionLabel => _cachedRegion;

  /// Asynchronously requests location permission only when explicitly triggered.
  /// Handles denial gracefully without reprompting.
  static Future<String> checkOrRequestLocationRegion() async {
    try {
      final status = await Permission.locationWhenInUse.status;
      if (status.isGranted) {
        _cachedRegion = 'India (Local Trends)';
        return _cachedRegion;
      }

      if (!_hasPromptedLocation && !status.isPermanentlyDenied) {
        _hasPromptedLocation = true;
        final result = await Permission.locationWhenInUse.request();
        if (result.isGranted) {
          _cachedRegion = 'India (Local Trends)';
          return _cachedRegion;
        }
      }
    } catch (e) {
      log('Location permission check handled safely: $e',
          name: 'DiscoveryContextService');
    }

    _cachedRegion = 'India (National)';
    return _cachedRegion;
  }
}
