import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' hide log;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/core/utils/track_identity.dart';
import 'package:Orvia/plugins/utils/media_id.dart';
import 'orvia_deep_link_service.dart';

/// Abstract interface for short link creation and resolution.
abstract interface class ShortLinkResolver {
  /// Attempts to create and store a short link for the given playlist.
  /// Returns the short ID on success, or null if unconfigured, offline, or failed.
  Future<String?> createShortLink({
    required String title,
    String? description,
    String? artworkUrl,
    required List<Track> tracks,
  });

  /// Resolves a short ID to a hydrated [Playlist].
  /// Returns null if not found, expired, invalid, or upon network failure.
  Future<Playlist?> resolveShortLink(String shortId);
}

/// In-memory mock resolver for testing, offline verification, and deterministic CI.
class InMemoryMockShortLinkResolver implements ShortLinkResolver {
  final Map<String, Map<String, dynamic>> _storage = {};
  final Map<String, DateTime> _expirations = {};

  void storePlaylist(
    String shortId, {
    required String title,
    String? description,
    String? artworkUrl,
    required List<Track> tracks,
    Duration? ttl,
  }) {
    _storage[shortId] = {
      't': title,
      if (description != null && description.isNotEmpty) 'd': description,
      if (artworkUrl != null && artworkUrl.isNotEmpty) 'art': artworkUrl,
      'tr': tracks.map((track) {
        final cleanArtists = TrackIdentity.sanitizeArtistSummaries(track.artists);
        final artist = cleanArtists.map((a) => a.name).join(', ');
        final parts = tryParseMediaId(track.id);
        final src = parts != null
            ? (parts.pluginId.contains('ytmusic')
                ? 'ytmusic'
                : parts.pluginId.contains('youtube')
                    ? 'youtube'
                    : 'saavn')
            : null;
        final cleanId = parts != null ? parts.localId : track.id;
        final thumb = track.thumbnail.url;
        final albumTitle = (track.album?.title.isNotEmpty == true &&
                track.album!.title != 'Unknown Album' &&
                track.album!.title != 'Single')
            ? track.album!.title
            : '';

        return [
          cleanId,
          track.title,
          artist,
          albumTitle,
          thumb,
          src ?? '',
          track.url ?? '',
        ];
      }).toList(),
    };

    if (ttl != null) {
      _expirations[shortId] = DateTime.now().add(ttl);
    } else {
      _expirations.remove(shortId);
    }
  }

  void expireShortLink(String shortId) {
    _expirations[shortId] = DateTime.now().subtract(const Duration(seconds: 1));
  }

  void corruptShortLink(String shortId) {
    _storage[shortId] = {'corrupted': true};
  }

  void clear() {
    _storage.clear();
    _expirations.clear();
  }

  @override
  Future<String?> createShortLink({
    required String title,
    String? description,
    String? artworkUrl,
    required List<Track> tracks,
  }) async {
    final shortId = OrviaShortLinkService.generateSecureShortId();
    storePlaylist(
      shortId,
      title: title,
      description: description,
      artworkUrl: artworkUrl,
      tracks: tracks,
    );
    return shortId;
  }

  @override
  Future<Playlist?> resolveShortLink(String shortId) async {
    if (!OrviaShortLinkService.isValidShortId(shortId)) return null;

    final expiration = _expirations[shortId];
    if (expiration != null && DateTime.now().isAfter(expiration)) {
      return null;
    }

    final payload = _storage[shortId];
    if (payload == null) return null;
    if (!payload.containsKey('t') || !payload.containsKey('tr')) return null;

    try {
      final title = payload['t'] as String? ?? 'Shared Playlist';
      final desc = payload['d'] as String?;
      final artUrl = payload['art'] as String?;
      final rawTracks = payload['tr'] as List? ?? [];
      final tracks = <Track>[];

      for (final item in rawTracks) {
        if (item is List) {
          final id = item.isNotEmpty ? item[0]?.toString() ?? '' : '';
          final t = item.length > 1 ? item[1]?.toString() ?? 'Unknown Track' : 'Unknown Track';
          final a = item.length > 2 ? item[2]?.toString() ?? '' : '';
          final al = item.length > 3 ? item[3]?.toString() ?? '' : '';
          final th = item.length > 4 ? item[4]?.toString() ?? '' : '';
          final src = item.length > 5 ? item[5]?.toString() : null;
          final u = item.length > 6 ? item[6]?.toString() : null;

          final effectiveThumb = th.isNotEmpty ? th : (artUrl ?? '');
          final artwork = effectiveThumb.isNotEmpty
              ? Artwork(
                  url: effectiveThumb,
                  urlLow: effectiveThumb,
                  urlHigh: effectiveThumb,
                  layout: ImageLayout.square,
                )
              : const Artwork(url: '', layout: ImageLayout.square);

          final pluginId = (src == 'ytmusic' || src == 'youtube')
              ? 'content-resolver.bloomfactory.$src'
              : kDefaultSaavnPluginId;
          final fullId = !id.contains(':') ? '$pluginId::$id' : id;

          tracks.add(Track(
            id: fullId,
            title: t,
            artists: [ArtistSummary(id: '', name: a, thumbnail: artwork)],
            album: AlbumSummary(id: '', title: al, artists: const [], thumbnail: artwork),
            durationMs: BigInt.zero,
            thumbnail: artwork,
            url: u,
            isExplicit: false,
          ));
        }
      }

      final playlistArt = (artUrl != null && artUrl.isNotEmpty)
          ? Artwork(url: artUrl, layout: ImageLayout.square)
          : (tracks.isNotEmpty && tracks.first.thumbnail.url.isNotEmpty)
              ? tracks.first.thumbnail
              : const Artwork(url: '', layout: ImageLayout.square);

      return Playlist(
        title: title,
        description: desc,
        thumbnail: playlistArt,
        tracks: tracks,
        type: PlaylistType.userPlaylist,
      );
    } catch (e) {
      log('Mock resolver parse error: $e', name: 'OrviaShortLinkService');
      return null;
    }
  }
}

/// HTTP REST backend resolver for production short-link resolution.
class HttpShortLinkResolver implements ShortLinkResolver {
  final String apiEndpoint;
  final Duration timeout;
  final http.Client _client;

  HttpShortLinkResolver({
    required this.apiEndpoint,
    this.timeout = const Duration(seconds: 5),
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Future<String?> createShortLink({
    required String title,
    String? description,
    String? artworkUrl,
    required List<Track> tracks,
  }) async {
    try {
      final uri = Uri.parse(apiEndpoint);
      final body = jsonEncode({
        'version': 2,
        'title': title,
        if (description != null) 'description': description,
        if (artworkUrl != null) 'artworkUrl': artworkUrl,
        'tracks': tracks.map((t) {
          final parts = tryParseMediaId(t.id);
          final src = parts != null
              ? (parts.pluginId.contains('ytmusic')
                  ? 'ytmusic'
                  : parts.pluginId.contains('youtube')
                      ? 'youtube'
                      : 'saavn')
              : null;
          return {
            'id': parts != null ? parts.localId : t.id,
            'title': t.title,
            'artist': t.artists.map((a) => a.name).join(', '),
            'album': t.album?.title ?? '',
            'thumb': t.thumbnail.url,
            if (src != null) 'src': src,
            if (t.url != null) 'providerUrl': t.url,
          };
        }).toList(),
      });

      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final id = decoded['id'] ?? decoded['shortId'];
          if (id is String && OrviaShortLinkService.isValidShortId(id)) {
            return id;
          }
        }
      }
      return null;
    } catch (e) {
      log('HttpShortLinkResolver create error: $e', name: 'OrviaShortLinkService');
      return null;
    }
  }

  @override
  Future<Playlist?> resolveShortLink(String shortId) async {
    if (!OrviaShortLinkService.isValidShortId(shortId)) return null;

    try {
      final base = apiEndpoint.endsWith('/')
          ? apiEndpoint.substring(0, apiEndpoint.length - 1)
          : apiEndpoint;
      final uri = Uri.parse('$base/$shortId');

      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode != 200) return null;

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      if ((!decoded.containsKey('title') && !decoded.containsKey('t')) ||
          (!decoded.containsKey('tracks') && !decoded.containsKey('tr'))) {
        return null;
      }

      final title = decoded['title'] as String? ?? decoded['t'] as String? ?? 'Shared Playlist';
      final desc = decoded['description'] as String? ?? decoded['d'] as String?;
      final artUrl = decoded['artworkUrl'] as String? ?? decoded['art'] as String?;
      final rawTracks = decoded['tracks'] as List? ?? decoded['tr'] as List? ?? [];
      final tracks = <Track>[];

      for (final item in rawTracks) {
        if (item is Map) {
          final id = item['id']?.toString() ?? '';
          final t = item['title']?.toString() ?? item['t']?.toString() ?? 'Unknown Track';
          final a = item['artist']?.toString() ?? item['a']?.toString() ?? '';
          final al = item['album']?.toString() ?? item['al']?.toString() ?? '';
          final th = item['thumb']?.toString() ?? item['th']?.toString() ?? '';
          final src = item['src']?.toString();
          final u = item['providerUrl']?.toString() ?? item['u']?.toString();

          final effectiveThumb = th.isNotEmpty ? th : (artUrl ?? '');
          final artwork = effectiveThumb.isNotEmpty
              ? Artwork(
                  url: effectiveThumb,
                  urlLow: effectiveThumb,
                  urlHigh: effectiveThumb,
                  layout: ImageLayout.square,
                )
              : const Artwork(url: '', layout: ImageLayout.square);

          final pluginId = (src == 'ytmusic' || src == 'youtube')
              ? 'content-resolver.bloomfactory.$src'
              : kDefaultSaavnPluginId;
          final fullId = !id.contains(':') ? '$pluginId::$id' : id;

          tracks.add(Track(
            id: fullId,
            title: t,
            artists: [ArtistSummary(id: '', name: a, thumbnail: artwork)],
            album: AlbumSummary(id: '', title: al, artists: const [], thumbnail: artwork),
            durationMs: BigInt.zero,
            thumbnail: artwork,
            url: u,
            isExplicit: false,
          ));
        }
      }

      final artwork = (artUrl != null && artUrl.isNotEmpty)
          ? Artwork(url: artUrl, layout: ImageLayout.square)
          : (tracks.isNotEmpty && tracks.first.thumbnail.url.isNotEmpty)
              ? tracks.first.thumbnail
              : const Artwork(url: '', layout: ImageLayout.square);

      return Playlist(
        title: title,
        description: desc,
        thumbnail: artwork,
        tracks: tracks,
        type: PlaylistType.userPlaylist,
      );
    } catch (e) {
      log('HttpShortLinkResolver resolve error: $e', name: 'OrviaShortLinkService');
      return null;
    }
  }
}

/// Default offline / self-contained resolver that returns null for short IDs,
/// cleanly signaling the application to generate and use self-contained long URLs.
class DefaultSelfContainedResolver implements ShortLinkResolver {
  const DefaultSelfContainedResolver();

  @override
  Future<String?> createShortLink({
    required String title,
    String? description,
    String? artworkUrl,
    required List<Track> tracks,
  }) async =>
      null;

  @override
  Future<Playlist?> resolveShortLink(String shortId) async => null;
}

/// Central manager for generating, validating, and resolving short links.
class OrviaShortLinkService {
  OrviaShortLinkService._();

  static const String webDomain = 'ankitcodes30.github.io';
  static const String webBasePath = '/Orvia';
  static const String appScheme = 'orvia';

  static const String _base62Chars =
      '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static final RegExp _validShortIdRegex = RegExp(r'^[a-zA-Z0-9_-]{4,32}$');

  /// The currently active short link resolver.
  static ShortLinkResolver activeResolver = const DefaultSelfContainedResolver();

  /// Resets the active resolver to the default self-contained resolver.
  @visibleForTesting
  static void resetForTesting() {
    activeResolver = const DefaultSelfContainedResolver();
  }

  /// Generates a cryptographically secure, collision-resistant Base62 ID.
  /// 8 characters in Base62 yield 62^8 ≈ 2.18 × 10^14 combinations.
  static String generateSecureShortId({int length = 8}) {
    final rng = Random.secure();
    final buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      buffer.write(_base62Chars[rng.nextInt(_base62Chars.length)]);
    }
    return buffer.toString();
  }

  /// Validates whether a given string is a syntactically valid short ID.
  static bool isValidShortId(String? id) {
    if (id == null) return false;
    final trimmed = id.trim();
    if (trimmed.isEmpty) return false;
    // Reject reserved route names
    const reserved = {'playlist', 'track', 'p', 'search', 'settings', 'admin', 'api'};
    if (reserved.contains(trimmed.toLowerCase())) return false;
    return _validShortIdRegex.hasMatch(trimmed);
  }

  /// Builds a user-facing short link URI for a given short ID.
  static Uri buildShortPlaylistUri(
    String shortId, {
    bool useAppScheme = false,
    bool useQueryFormat = false,
  }) {
    assert(isValidShortId(shortId), 'Invalid short ID: $shortId');

    if (useAppScheme) {
      if (useQueryFormat) {
        return Uri(
          scheme: appScheme,
          host: 'p',
          queryParameters: {'id': shortId},
        );
      } else {
        return Uri(
          scheme: appScheme,
          host: 'p',
          path: '/$shortId',
        );
      }
    } else {
      if (useQueryFormat) {
        return Uri(
          scheme: 'https',
          host: webDomain,
          path: '$webBasePath/p',
          queryParameters: {'id': shortId},
        );
      } else {
        return Uri(
          scheme: 'https',
          host: webDomain,
          path: '$webBasePath/p/$shortId',
        );
      }
    }
  }

  /// Attempts to create a short link using the active resolver.
  static Future<String?> createShortLink({
    required String title,
    String? description,
    String? artworkUrl,
    required List<Track> tracks,
  }) async {
    return await activeResolver.createShortLink(
      title: title,
      description: description,
      artworkUrl: artworkUrl,
      tracks: tracks,
    );
  }

  /// Resolves a short ID to a hydrated [Playlist] domain model.
  /// Returns null if the ID is missing, malformed, expired, unknown, or if network fails.
  static Future<Playlist?> resolveShortLink(String shortId) async {
    if (!isValidShortId(shortId)) return null;
    try {
      final playlist = await activeResolver.resolveShortLink(shortId.trim());
      if (playlist == null) return null;
      // Safety check: ensure title is non-empty
      if (playlist.title.trim().isEmpty) return null;
      return playlist;
    } catch (e) {
      log('Error resolving short ID "$shortId": $e', name: 'OrviaShortLinkService');
      return null;
    }
  }

  /// High-level share URL builder:
  /// Attempts to generate a short link. If successful, returns the short link URI.
  /// If unconfigured, offline, or failed, safely falls back to the self-contained long link URI.
  static Future<Uri> buildShareablePlaylistUri({
    required String name,
    String? description,
    String? artworkUrl,
    required List<Track> tracks,
    bool useAppScheme = false,
  }) async {
    try {
      final shortId = await createShortLink(
        title: name,
        description: description,
        artworkUrl: artworkUrl,
        tracks: tracks,
      );

      if (shortId != null && isValidShortId(shortId)) {
        return buildShortPlaylistUri(shortId, useAppScheme: useAppScheme);
      }
    } catch (e) {
      log('Short link creation failed, falling back to long link: $e',
          name: 'OrviaShortLinkService');
    }

    return OrviaDeepLinkService.buildPlaylistDeepLink(
      name: name,
      description: description,
      artworkUrl: artworkUrl,
      tracks: tracks,
      useAppScheme: useAppScheme,
    );
  }

  /// Resolves any incoming URI (short link or legacy long link) into a [Playlist].
  static Future<Playlist?> resolvePlaylistFromUri(Uri uri) async {
    final parsed = OrviaDeepLinkService.parseDeepLink(uri);
    if (parsed == null || parsed['type'] != 'playlist') return null;

    if (parsed['isShortLink'] == true) {
      final shortId = parsed['shortId'] as String?;
      if (shortId == null) return null;
      return await resolveShortLink(shortId);
    }

    return OrviaDeepLinkService.parsePlaylistFromUri(uri);
  }
}
