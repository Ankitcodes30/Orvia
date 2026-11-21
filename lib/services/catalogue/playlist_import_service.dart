import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:Orvia/plugins/utils/media_id.dart';
import 'package:Orvia/src/rust/api/plugin/models.dart';

enum ImportPlatform {
  spotify,
  youtube,
  jiosaavn,
  unknown,
}

class PlaylistImportResult {
  final bool isSuccess;
  final ImportPlatform platform;
  final ImportCollectionSummary? summary;
  final List<ImportTrackItem> tracks;
  final String? errorMessage;
  final int sourceCount;
  final int importedCount;
  final int duplicateCount;
  final int unavailableCount;
  final List<String> unmatchedTrackTitles;

  const PlaylistImportResult({
    required this.isSuccess,
    required this.platform,
    this.summary,
    this.tracks = const [],
    this.errorMessage,
    this.sourceCount = 0,
    this.importedCount = 0,
    this.duplicateCount = 0,
    this.unavailableCount = 0,
    this.unmatchedTrackTitles = const [],
  });
}

/// Service handling playlist imports from YouTube, Spotify, and JioSaavn.
/// Extracts playlist metadata and track items, then feeds them into the
/// existing [ContentImportCubit] and [CrossPluginResolver] architecture.
class PlaylistImportService {
  PlaylistImportService._();

  static const Duration _timeout = Duration(seconds: 12);

  /// Detects the platform of a URL.
  static ImportPlatform detectPlatform(String url) {
    final lower = url.trim().toLowerCase();
    if (lower.contains('spotify.com')) return ImportPlatform.spotify;
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return ImportPlatform.youtube;
    }
    if (lower.contains('jiosaavn.com') || lower.contains('saavn.com')) {
      return ImportPlatform.jiosaavn;
    }
    return ImportPlatform.unknown;
  }

  /// Validates whether the given URL is supported for import.
  static bool isValidImportUrl(String url) {
    final p = detectPlatform(url);
    return p != ImportPlatform.unknown && Uri.tryParse(url)?.hasScheme == true;
  }

  /// Imports tracks and metadata from a given URL.
  static Future<PlaylistImportResult> importFromUrl(String url) async {
    final platform = detectPlatform(url);
    if (platform == ImportPlatform.unknown) {
      return const PlaylistImportResult(
        isSuccess: false,
        platform: ImportPlatform.unknown,
        errorMessage:
            'Unsupported URL. Please provide a valid YouTube, Spotify, or JioSaavn playlist/album URL.',
      );
    }

    try {
      switch (platform) {
        case ImportPlatform.jiosaavn:
          return await _importJioSaavn(url);
        case ImportPlatform.spotify:
          return await _importSpotify(url);
        case ImportPlatform.youtube:
          return await _importYouTube(url);
        case ImportPlatform.unknown:
          return const PlaylistImportResult(
            isSuccess: false,
            platform: ImportPlatform.unknown,
            errorMessage: 'Unknown platform.',
          );
      }
    } catch (e, stack) {
      log('Playlist import failed for $url: $e',
          error: e, stackTrace: stack, name: 'PlaylistImportService');
      return PlaylistImportResult(
        isSuccess: false,
        platform: platform,
        errorMessage: 'Import failed: $e',
      );
    }
  }

  // ==========================================
  // JIOSAAVN IMPORT
  // ==========================================
  static Future<PlaylistImportResult> _importJioSaavn(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) {
      return const PlaylistImportResult(
        isSuccess: false,
        platform: ImportPlatform.jiosaavn,
        errorMessage: 'Invalid JioSaavn URL.',
      );
    }

    // Extract token from URL path: e.g. /featured/<token>/<id> or /album/<token>/<id>
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    String? token;
    String type = 'playlist';

    if (segments.contains('featured') || segments.contains('playlist')) {
      type = 'playlist';
      final idx = segments.contains('featured')
          ? segments.indexOf('featured')
          : segments.indexOf('playlist');
      if (idx + 1 < segments.length) token = segments[idx + 1];
    } else if (segments.contains('album')) {
      type = 'album';
      final idx = segments.indexOf('album');
      if (idx + 1 < segments.length) token = segments[idx + 1];
    } else if (segments.contains('song')) {
      type = 'song';
      final idx = segments.indexOf('song');
      if (idx + 1 < segments.length) token = segments[idx + 1];
    }

    if (token == null && segments.isNotEmpty) {
      token = segments.last;
    }

    if (token == null || token.isEmpty) {
      return const PlaylistImportResult(
        isSuccess: false,
        platform: ImportPlatform.jiosaavn,
        errorMessage: 'Could not extract JioSaavn collection token from URL.',
      );
    }

    final apiUrl =
        'https://www.jiosaavn.com/api.php?__call=webapi.get&token=$token&type=$type&_format=json&_marker=0&api_version=4&ctx=web6dot0&n=200';

    final resp = await http.get(Uri.parse(apiUrl), headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    }).timeout(_timeout);

    if (resp.statusCode != 200) {
      return PlaylistImportResult(
        isSuccess: false,
        platform: ImportPlatform.jiosaavn,
        errorMessage:
            'JioSaavn server responded with HTTP status ${resp.statusCode}',
      );
    }

    final data = json.decode(resp.body);
    final title = (data['title'] ?? data['name'] ?? 'JioSaavn Playlist').toString();
    final image = (data['image'] ?? '').toString().replaceAll('150x150', '500x500');

    final rawSongs = data['list'] ?? data['songs'] ?? [];
    final tracks = <ImportTrackItem>[];
    final seenIds = <String>{};
    var duplicateCount = 0;
    var unavailableCount = 0;
    final unavailableTitles = <String>[];

    if (rawSongs is List) {
      for (final s in rawSongs) {
        if (s is Map) {
          final sTitle = (s['title'] ?? s['song'] ?? '').toString().trim();
          final artistStr = (s['primary_artists'] ??
                  s['singers'] ??
                  s['more_info']?['music'] ??
                  '')
              .toString()
              .trim();
          final artists = artistStr.isNotEmpty
              ? artistStr.split(',').map((a) => a.trim()).toList()
              : <String>[];
          final album = (s['album'] ?? '').toString().trim();
          final thumb = (s['image'] ?? image).toString().replaceAll('150x150', '500x500');
          final durationSec = int.tryParse(s['duration']?.toString() ?? '0');
          final permaUrl = s['perma_url']?.toString();
          final sId = s['id']?.toString() ?? permaUrl ?? sTitle;

          if (sTitle.isEmpty) {
            unavailableCount++;
            continue;
          }

          if (!seenIds.add(sId)) {
            duplicateCount++;
            continue;
          }

          final jioId = s['id']?.toString();
          final stampedSourceId = (jioId != null && jioId.isNotEmpty)
              ? (isStampedId(jioId) ? jioId : buildMediaId(kDefaultSaavnPluginId, jioId))
              : null;

          tracks.add(
            ImportTrackItem(
              sourceId: stampedSourceId,
              title: sTitle,
              artists: artists,
              albumTitle: album.isNotEmpty ? album : null,
              thumbnailUrl: thumb.isNotEmpty ? thumb : null,
              durationMs: durationSec != null && durationSec > 0
                  ? BigInt.from(durationSec * 1000)
                  : null,
              isExplicit: false,
              url: permaUrl,
            ),
          );
        }
      }
    }

    if (tracks.isEmpty) {
      return const PlaylistImportResult(
        isSuccess: false,
        platform: ImportPlatform.jiosaavn,
        errorMessage: 'No playable tracks found in this JioSaavn collection.',
      );
    }

    final summary = ImportCollectionSummary(
      title: title,
      kind: type == 'album' ? ImportCollectionType.album : ImportCollectionType.playlist,
      trackCount: tracks.length,
      thumbnailUrl: image.isNotEmpty ? image : null,
    );

    return PlaylistImportResult(
      isSuccess: true,
      platform: ImportPlatform.jiosaavn,
      summary: summary,
      tracks: tracks,
      sourceCount: tracks.length + duplicateCount + unavailableCount,
      importedCount: tracks.length,
      duplicateCount: duplicateCount,
      unavailableCount: unavailableCount,
      unmatchedTrackTitles: unavailableTitles,
    );
  }

  // ==========================================
  // SPOTIFY IMPORT
  // ==========================================
  static Future<PlaylistImportResult> _importSpotify(String url) async {
    // 1. Fetch oEmbed metadata for title & thumbnail
    final oembedUrl =
        'https://open.spotify.com/oembed?url=${Uri.encodeComponent(url)}';
    String title = 'Spotify Playlist';
    String? thumbUrl;

    try {
      final oembedResp = await http.get(Uri.parse(oembedUrl)).timeout(_timeout);
      if (oembedResp.statusCode == 200) {
        final oembedJson = json.decode(oembedResp.body);
        if (oembedJson['title'] != null) {
          title = oembedJson['title'].toString();
        }
        if (oembedJson['thumbnail_url'] != null) {
          thumbUrl = oembedJson['thumbnail_url'].toString();
        }
      }
    } catch (e) {
      log('Spotify oEmbed fetch failed: $e', name: 'PlaylistImportService');
    }

    // 2. Fetch embed HTML to parse track list
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    final playlistIdx = segments.indexOf('playlist');
    final albumIdx = segments.indexOf('album');

    String? embedPath;
    if (playlistIdx != -1 && playlistIdx + 1 < segments.length) {
      embedPath = 'embed/playlist/${segments[playlistIdx + 1]}';
    } else if (albumIdx != -1 && albumIdx + 1 < segments.length) {
      embedPath = 'embed/album/${segments[albumIdx + 1]}';
    }

    final tracks = <ImportTrackItem>[];

    if (embedPath != null) {
      try {
        final embedUrl = 'https://open.spotify.com/$embedPath';
        final embedResp = await http.get(Uri.parse(embedUrl), headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        }).timeout(_timeout);

        if (embedResp.statusCode == 200) {
          final html = embedResp.body;
          // Look for NEXT_DATA JSON or resource script
          final match = RegExp(
                  r'<script id="__NEXT_DATA__" type="application/json">([^<]+)</script>')
              .firstMatch(html);
          if (match != null) {
            final jsonStr = match.group(1);
            if (jsonStr != null) {
              final root = json.decode(jsonStr);
              final entity = root['props']?['pageProps']?['state']?['data']?['entity'];
              if (entity != null) {
                final trackList = entity['trackList'] ?? entity['tracks']?['items'] ?? [];
                if (trackList is List) {
                  for (final item in trackList) {
                    final tName = item['title'] ?? item['name'];
                    final tSubtitle = item['subtitle'] ?? '';
                    final tDuration = item['duration'];

                    if (tName != null && tName.toString().trim().isNotEmpty) {
                      final artists = tSubtitle.toString().isNotEmpty
                          ? tSubtitle.toString().split(',').map((a) => a.trim()).toList()
                          : <String>[];
                      tracks.add(
                        ImportTrackItem(
                          title: tName.toString().trim(),
                          artists: artists,
                          albumTitle: title,
                          thumbnailUrl: thumbUrl,
                          durationMs: tDuration is int ? BigInt.from(tDuration) : null,
                          isExplicit: false,
                        ),
                      );
                    }
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        log('Spotify embed parsing failed: $e', name: 'PlaylistImportService');
      }
    }

    if (tracks.isEmpty) {
      // Single track fallback if URL was a track URL
      if (segments.contains('track') && title != 'Spotify Playlist') {
        tracks.add(
          ImportTrackItem(
            title: title,
            artists: const [],
            thumbnailUrl: thumbUrl,
            isExplicit: false,
          ),
        );
      } else {
        return const PlaylistImportResult(
          isSuccess: false,
          platform: ImportPlatform.spotify,
          errorMessage:
              'Could not extract tracks from Spotify link. Ensure the playlist is Public and not restricted by Spotify authentication/DRM.',
        );
      }
    }

    final summary = ImportCollectionSummary(
      title: title,
      kind: ImportCollectionType.playlist,
      trackCount: tracks.length,
      thumbnailUrl: thumbUrl,
    );

    return PlaylistImportResult(
      isSuccess: true,
      platform: ImportPlatform.spotify,
      summary: summary,
      tracks: tracks,
    );
  }

  // ==========================================
  // YOUTUBE IMPORT
  // ==========================================
  static Future<PlaylistImportResult> _importYouTube(String url) async {
    // 1. Normalize YouTube Music / short URLs to desktop www.youtube.com for complete playlist scraping
    var normalizedUrl = url.trim();
    if (normalizedUrl.contains('music.youtube.com')) {
      normalizedUrl = normalizedUrl.replaceFirst('music.youtube.com', 'www.youtube.com');
    }

    // 1. Fetch oEmbed metadata
    final oembedUrl =
        'https://www.youtube.com/oembed?url=${Uri.encodeComponent(normalizedUrl)}&format=json';
    String title = 'YouTube Playlist';
    String? thumbUrl;

    try {
      final oembedResp = await http.get(Uri.parse(oembedUrl)).timeout(_timeout);
      if (oembedResp.statusCode == 200) {
        final oembedJson = json.decode(oembedResp.body);
        if (oembedJson['title'] != null) {
          title = oembedJson['title'].toString();
        }
        if (oembedJson['thumbnail_url'] != null) {
          thumbUrl = oembedJson['thumbnail_url'].toString();
        }
      }
    } catch (e) {
      log('YouTube oEmbed fetch failed: $e', name: 'PlaylistImportService');
    }

    // 2. Fetch public HTML to extract videos from ytInitialData
    final tracks = <ImportTrackItem>[];
    final seenVideoIds = <String>{};
    var duplicateCount = 0;
    var unavailableCount = 0;
    final unavailableTitles = <String>[];

    try {
      final pageResp = await http.get(Uri.parse(normalizedUrl), headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      }).timeout(_timeout);

      if (pageResp.statusCode == 200) {
        final html = pageResp.body;

        // Try extracting ytInitialData JSON structure
        final match = RegExp(
          r'(?:var\s+ytInitialData\s*=\s*|ytInitialData\s*=\s*)({.*?});(?:<\/script>|\n|\r)',
          dotAll: true,
        ).firstMatch(html);

        if (match != null) {
          try {
            final data = json.decode(match.group(1)!) as Map<String, dynamic>;
            final renderers = _collectPlaylistVideoRenderers(data);

            for (final pvr in renderers) {
              final videoId = pvr['videoId']?.toString() ?? '';
              final rawTitle = pvr['title']?['runs']?[0]?['text']?.toString() ??
                  pvr['title']?['simpleText']?.toString() ??
                  '';
              final author = pvr['shortBylineText']?['runs']?[0]?['text']?.toString() ??
                  pvr['shortBylineText']?['simpleText']?.toString() ??
                  '';
              final durationSec = int.tryParse(pvr['lengthSeconds']?.toString() ?? '0') ?? 0;

              String? itemThumb = thumbUrl;
              final thumbs = pvr['thumbnail']?['thumbnails'];
              if (thumbs is List && thumbs.isNotEmpty) {
                final lastThumb = thumbs.last;
                if (lastThumb is Map && lastThumb['url'] != null) {
                  itemThumb = lastThumb['url'].toString();
                }
              }

              if (videoId.isEmpty ||
                  rawTitle.isEmpty ||
                  rawTitle == '[Deleted video]' ||
                  rawTitle == '[Private video]') {
                unavailableCount++;
                if (rawTitle.isNotEmpty) unavailableTitles.add(rawTitle);
                continue;
              }

              if (!seenVideoIds.add(videoId)) {
                duplicateCount++;
                continue;
              }

              final cleaned = _parseYouTubeTitle(rawTitle, fallbackArtist: author);
              tracks.add(
                ImportTrackItem(
                  sourceId: videoId,
                  url: 'https://www.youtube.com/watch?v=$videoId',
                  title: cleaned.title,
                  artists: cleaned.artists,
                  durationMs: durationSec > 0 ? BigInt.from(durationSec * 1000) : null,
                  thumbnailUrl: itemThumb,
                  isExplicit: false,
                ),
              );
            }
          } catch (e) {
            log('ytInitialData parsing failed: $e', name: 'PlaylistImportService');
          }
        }

        // Fallback regex matching if ytInitialData did not find tracks
        if (tracks.isEmpty) {
          final titleMatches = RegExp(r'"title":\{"runs":\[\{"text":"([^"]+)"\}\]').allMatches(html);
          for (final m in titleMatches) {
            final rawTitle = m.group(1)?.trim();
            if (rawTitle != null &&
                rawTitle.isNotEmpty &&
                rawTitle != title &&
                !rawTitle.toLowerCase().contains('view full playlist') &&
                seenVideoIds.add(rawTitle)) {
              final cleaned = _parseYouTubeTitle(rawTitle);
              tracks.add(
                ImportTrackItem(
                  title: cleaned.title,
                  artists: cleaned.artists,
                  thumbnailUrl: thumbUrl,
                  isExplicit: false,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      log('YouTube playlist parsing failed: $e', name: 'PlaylistImportService');
    }

    if (tracks.isEmpty) {
      // Single video fallback if title was resolved
      if (title != 'YouTube Playlist') {
        final cleaned = _parseYouTubeTitle(title);
        tracks.add(
          ImportTrackItem(
            title: cleaned.title,
            artists: cleaned.artists,
            thumbnailUrl: thumbUrl,
            isExplicit: false,
          ),
        );
      } else {
        return const PlaylistImportResult(
          isSuccess: false,
          platform: ImportPlatform.youtube,
          errorMessage:
              'Could not extract videos from YouTube playlist. Ensure the playlist is Public or Unlisted.',
        );
      }
    }

    final summary = ImportCollectionSummary(
      title: title,
      kind: ImportCollectionType.playlist,
      trackCount: tracks.length,
      thumbnailUrl: thumbUrl,
    );

    return PlaylistImportResult(
      isSuccess: true,
      platform: ImportPlatform.youtube,
      summary: summary,
      tracks: tracks,
      sourceCount: tracks.length + duplicateCount + unavailableCount,
      importedCount: tracks.length,
      duplicateCount: duplicateCount,
      unavailableCount: unavailableCount,
      unmatchedTrackTitles: unavailableTitles,
    );
  }

  static List<Map<String, dynamic>> _collectPlaylistVideoRenderers(dynamic node) {
    final results = <Map<String, dynamic>>[];
    void search(dynamic current) {
      if (current is Map<String, dynamic>) {
        if (current.containsKey('playlistVideoRenderer') &&
            current['playlistVideoRenderer'] is Map<String, dynamic>) {
          results.add(current['playlistVideoRenderer'] as Map<String, dynamic>);
        }
        for (final v in current.values) {
          search(v);
        }
      } else if (current is List) {
        for (final item in current) {
          search(item);
        }
      }
    }
    search(node);
    return results;
  }

  static ({String title, List<String> artists}) _parseYouTubeTitle(
    String raw, {
    String? fallbackArtist,
  }) {
    var cleaned = raw
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'\(official.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(lyric.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(video.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(audio.*?\)', caseSensitive: false), '')
        .trim();

    if (cleaned.contains(' - ')) {
      final parts = cleaned.split(' - ');
      final artist = parts[0].trim();
      final songTitle = parts.sublist(1).join(' - ').trim();
      return (
        title: songTitle.isNotEmpty ? songTitle : cleaned,
        artists: [artist],
      );
    } else if (cleaned.contains(' | ')) {
      final parts = cleaned.split(' | ');
      final songTitle = parts[0].trim();
      return (
        title: songTitle.isNotEmpty ? songTitle : cleaned,
        artists: (fallbackArtist != null && fallbackArtist.isNotEmpty)
            ? [fallbackArtist]
            : const [],
      );
    }

    return (
      title: cleaned,
      artists: (fallbackArtist != null && fallbackArtist.isNotEmpty)
          ? [fallbackArtist]
          : const [],
    );
  }
}
