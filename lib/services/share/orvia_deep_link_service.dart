import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/core/utils/track_identity.dart';
import 'package:Orvia/plugins/utils/media_id.dart';
import 'package:Orvia/routes/app_router.dart';
import 'package:Orvia/screens/screen/library_views/shared_playlist_screen.dart';
import 'package:Orvia/screens/widgets/snackbar.dart';
import 'package:Orvia/services/audio_service_initializer.dart';
import 'package:Orvia/services/catalogue/creators_choice_service.dart';
import 'package:Orvia/services/song_metadata_refresh_service.dart';
import 'orvia_short_link_service.dart';

/// Central service for generating, routing, and sharing Orvia deep links.
/// Supports custom scheme `orvia://` and GitHub Pages web links while cleanly
/// abstracting internal plugin resolver IDs.
class OrviaDeepLinkService {
  OrviaDeepLinkService._();

  /// Host and project path for the currently deployed GitHub Pages website.
  static const String webDomain = 'ankitcodes30.github.io';
  static const String webBasePath = '/Orvia';

  /// Supported hosts for incoming links, including hosts used by older shares.
  static const Set<String> supportedWebDomains = {
    webDomain,
    'orvia.app',
    'www.orvia.app',
    'ankitkr324.github.io',
    'hemantkarya.github.io',
    'localhost',
  };

  /// Scheme for native intent handling.
  static const String appScheme = 'orvia';

  static String _mapSourceKeyToPluginId(String? src) {
    if (src == null || src.isEmpty) return kDefaultSaavnPluginId;
    final lower = src.toLowerCase().trim();
    return switch (lower) {
      'saavn' || 'jiosaavn' => kDefaultSaavnPluginId,
      'ytmusic' => 'content-resolver.bloomfactory.ytmusic',
      'youtube' || 'ytvideo' => 'content-resolver.bloomfactory.ytvideo',
      'local' => kLocalPluginId,
      _ => kDefaultSaavnPluginId,
    };
  }

  static String? _mapPluginIdToSourceKey(String pluginId) {
    if (pluginId.contains('saavn') || pluginId.contains('jisaavn')) return 'saavn';
    if (pluginId.contains('ytmusic')) return 'ytmusic';
    if (pluginId.contains('ytvideo') || pluginId.contains('youtube')) return 'youtube';
    if (pluginId == kLocalPluginId) return 'local';
    return null;
  }

  static bool _isChannelAvatar(String url) {
    final normalized = url.toLowerCase();
    return normalized.contains('yt3.ggpht.com') ||
        normalized.contains('yt3.googleusercontent.com');
  }

  /// Generates a clean deep link URI for a given [Track].
  ///
  /// Removes internal `content-resolver.bloomfactory.` namespace prefixes from public URLs
  /// to preserve clean branding while retaining unambiguous provider reconstruction.
  static Uri? _pendingDeepLinkUri;
  static bool get hasPendingDeepLink => _pendingDeepLinkUri != null;
  static Uri? get pendingDeepLink => _pendingDeepLinkUri;

  static bool _isHandlingDeepLink = false;
  static bool get isHandlingDeepLink => _isHandlingDeepLink;

  static bool _isSharing = false;
  static bool get isSharing => _isSharing;

  @visibleForTesting
  static set isSharingForTesting(bool val) => _isSharing = val;

  static bool _hasHandledColdStartDeepLink = false;
  static bool get hasHandledColdStartDeepLink => _hasHandledColdStartDeepLink;

  static int activeRequestId = 0;
  static int nextRequestId() => ++activeRequestId;

  static String? _lastHandledTrackId;
  static String? _lastHandledPlaylistHash;
  static DateTime? _lastHandledTime;

  static const MethodChannel _androidChannel =
      MethodChannel('ls.orvia.musicplayer/deep_link');
  static bool _androidListenerInitialized = false;

  /// Queries the Android native activity for any launch intent URL that opened the app.
  /// MUST be called at the very start of main() before player initialization.
  static Future<Uri?> getInitialAndroidIntentUri() async {
    if (!io.Platform.isAndroid) return null;
    try {
      final url =
          await _androidChannel.invokeMethod<String>('getInitialIntentUrl');
      if (url != null && url.trim().isNotEmpty) {
        final uri = Uri.tryParse(url.trim());
        if (uri != null && isDeepLink(uri)) {
          return uri;
        }
      }
    } catch (e) {
      log('getInitialAndroidIntentUri error: $e', name: 'OrviaDeepLinkService');
    }
    return null;
  }

  /// Sets up a native callback listener for warm-start / background deep links (`onNewIntent`).
  static void initAndroidDeepLinkListener() {
    if (!io.Platform.isAndroid || _androidListenerInitialized) return;
    _androidListenerInitialized = true;
    _androidChannel.setMethodCallHandler((call) async {
      if (call.method == 'onNewIntentUrl') {
        final raw = call.arguments as String?;
        if (raw != null && raw.trim().isNotEmpty) {
          String candidate = raw.trim();
          final match = RegExp(r'(https?://[^\s]+|orvia://[^\s]+)').firstMatch(candidate);
          if (match != null) {
            candidate = match.group(0)!;
          }
          final uri = Uri.tryParse(candidate);
          if (uri != null && isDeepLink(uri)) {
            setPendingDeepLink(uri);
            await handleDeepLinkUri(uri);
          }
        }
      }
    });
  }

  /// Registers a pending deep link to prioritize it over previous session restoration.
  static void setPendingDeepLink(Uri uri) {
    _pendingDeepLinkUri = uri;
    _hasHandledColdStartDeepLink = true;
  }

  /// Clears any pending deep link.
  static void clearPendingDeepLink() {
    _pendingDeepLinkUri = null;
  }

  /// Resets all deep-link tracking state (primarily for automated testing).
  @visibleForTesting
  static void resetForTesting() {
    _pendingDeepLinkUri = null;
    _isHandlingDeepLink = false;
    _isSharing = false;
    _hasHandledColdStartDeepLink = false;
    activeRequestId = 0;
    _lastHandledTrackId = null;
    _lastHandledTime = null;
  }

  /// Generates a clean deep link URI for a given [Track].
  ///
  /// Removes internal `content-resolver.bloomfactory.` namespace prefixes from public URLs
  /// to preserve clean branding while retaining unambiguous provider reconstruction.
  static Uri buildTrackDeepLink(
    Track track, {
    bool useAppScheme = false,
    bool short = false,
  }) {
    final cleanArtists = TrackIdentity.sanitizeArtistSummaries(track.artists);
    final artistNames = cleanArtists.map((a) => a.name).join(', ');
    final parts = tryParseMediaId(track.id);

    // Clean user-facing ID: do not expose internal bloomfactory IDs in URLs
    final cleanId = parts != null ? parts.localId : track.id;
    final sourceKey = parts != null
        ? _mapPluginIdToSourceKey(parts.pluginId)
        : (cleanId.length == 11 && !cleanId.contains(':') ? 'youtube' : 'saavn');
    final isYtTrack = sourceKey == 'youtube' ||
        sourceKey == 'ytmusic' ||
        (cleanId.length == 11 && !cleanId.contains(':'));
    final artworkCandidates = [
      track.thumbnail.urlHigh,
      track.thumbnail.url,
      track.thumbnail.urlLow,
    ];
    final trackArtwork = artworkCandidates
        .whereType<String>()
        .map((url) => url.trim())
        .firstWhere(
          (url) => url.isNotEmpty && !_isChannelAvatar(url),
          orElse: () => '',
        );
    final thumbUrl = trackArtwork.isNotEmpty
        ? trackArtwork
        : isYtTrack
            ? 'https://i.ytimg.com/vi/$cleanId/hqdefault.jpg'
            : '';

    // Preserve original provider URL if present; if empty and it's a YouTube track, use YouTube URL.
    // Never export local file URLs to web share links.
    final rawUrl = track.url?.trim() ?? '';
    final effectiveProviderUrl = rawUrl.isNotEmpty
        ? (rawUrl.startsWith('file:') ? '' : rawUrl)
        : (isYtTrack ? 'https://www.youtube.com/watch?v=$cleanId' : '');

    final queryParams = <String, String>{
      'id': cleanId,
      if (sourceKey != null) 'src': sourceKey,
      if (!short && track.title.isNotEmpty) 'title': track.title,
      if (!short && artistNames.isNotEmpty) 'artist': artistNames,
      if (!short &&
          track.album?.title.isNotEmpty == true &&
          track.album!.title != 'Unknown Album' &&
          track.album!.title != 'Single')
        'album': track.album!.title,
      if (!short && thumbUrl.isNotEmpty) 'thumb': thumbUrl,
      if (!short && effectiveProviderUrl.isNotEmpty)
        'providerUrl': effectiveProviderUrl,
    };

    if (useAppScheme) {
      return Uri(
        scheme: appScheme,
        host: 'track',
        queryParameters: queryParams,
      );
    } else {
      return Uri(
        scheme: 'https',
        host: webDomain,
        path: '$webBasePath/track',
        queryParameters: queryParams,
      );
    }
  }

  /// Builds a clean, minimal short share link:
  /// e.g. https://ankitcodes30.github.io/Orvia/track?id=dxrBpjVX&src=saavn
  static Uri buildShortTrackUri(Track track, {bool useAppScheme = false}) =>
      buildTrackDeepLink(track, useAppScheme: useAppScheme, short: true);

  /// Maximum number of tracks permitted in a single direct-share link.
  /// Playlists larger than this must be shared via file export to ensure
  /// URLs remain reliable across messaging apps, SMS, and proxies.
  static const int kMaxShareablePlaylistTracks = 100;

  /// Absolute maximum character length for a shareable URL before it is rejected
  /// with a prompt recommending file export. Most messengers truncate or drop
  /// URLs exceeding 6,000 characters.
  static const int kMaxShareableUrlLength = 6144;

  static String _compressThumbnail(String url, String? artUrl) {
    if (url.isEmpty) return '';
    if (artUrl != null && url == artUrl) return '=';
    var s = url;
    if (s.startsWith('https://c.saavncdn.com/')) {
      s = '~${s.substring(23)}';
    } else if (s.startsWith('https://i.ytimg.com/vi/')) {
      s = '^${s.substring(23)}';
    }
    if (s.endsWith('-500x500.webp')) {
      s = '${s.substring(0, s.length - 13)}@';
    } else if (s.endsWith('-500x500.jpg')) {
      s = '${s.substring(0, s.length - 12)}\$';
    }
    return s;
  }

  static String _decompressThumbnail(String? raw, String? artUrl, {String? localId, String? src}) {
    if (raw == null || raw.isEmpty) {
      if (localId != null && (localId.length == 11 || src == 'youtube' || src == 'ytmusic')) {
        return 'https://i.ytimg.com/vi/$localId/hqdefault.jpg';
      }
      return artUrl ?? '';
    }
    if (raw == '=') return artUrl ?? '';
    var s = raw;
    if (s.startsWith('~')) {
      s = 'https://c.saavncdn.com/${s.substring(1)}';
    } else if (s.startsWith('^')) {
      s = 'https://i.ytimg.com/vi/${s.substring(1)}';
    }
    if (s.endsWith('@')) {
      s = '${s.substring(0, s.length - 1)}-500x500.webp';
    } else if (s.endsWith('\$')) {
      s = '${s.substring(0, s.length - 1)}-500x500.jpg';
    }
    return s;
  }

  /// Encodes playlist metadata and tracks into a URL-safe compressed base64 string.
  /// Uses compact version 2 tuple format to minimize share URL length.
  static String encodePlaylistData({
    required String title,
    String? description,
    String? artworkUrl,
    required List<Track> tracks,
  }) {
    final cappedTracks = tracks.length > kMaxShareablePlaylistTracks
        ? tracks.take(kMaxShareablePlaylistTracks).toList()
        : tracks;

    final effectiveArt = artworkUrl ?? tracks.firstOrNull?.thumbnail.url;

    final payload = {
      'v': 2,
      't': title,
      if (description != null && description.isNotEmpty) 'd': description,
      if (effectiveArt != null && effectiveArt.isNotEmpty) 'art': effectiveArt,
      'tr': cappedTracks.map((track) {
        final cleanArtists = TrackIdentity.sanitizeArtistSummaries(track.artists);
        final artist = cleanArtists.map((a) => a.name).join(', ');
        final parts = tryParseMediaId(track.id);
        final src = parts != null ? _mapPluginIdToSourceKey(parts.pluginId) : null;
        final cleanId = parts != null ? parts.localId : track.id;
        final thumb = track.thumbnail.url;
        final albumTitle = (track.album?.title.isNotEmpty == true &&
                track.album!.title != 'Unknown Album' &&
                track.album!.title != 'Single')
            ? track.album!.title
            : '';
        final compactThumb = _compressThumbnail(thumb, effectiveArt);
        final cleanSrc = (src != null && src != 'saavn') ? src : '';
        final customUrl = (track.url != null &&
                track.url!.isNotEmpty &&
                !track.url!.startsWith('file:'))
            ? track.url!
            : '';

        // Tuple format: [cleanId, title, artist, album, thumb, src, url]
        final tuple = <dynamic>[
          cleanId,
          track.title,
          artist,
          albumTitle,
          compactThumb,
          cleanSrc,
          customUrl,
        ];

        while (tuple.length > 2 && tuple.last == '') {
          tuple.removeLast();
        }
        return tuple;
      }).toList(),
    };

    final jsonStr = jsonEncode(payload);
    final compressed = io.GZipCodec(level: 9).encode(utf8.encode(jsonStr));
    return base64UrlEncode(compressed).replaceAll('=', '');
  }

  /// Decodes and decompresses a base64url payload into a playlist map.
  /// Supports truncated payloads via chunked gzip streaming recovery.
  static Map<String, dynamic>? decodePlaylistData(String b64) {
    if (b64.isEmpty || b64.length > 65536) return null;
    try {
      var clean = b64.trim().replaceAll(RegExp(r'[\s\r\n]+'), '');
      if (clean.startsWith('<') && clean.endsWith('>')) {
        clean = clean.substring(1, clean.length - 1);
      }
      // If cut off mid-character by a URL length limit or messenger, drop orphan character
      if (clean.length % 4 == 1) {
        clean = clean.substring(0, clean.length - 1);
      }
      var normalized = clean.replaceAll('-', '+').replaceAll('_', '/');
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      final bytes = base64Decode(normalized);

      // Check for gzip magic bytes 0x1f, 0x8b
      if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
        // 1. Try standard complete gunzip
        try {
          final decompressed = io.gzip.decode(bytes);
          final jsonStr = utf8.decode(decompressed);
          final dynamic decoded = jsonDecode(jsonStr);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        } catch (e) {
          log('Standard gzip decode failed, attempting chunked recovery: $e',
              name: 'OrviaDeepLinkService');
        }

        // 2. Chunked streaming recovery for truncated payloads
        try {
          final chunks = <List<int>>[];
          final outSink = ChunkedConversionSink<List<int>>.withCallback((c) {
            chunks.addAll(c);
          });
          final inSink = io.gzip.decoder.startChunkedConversion(outSink);
          const chunkSize = 256;
          for (int i = 0; i < bytes.length; i += chunkSize) {
            final end =
                (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
            inSink.add(bytes.sublist(i, end));
          }
          try {
            inSink.close();
          } catch (_) {}

          final totalBytes = chunks.expand((c) => c).toList();
          if (totalBytes.isNotEmpty) {
            final text = utf8.decode(totalBytes, allowMalformed: true);
            final lastObj = text.lastIndexOf('},');
            final lastArr = text.lastIndexOf('],');
            final lastValidIndex = lastObj > lastArr ? lastObj : lastArr;
            if (lastValidIndex != -1) {
              final recoveredJsonStr =
                  '${text.substring(0, lastValidIndex + 1)}]}';
              final dynamic decoded = jsonDecode(recoveredJsonStr);
              if (decoded is Map<String, dynamic> &&
                  (decoded.containsKey('tr') || decoded.containsKey('tracks'))) {
                decoded['_partiallyRecovered'] = true;
                return decoded;
              }
            }
          }
        } catch (e) {
          log('Chunked gzip recovery failed: $e',
              name: 'OrviaDeepLinkService');
        }
      } else {
        // Plain UTF-8 JSON fallback
        try {
          final jsonStr = utf8.decode(bytes);
          final dynamic decoded = jsonDecode(jsonStr);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        } catch (_) {}
      }

      return null;
    } catch (e) {
      log('Failed to decode playlist data: $e', name: 'OrviaDeepLinkService');
      return null;
    }
  }

  /// Generates a deep link URI for a user or curated playlist.
  static Uri buildPlaylistDeepLink({
    required String name,
    String? id,
    List<Track>? tracks,
    String? artworkUrl,
    String? description,
    bool useAppScheme = false,
  }) {
    final queryParams = <String, String>{
      'name': name,
      if (id != null && id.isNotEmpty) 'id': id,
    };

    if (tracks != null && tracks.isNotEmpty) {
      try {
        final payload = encodePlaylistData(
          title: name,
          description: description,
          artworkUrl: artworkUrl,
          tracks: tracks,
        );
        queryParams['data'] = payload;
      } catch (e) {
        log('Failed to encode playlist data: $e', name: 'OrviaDeepLinkService');
      }
    }

    if (useAppScheme) {
      return Uri(
        scheme: appScheme,
        host: 'playlist',
        queryParameters: queryParams,
      );
    } else {
      return Uri(
        scheme: 'https',
        host: webDomain,
        path: '$webBasePath/playlist',
        queryParameters: queryParams,
      );
    }
  }

  /// Builds the share text for a given track, containing clean web and app deep links.
  static String buildTrackShareText(Track track) {
    final cleanArtists = TrackIdentity.sanitizeArtistSummaries(track.artists);
    final artists = cleanArtists.map((a) => a.name).join(', ');
    final byArtist = artists.isNotEmpty ? ' by $artists' : '';

    final webLink = buildTrackDeepLink(track, useAppScheme: false, short: false).toString();

    final buffer = StringBuffer();
    buffer.writeln('🎵 Listen to "${track.title}"$byArtist on Orvia:');
    buffer.write(webLink);
    return buffer.toString();
  }

  /// Shares a track via the system share sheet, including the deep links
  /// and original provider URL. If the system share fails, falls back to copying the link.
  static Future<void> shareTrack(BuildContext context, Track track) async {
    Rect? origin;
    try {
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize && renderBox.attached) {
        final size = renderBox.size;
        final position = renderBox.localToGlobal(Offset.zero);
        origin = position & size;
      }
    } catch (_) {}

    final text = buildTrackShareText(track);

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: 'Listen to "${track.title}" on Orvia',
          title: 'Share "${track.title}"',
          sharePositionOrigin: origin,
        ),
      );
    } catch (e, stack) {
      log('Unable to open system share: $e\n$stack', name: 'OrviaDeepLinkService');
      await Clipboard.setData(ClipboardData(text: text));
      SnackbarService.showMessage('Unable to open system share ($e). Link copied to clipboard.');
    }
  }

  /// Shares a playlist link via the system share sheet with URL and text preview.
  /// If the system share fails, falls back to copying the link.
  static Future<void> sharePlaylist(
    BuildContext context, {
    required String name,
    String? id,
    List<Track>? tracks,
    String? artworkUrl,
    String? description,
  }) async {
    if (CreatorsChoiceService.isCreatorsChoice(name)) {
      log('Cannot share protected playlist "$name"', name: 'OrviaDeepLinkService');
      return;
    }
    if (_isSharing) {
      SnackbarService.showMessage('A share operation is already in progress...');
      return;
    }
    _isSharing = true;

    Rect? origin;
    try {
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize && renderBox.attached) {
        final size = renderBox.size;
        final position = renderBox.localToGlobal(Offset.zero);
        origin = position & size;
      }
    } catch (_) {}

    try {
      final count = tracks?.length ?? 0;
      if (count > kMaxShareablePlaylistTracks) {
        SnackbarService.showMessage(
          'Direct link sharing supports up to $kMaxShareablePlaylistTracks songs to ensure links work reliably across messaging apps. Please use "Export as File (.json)" for larger playlists.',
        );
        return;
      }

      final webLinkUri = await OrviaShortLinkService.buildShareablePlaylistUri(
        name: name,
        description: description,
        artworkUrl: artworkUrl,
        tracks: tracks ?? const [],
        useAppScheme: false,
      );
      final webLink = webLinkUri.toString();

      if (webLink.length > kMaxShareableUrlLength) {
        SnackbarService.showMessage(
          'This playlist payload exceeds the maximum shareable link size (${webLink.length} characters). Please use "Export as File (.json)" instead.',
        );
        return;
      }

      final countStr = count > 0 ? ' ($count song${count == 1 ? '' : 's'})' : '';
      final buffer = StringBuffer();
      buffer.writeln('🎶 Check out playlist "$name"$countStr on Orvia:');
      buffer.write(webLink);
      final text = buffer.toString();

      try {
        await SharePlus.instance.share(
          ShareParams(
            text: text,
            subject: 'Playlist "$name" on Orvia',
            title: 'Share Playlist "$name"',
            sharePositionOrigin: origin,
          ),
        );
      } catch (e, stack) {
        log('Unable to open system share: $e\n$stack', name: 'OrviaDeepLinkService');
        await Clipboard.setData(ClipboardData(text: text));
        SnackbarService.showMessage('Unable to open system share ($e). Playlist link copied to clipboard.');
      }
    } catch (e, stack) {
      log('Failed to share playlist: $e\n$stack', name: 'OrviaDeepLinkService');
      SnackbarService.showMessage('Unable to share playlist link: $e');
    } finally {
      _isSharing = false;
    }
  }

  /// Checks whether a URI corresponds to an Orvia deep link.
  static bool isDeepLink(Uri uri) {
    if (uri.scheme == appScheme) return true;
    final hasSupportedHost = (uri.scheme == 'http' || uri.scheme == 'https') &&
        (supportedWebDomains.contains(uri.host.toLowerCase()) || uri.host.isEmpty);
    final isRelative = uri.scheme.isEmpty && (uri.path.startsWith('/') || uri.host.isEmpty);

    if (hasSupportedHost || isRelative) {
      final segments = uri.pathSegments;
      if (segments.isNotEmpty &&
          (segments.first == 'track' ||
              segments.first == 'playlist' ||
              segments.first == 'p' ||
              segments.contains('track') ||
              segments.contains('playlist') ||
              segments.contains('p'))) {
        return true;
      }
      if (uri.queryParameters.containsKey('id') ||
          uri.queryParameters.containsKey('v') ||
          uri.queryParameters.containsKey('data')) {
        return true;
      }
    }
    return false;
  }

  /// Parses an incoming deep link URI to extract track or playlist parameters.
  static Map<String, dynamic>? parseDeepLink(Uri uri) {
    if (!isDeepLink(uri)) {
      return null;
    }

    final isScheme = uri.scheme == appScheme;
    final params = uri.queryParameters;
    final type = isScheme
        ? uri.host
        : uri.pathSegments.isNotEmpty
            ? uri.pathSegments.firstWhere(
                (s) => s == 'track' || s == 'playlist' || s == 'p',
                orElse: () => uri.pathSegments.first,
              )
            : '';

    // Handle short playlist link: /p/<id> or orvia://p/<id> or /p?id=<id>
    final isShortPlaylist = type == 'p' ||
        uri.pathSegments.contains('p') ||
        (isScheme && uri.host == 'p');

    if (isShortPlaylist) {
      String? shortId;
      if (params.containsKey('id') && params['id']!.isNotEmpty) {
        shortId = params['id'];
      } else if (isScheme && uri.pathSegments.isNotEmpty) {
        shortId = uri.pathSegments.first;
      } else {
        final pIndex = uri.pathSegments.indexOf('p');
        if (pIndex != -1 && pIndex + 1 < uri.pathSegments.length) {
          shortId = uri.pathSegments[pIndex + 1];
        }
      }

      return {
        'type': 'playlist',
        'isShortLink': true,
        'shortId': shortId,
        'name': params['name'] ?? params['title'] ?? 'Shared Playlist',
        'id': params['id'],
        'data': params['data'],
      };
    }

    // Handle playlist FIRST if host, path, or query indicates playlist
    final isPlaylist = type == 'playlist' || params.containsKey('data');

    if (isPlaylist) {
      return {
        'type': 'playlist',
        'isShortLink': false,
        'name': params['name'] ?? params['title'] ?? 'Playlist',
        'id': params['id'],
        'data': params['data'],
      };
    }

    final isTrack = type == 'track' ||
        params.containsKey('id') ||
        params.containsKey('v');

    if (isTrack) {
      final rawId = params['id'];
      if (rawId == null || rawId.trim().isEmpty) return null;

      final src = params['src'];
      // Reconstruct composite ID safely if not already stamped
      final stampedId = isStampedId(rawId)
          ? rawId
          : buildMediaId(_mapSourceKeyToPluginId(src), rawId.trim());

      return {
        'type': 'track',
        'id': stampedId,
        'title': params['title'] ?? 'Unknown Track',
        'artist': params['artist'] ?? '',
        'album': params['album'] ?? '',
        'thumb': params['thumb'] ?? '',
        'providerUrl': params['providerUrl'],
        'src': src,
      };
    }

    return null;
  }

  /// Parses a valid [Track] from an incoming deep link URI.
  static Track? parseTrackFromUri(Uri uri) {
    final parsed = parseDeepLink(uri);
    if (parsed == null || parsed['type'] != 'track') return null;

    final id = parsed['id'] as String;
    final title = parsed['title'] as String;
    final artist = parsed['artist'] as String;
    final album = parsed['album'] as String;
    final thumb = parsed['thumb'] as String;
    final providerUrl = parsed['providerUrl'] as String?;
    final src = parsed['src'] as String?;

    final parts = tryParseMediaId(id);
    final localId = parts != null ? parts.localId : id;
    final isYt = src == 'ytmusic' ||
        src == 'youtube' ||
        (localId.length == 11 && !localId.contains(':'));
    final effectiveThumb = thumb.isNotEmpty
        ? thumb
        : isYt
            ? 'https://i.ytimg.com/vi/$localId/hqdefault.jpg'
            : '';

    final artwork = effectiveThumb.isNotEmpty
        ? Artwork(
            url: effectiveThumb,
            urlLow: effectiveThumb,
            urlHigh: effectiveThumb,
            layout: ImageLayout.square,
          )
        : const Artwork(url: '', layout: ImageLayout.square);

    final pluginId = _mapSourceKeyToPluginId(src);
    final fullId = !id.contains('::') ? '$pluginId::$id' : id;

    return Track(
      id: fullId,
      title: title,
      artists: [ArtistSummary(id: '', name: artist, thumbnail: artwork)],
      album: AlbumSummary(id: '', title: album, artists: const [], thumbnail: artwork),
      durationMs: BigInt.zero,
      thumbnail: artwork,
      url: providerUrl,
      isExplicit: false,
    );
  }

  /// Parses a [Playlist] domain model from an incoming deep link URI.
  static Playlist? parsePlaylistFromUri(Uri uri) {
    final parsed = parseDeepLink(uri);
    if (parsed == null || parsed['type'] != 'playlist') return null;

    final name = parsed['name'] as String? ?? 'Shared Playlist';
    final data = parsed['data'] as String?;

    if (data != null && data.isNotEmpty) {
      final decoded = decodePlaylistData(data);
      if (decoded != null) {
        final title = (decoded['t'] as String?) ?? name;
        final desc = decoded['d'] as String?;
        final artUrl = decoded['art'] as String?;
        final rawTracks = (decoded['tr'] as List?) ?? [];
        final tracks = <Track>[];

        for (final item in rawTracks) {
          if (item is List) {
            // v2 tuple: [cleanId, title, artist, album, thumb, src, url]
            final id = item.isNotEmpty ? item[0]?.toString() ?? '' : '';
            final t = item.length > 1 ? item[1]?.toString() ?? 'Unknown Track' : 'Unknown Track';
            final a = item.length > 2 ? item[2]?.toString() ?? '' : '';
            final al = item.length > 3 ? item[3]?.toString() ?? '' : '';
            final rawTh = item.length > 4 ? item[4]?.toString() ?? '' : '';
            final src = item.length > 5 ? item[5]?.toString() : null;
            final u = item.length > 6 ? item[6]?.toString() : null;

            final parts = tryParseMediaId(id);
            final localId = parts != null ? parts.localId : id;
            final effectiveThumb = _decompressThumbnail(rawTh, artUrl, localId: localId, src: src);

            final artwork = effectiveThumb.isNotEmpty
                ? Artwork(
                    url: effectiveThumb,
                    urlLow: effectiveThumb,
                    urlHigh: effectiveThumb,
                    layout: ImageLayout.square,
                  )
                : const Artwork(url: '', layout: ImageLayout.square);

            final pluginId = _mapSourceKeyToPluginId(src);
            final fullId = !id.contains(':') ? '$pluginId::$id' : id;

            tracks.add(Track(
              id: fullId,
              title: t,
              artists: [ArtistSummary(id: '', name: a, thumbnail: artwork)],
              album: AlbumSummary(
                  id: '', title: al, artists: const [], thumbnail: artwork),
              durationMs: BigInt.zero,
              thumbnail: artwork,
              url: u,
              isExplicit: false,
            ));
          } else if (item is Map) {
            final id = item['id'] as String? ?? '';
            final t = item['t'] as String? ?? 'Unknown Track';
            final a = item['a'] as String? ?? '';
            final al = item['al'] as String? ?? '';
            final th = item['th'] as String? ?? '';
            final src = item['src'] as String?;
            final u = item['u'] as String?;

            final parts = tryParseMediaId(id);
            final localId = parts != null ? parts.localId : id;
            final isYt = src == 'ytmusic' ||
                src == 'youtube' ||
                (localId.length == 11 && !localId.contains(':'));
            final effectiveThumb = th.isNotEmpty
                ? th
                : isYt
                    ? 'https://i.ytimg.com/vi/$localId/hqdefault.jpg'
                    : (artUrl ?? '');

            final artwork = effectiveThumb.isNotEmpty
                ? Artwork(
                    url: effectiveThumb,
                    urlLow: effectiveThumb,
                    urlHigh: effectiveThumb,
                    layout: ImageLayout.square,
                  )
                : const Artwork(url: '', layout: ImageLayout.square);

            final pluginId = _mapSourceKeyToPluginId(src);
            final fullId = !id.contains(':') ? '$pluginId::$id' : id;

            tracks.add(Track(
              id: fullId,
              title: t,
              artists: [ArtistSummary(id: '', name: a, thumbnail: artwork)],
              album: AlbumSummary(
                  id: '', title: al, artists: const [], thumbnail: artwork),
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

        final isPartial = decoded['_partiallyRecovered'] == true;
        var effectiveDesc = desc;
        if (isPartial) {
          effectiveDesc = (desc != null && desc.isNotEmpty)
              ? '$desc (Partially recovered)'
              : 'Partially recovered from link';
        }

        return Playlist(
          title: title,
          description: effectiveDesc,
          thumbnail: artwork,
          tracks: tracks,
          type: PlaylistType.userPlaylist,
        );
      }
    }

    return Playlist(
      title: name,
      tracks: const [],
      type: PlaylistType.userPlaylist,
    );
  }

  /// Handles opening a shared playlist deep link inside Orvia.
  static Future<bool> handlePlaylistDeepLinkUri(Uri uri) async {
    try {
      final parsed = parseDeepLink(uri);
      Playlist? playlist;

      if (parsed != null && parsed['isShortLink'] == true) {
        final shortId = parsed['shortId'] as String?;
        if (shortId == null || !OrviaShortLinkService.isValidShortId(shortId)) {
          log('Invalid or missing shortId in short link: $uri',
              name: 'OrviaDeepLinkService');
          SnackbarService.showMessage(
              'Unable to load shared playlist: invalid or malformed short link');
          return false;
        }

        playlist = await OrviaShortLinkService.resolveShortLink(shortId);
        if (playlist == null) {
          log('Short link resolution returned null for ID "$shortId": $uri',
              name: 'OrviaDeepLinkService');
          SnackbarService.showMessage(
              'Unable to load shared playlist: link may be expired or not found');
          return false;
        }
      } else {
        playlist = parsePlaylistFromUri(uri);
        if (playlist == null) {
          log('Failed to parse playlist from deep link: $uri',
              name: 'OrviaDeepLinkService');
          return false;
        }

        if (playlist.tracks.isEmpty && uri.queryParameters.containsKey('data')) {
          log('Playlist deep link has data parameter but 0 tracks could be decoded: $uri',
              name: 'OrviaDeepLinkService');
          SnackbarService.showMessage(
              'Unable to load shared playlist: corrupted or incomplete link');
          return false;
        }
      }

      final targetPlaylist = playlist;
      final now = DateTime.now();
      final hash =
          '${targetPlaylist.title}_${targetPlaylist.tracks.length}_${uri.queryParameters['data']?.hashCode}_${parsed?['shortId']}';
      if (_lastHandledPlaylistHash == hash &&
          _lastHandledTime != null &&
          now.difference(_lastHandledTime!).inMilliseconds < 2500) {
        log('Ignoring duplicate playlist deep link within 2.5s',
            name: 'OrviaDeepLinkService');
        return true;
      }

      _lastHandledPlaylistHash = hash;
      _lastHandledTime = now;
      _isHandlingDeepLink = true;
      _hasHandledColdStartDeepLink = true;

      void pushScreen() {
        final nav = AppRouter.globalRouterKey.currentState;
        if (nav != null) {
          nav.push(MaterialPageRoute(
            builder: (context) => SharedPlaylistScreen(playlist: targetPlaylist),
          ));
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final retryNav = AppRouter.globalRouterKey.currentState;
            if (retryNav != null) {
              retryNav.push(MaterialPageRoute(
                builder: (context) => SharedPlaylistScreen(playlist: targetPlaylist),
              ));
            } else {
              Future.delayed(const Duration(milliseconds: 300), () {
                AppRouter.globalRouterKey.currentState?.push(MaterialPageRoute(
                  builder: (context) =>
                      SharedPlaylistScreen(playlist: targetPlaylist),
                ));
              });
            }
          });
        }
      }

      pushScreen();
      _pendingDeepLinkUri = null;
      _isHandlingDeepLink = false;
      return true;
    } catch (e, stack) {
      _isHandlingDeepLink = false;
      log('Failed to handle playlist deep link: $e',
          error: e, stackTrace: stack, name: 'OrviaDeepLinkService');
      return false;
    }
  }

  /// Handles an incoming deep link URI end-to-end:
  /// Parses, validates, guards against duplicate playback starts/queues, and routes appropriately.
  static Future<bool> handleDeepLinkUri(Uri uri) async {
    try {
      final parsed = parseDeepLink(uri);
      if (parsed == null) {
        log('Deep link URI not recognized: $uri', name: 'OrviaDeepLinkService');
        return false;
      }

      if (parsed['type'] == 'playlist') {
        return await handlePlaylistDeepLinkUri(uri);
      }

      final track = parseTrackFromUri(uri);
      if (track == null) {
        log('Deep link URI not recognized or missing track data: $uri',
            name: 'OrviaDeepLinkService');
        return false;
      }

      // Deduplication guard: ignore duplicate calls for the same track within 2.5s
      final now = DateTime.now();
      if (_lastHandledTrackId != null &&
          isMatchingTrackId(_lastHandledTrackId, track.id) &&
          _lastHandledTime != null &&
          now.difference(_lastHandledTime!).inMilliseconds < 2500) {
        log('Ignoring duplicate deep link handling for track "${track.id}" within 2.5s',
            name: 'OrviaDeepLinkService');
        return true;
      }

      final currentReqId = ++activeRequestId;
      _isHandlingDeepLink = true;
      _hasHandledColdStartDeepLink = true;
      _lastHandledTrackId = track.id;
      _lastHandledTime = now;

      try {
        final player = await PlayerInitializer().getOrviaMusicPlayer();
        if (currentReqId != activeRequestId) {
          log('Aborting deep link request #$currentReqId because request #$activeRequestId took priority.',
              name: 'OrviaDeepLinkService');
          return false;
        }

        final currentMedia = player.mediaItem.valueOrNull;

        // Duplicate guard: if already loaded/playing the exact same track ID, avoid restarting
        if (currentMedia != null && isMatchingTrackId(currentMedia.id, track.id)) {
          log('Deep link track "${track.title}" is already loaded in player.',
              name: 'OrviaDeepLinkService');
          if (!(player.playbackState.valueOrNull?.playing ?? false)) {
            await player.play();
          }
          if (currentReqId == activeRequestId) {
            _pendingDeepLinkUri = null;
          }
          return true;
        }

        await player.updateQueueTracks(
          [track],
          doPlay: true,
          queueTitle: 'Shared Track',
        );

        if (currentReqId != activeRequestId) {
          return false;
        }

        if (track.title.isNotEmpty && track.title != 'Unknown Track') {
          SnackbarService.showMessage('Playing: ${track.title}');
        }

        // If track has missing or unknown metadata, asynchronously resolve full details
        if (track.title == 'Unknown Track' ||
            track.artists.isEmpty ||
            track.artists.first.name.isEmpty) {
          unawaited(
            SongMetadataRefreshService.refreshTrack(track, player: player).then((result) {
              if (result.isSuccess && result.track != null) {
                log('Refreshed shared track metadata: "${result.track!.title}"',
                    name: 'OrviaDeepLinkService');
              }
            }),
          );
        }
        return true;
      } finally {
        if (currentReqId == activeRequestId) {
          _isHandlingDeepLink = false;
          _pendingDeepLinkUri = null;
        }
      }
    } catch (e, stack) {
      _isHandlingDeepLink = false;
      log('Failed to handle deep link URI: $e',
          error: e, stackTrace: stack, name: 'OrviaDeepLinkService');
      return false;
    }
  }
}
