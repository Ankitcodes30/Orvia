import 'dart:convert';
import 'dart:developer';

import 'package:Orvia/core/models/exported.dart' hide Lyrics;
import 'package:Orvia/core/models/lyrics_models.dart';
import 'package:http/http.dart' as http;

/// Direct, native fallback service for LRCLIB (https://lrclib.net).
/// Provides synchronized and plain lyrics when WASM plugins are unavailable,
/// offline, or fail to resolve.
class LrclibLyricsService {
  static const String baseUrl = 'https://lrclib.net/api';
  static const String userAgent =
      'OrviaMusicPlayer/3.0.7 (https://github.com/ankitcodes30/Orvia)';
  static const Duration timeout = Duration(seconds: 10);

  /// Fetch lyrics for a [track] using exact metadata match, falling back to search.
  static Future<Lyrics?> fetchLyrics({
    required Track track,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final title = sanitizeTitle(track.title);
      final artists = track.artists
          .map((a) => a.name.trim())
          .where((n) => n.isNotEmpty)
          .toList(growable: false);
      final primaryArtist = artists.isNotEmpty ? artists.first : '';
      final allArtists = artists.join(', ');
      final durationSec = track.durationMs != null
          ? (track.durationMs! ~/ BigInt.from(1000)).toInt()
          : null;

      // 1. Try exact get with primary artist
      if (primaryArtist.isNotEmpty) {
        final exact = await _tryGet(
          httpClient: httpClient,
          trackName: title,
          artistName: primaryArtist,
          albumName: track.album?.title,
          durationSec: durationSec,
          mediaId: track.id,
        );
        if (exact != null) return exact;
      }

      // 1b. Try exact get with all artists joined
      if (artists.length > 1) {
        final exactAll = await _tryGet(
          httpClient: httpClient,
          trackName: title,
          artistName: allArtists,
          albumName: track.album?.title,
          durationSec: durationSec,
          mediaId: track.id,
        );
        if (exactAll != null) return exactAll;
      }

      // 2. Fallback to query search
      final queries = <String>[
        if (primaryArtist.isNotEmpty) '$title $primaryArtist',
        if (artists.length > 1) '$title $allArtists',
        title,
      ];

      for (final query in queries) {
        final results = await search(query: query, client: httpClient);
        if (results.isNotEmpty) {
          // Find best candidate matching duration or title
          final best = _findBestMatch(results, track);
          if (best != null) {
            return best.copyWith(mediaID: track.id);
          }
        }
      }

      return null;
    } catch (e, stack) {
      log('LrclibLyricsService.fetchLyrics error: $e\n$stack',
          name: 'LrclibLyricsService');
      return null;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  static Future<Lyrics?> _tryGet({
    required http.Client httpClient,
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSec,
    required String mediaId,
  }) async {
    try {
      final params = <String, String>{
        'track_name': trackName,
        'artist_name': artistName,
        if (albumName != null && albumName.trim().isNotEmpty)
          'album_name': albumName.trim(),
        if (durationSec != null && durationSec > 0)
          'duration': durationSec.toString(),
      };

      final uri = Uri.parse('$baseUrl/get').replace(queryParameters: params);
      final response = await httpClient.get(
        uri,
        headers: {'User-Agent': userAgent},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return _parseRecord(data, fallbackMediaId: mediaId);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Search LRCLIB for candidate lyrics matching a free-text [query].
  static Future<List<Lyrics>> search({
    required String query,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final cleanQuery = query.trim();
      if (cleanQuery.isEmpty) return const [];

      final uri = Uri.parse('$baseUrl/search')
          .replace(queryParameters: {'q': cleanQuery});
      final response = await httpClient.get(
        uri,
        headers: {'User-Agent': userAgent},
      ).timeout(timeout);

      if (response.statusCode != 200) return const [];

      final list = jsonDecode(response.body);
      if (list is! List) return const [];

      final results = <Lyrics>[];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final parsed = _parseRecord(item, fallbackMediaId: '');
          if (parsed != null) {
            results.add(parsed);
          }
        }
      }
      return results;
    } catch (e) {
      log('LrclibLyricsService.search error: $e', name: 'LrclibLyricsService');
      return const [];
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  static Lyrics? _parseRecord(
    Map<String, dynamic> data, {
    required String fallbackMediaId,
  }) {
    final isInstrumental = data['instrumental'] as bool? ?? false;
    final plain = (data['plainLyrics'] as String?)?.trim() ?? '';
    final synced = (data['syncedLyrics'] as String?)?.trim();

    if (plain.isEmpty && (synced == null || synced.isEmpty)) {
      if (isInstrumental) {
        return Lyrics(
          id: data['id']?.toString() ?? fallbackMediaId,
          artist: data['artistName']?.toString() ?? '',
          title: data['trackName']?.toString() ?? '',
          album: data['albumName']?.toString(),
          lyricsPlain: '♪ Instrumental ♪',
          lyricsSynced: null,
          duration: data['duration']?.toString(),
          provider: LyricsProvider.plugin,
          mediaID: fallbackMediaId,
        );
      }
      return null;
    }

    final id = data['id']?.toString() ?? fallbackMediaId;
    final artist = data['artistName']?.toString() ?? '';
    final title = data['trackName']?.toString() ?? '';
    final album = data['albumName']?.toString();
    final duration = data['duration']?.toString();

    return Lyrics(
      id: id,
      artist: artist,
      title: title,
      album: album,
      lyricsPlain: plain.isNotEmpty ? plain : (synced ?? ''),
      lyricsSynced: synced,
      duration: duration,
      provider: LyricsProvider.plugin,
      mediaID: fallbackMediaId,
    );
  }

  static Lyrics? _findBestMatch(List<Lyrics> candidates, Track track) {
    if (candidates.isEmpty) return null;

    final targetTitle = _normalize(track.title);
    final targetDuration = track.durationMs != null
        ? (track.durationMs! ~/ BigInt.from(1000)).toInt()
        : null;

    Lyrics? best;
    int bestScore = -1;

    for (final cand in candidates) {
      int score = 0;
      final candTitle = _normalize(cand.title);

      if (candTitle == targetTitle) {
        score += 50;
      } else if (candTitle.contains(targetTitle) ||
          targetTitle.contains(candTitle)) {
        score += 25;
      }

      if (cand.lyricsSynced != null && cand.lyricsSynced!.isNotEmpty) {
        score += 20;
      }

      if (targetDuration != null && cand.duration != null) {
        final candDuration = double.tryParse(cand.duration!)?.round();
        if (candDuration != null) {
          final diff = (targetDuration - candDuration).abs();
          if (diff <= 3) {
            score += 30;
          } else if (diff <= 8) {
            score += 15;
          }
        }
      }

      if (score > bestScore) {
        bestScore = score;
        best = cand;
      }
    }

    return bestScore >= 25 ? best : candidates.first;
  }

  static String sanitizeTitle(String title) {
    var clean = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Remove (From "Movie"), (Feat. ...), [Official Video]
    clean = clean.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), '').trim();
    return clean.isEmpty ? title : clean;
  }

  static String _normalize(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}
