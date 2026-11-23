import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:Orvia/core/models/lyrics_models.dart';

class LrcLibLyricsService {
  static const String _baseUrl = 'https://lrclib.net/api';

  static String _cleanTitle(String title) {
    return title
        .replaceAll(RegExp(r'\(.*?(official|video|audio|lyric|remix|hd|4k).*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[.*?(official|video|audio|lyric|remix|hd|4k).*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\|.*$'), '')
        .trim();
  }

  /// Fetches synchronized and plain lyrics from LRCLIB.
  static Future<Lyrics?> fetchLyrics({
    required String trackId,
    required String title,
    required String artist,
    String? album,
    int? durationSec,
  }) async {
    final cleanTitle = _cleanTitle(title);
    final cleanArtist = artist.split(',').first.trim();

    // 1. Try exact get
    try {
      final queryParams = {
        'track_name': cleanTitle,
        'artist_name': cleanArtist,
        if (album != null && album.isNotEmpty) 'album_name': album,
        if (durationSec != null && durationSec > 0) 'duration': durationSec.toString(),
      };

      final uri = Uri.parse('$_baseUrl/get').replace(queryParameters: queryParams);
      final res = await http.get(
        uri,
        headers: {'User-Agent': 'OrviaMusic/3.0.7 (https://github.com/Ankitcodes30/Orvia)'},
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final synced = data['syncedLyrics'] as String?;
        final plain = (data['plainLyrics'] as String?) ?? synced ?? '';

        if (plain.trim().isNotEmpty) {
          log('LRCLIB: Exact match found for "$title"', name: 'LrcLibService');
          return Lyrics(
            id: trackId,
            mediaID: trackId,
            title: title,
            artist: artist,
            album: album,
            lyricsPlain: plain,
            lyricsSynced: synced,
            duration: durationSec?.toString(),
            provider: LyricsProvider.lrclib,
          );
        }
      }
    } catch (e) {
      log('LRCLIB get error: $e', name: 'LrcLibService');
    }

    // 2. Fallback: Search endpoint
    try {
      final searchUri = Uri.parse('$_baseUrl/search').replace(
        queryParameters: {'q': '$cleanTitle $cleanArtist'},
      );

      final res = await http.get(
        searchUri,
        headers: {'User-Agent': 'OrviaMusic/3.0.7'},
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        if (list.isNotEmpty) {
          // Find first entry with syncedLyrics or plainLyrics
          final best = list.firstWhere(
            (item) => item['syncedLyrics'] != null || item['plainLyrics'] != null,
            orElse: () => list.first,
          ) as Map<String, dynamic>;

          final synced = best['syncedLyrics'] as String?;
          final plain = (best['plainLyrics'] as String?) ?? synced ?? '';

          if (plain.trim().isNotEmpty) {
            log('LRCLIB: Search match found for "$title"', name: 'LrcLibService');
            return Lyrics(
              id: trackId,
              mediaID: trackId,
              title: title,
              artist: artist,
              album: album,
              lyricsPlain: plain,
              lyricsSynced: synced,
              duration: durationSec?.toString(),
              provider: LyricsProvider.lrclib,
            );
          }
        }
      }
    } catch (e) {
      log('LRCLIB search fallback error: $e', name: 'LrcLibService');
    }

    return null;
  }
}
