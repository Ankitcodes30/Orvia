import 'package:Orvia/src/rust/api/plugin/models.dart';

/// Centralized utility for computing stable track identities and deduplicating
/// song lists across pagination, retries, and discovery categories.
class TrackIdentity {
  TrackIdentity._();

  /// Computes a stable, canonical identity key for a [Track].
  ///
  /// Priority:
  /// 1. Stamped / provider ID (e.g. `content-resolver.bloomfactory.jisaavn::W13ekRcO`)
  /// 2. Canonical URL if available
  /// 3. Normalized Title + Artist fallback
  static String computeKey(Track track) {
    // 1. Provider/source ID
    final id = track.id.trim();
    if (id.isNotEmpty) {
      return 'id:${id.toLowerCase()}';
    }

    // 2. Canonical source URL
    final url = track.url?.trim();
    if (url != null && url.isNotEmpty) {
      return 'url:${_normalizeUrl(url)}';
    }

    // 3. Normalized Title + Artist fallback
    final normTitle = _normalizeTitle(track.title);
    final artistNames = sanitizeArtistSummaries(track.artists)
        .map((a) => a.name.trim())
        .where((n) => n.isNotEmpty)
        .join(', ');
    final normArtist = _normalizeArtist(artistNames);

    return 'fallback:$normTitle::$normArtist';
  }

  /// Normalizes track title while preserving version distinctions
  /// (such as Remix, Acoustic, Live, Instrumental, etc.).
  static String _normalizeTitle(String title) {
    var clean = title.trim().toLowerCase();

    // Remove file extensions if any
    clean = clean.replaceAll(RegExp(r'\.(mp3|m4a|flac|wav|ogg|aac)$', caseSensitive: false), '');

    // Strip purely promotional video bracketed noise, but preserve genuine music versions
    clean = clean.replaceAll(
      RegExp(
        r'\[(official\s*(music\s*)?video|video|audio|lyrics?|full\s*song|4k|8k|hd)\]',
        caseSensitive: false,
      ),
      '',
    );
    clean = clean.replaceAll(
      RegExp(
        r'\((official\s*(music\s*)?video|video|audio|lyrics?|full\s*song|4k|8k|hd)\)',
        caseSensitive: false,
      ),
      '',
    );

    // Normalize whitespace
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean;
  }

  /// Normalizes artist name string.
  static String _normalizeArtist(String artists) {
    var clean = artists.trim().toLowerCase();
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean;
  }

  /// Canonicalizes URLs for identity comparison.
  static String _normalizeUrl(String url) {
    try {
      final uri = Uri.parse(url.trim());
      // For YouTube, extract video ID
      if (uri.host.contains('youtube.com')) {
        final v = uri.queryParameters['v'];
        if (v != null && v.isNotEmpty) return 'youtube:$v';
      } else if (uri.host.contains('youtu.be')) {
        if (uri.pathSegments.isNotEmpty) return 'youtube:${uri.pathSegments.first}';
      }
      return '${uri.host}${uri.path}'.toLowerCase();
    } catch (_) {
      return url.trim().toLowerCase();
    }
  }

  /// Deduplicates [tracks], preserving their original order.
  /// If [existingTracks] is provided, tracks that match any existing track
  /// will also be omitted.
  static List<Track> deduplicateTracks(
    Iterable<Track> tracks, {
    Iterable<Track>? existingTracks,
  }) {
    final seenKeys = <String>{};

    if (existingTracks != null) {
      for (final t in existingTracks) {
        seenKeys.add(computeKey(t));
      }
    }

    final unique = <Track>[];
    for (final t in tracks) {
      final key = computeKey(t);
      if (seenKeys.add(key)) {
        unique.add(t);
      }
    }

    return unique;
  }

  /// Computes a semantic identity key based on normalized title and artist.
  /// This detects duplicate uploads of the exact same song across different video IDs
  /// (e.g. Official Video vs Lyrical Video vs Audio Track).
  static String computeSemanticKey(Track track) {
    final normTitle = _normalizeTitle(track.title);
    final artistNames = sanitizeArtistSummaries(track.artists)
        .map((a) => a.name.trim())
        .where((n) => n.isNotEmpty)
        .join(', ');
    final normArtist = _normalizeArtist(artistNames);
    return 'semantic:$normTitle::$normArtist';
  }

  /// Regex to identify YouTube view-count or upload-time metadata strings
  /// mistakenly assigned to artist fields (e.g. "142 views", "1.2M views", "12K views", "8mo ago", "3 years ago").
  static final _viewCountOrTimestampPattern = RegExp(
    r'^\s*[\d,\.]+\s*(?:K|M|B)?\s*views?\s*$|^\s*[\d,\.]+\s*(?:sec|min|hours?|days?|weeks?|months?|mo|years?|yr)s?\s*ago\s*$',
    caseSensitive: false,
  );

  /// Checks if a string is a YouTube view count or timestamp artifact instead of a genuine artist name.
  static bool isViewCountOrMetadataArtifact(String str) {
    final trimmed = str.trim();
    if (trimmed.isEmpty) return false;
    return _viewCountOrTimestampPattern.hasMatch(trimmed);
  }

  /// Sanitizes an artist string, filtering out view counts and metadata noise.
  /// If the raw artist is a view count, falls back to [fallback] (e.g. channel name).
  static String sanitizeArtist(String rawArtist, {String fallback = 'Unknown Artist'}) {
    final trimmed = rawArtist.trim();
    if (trimmed.isEmpty || isViewCountOrMetadataArtifact(trimmed)) {
      return fallback;
    }
    return trimmed;
  }

  /// Sanitizes a list of [ArtistSummary], discarding items that are view counts or timestamps.
  /// If all items are noise, returns a single fallback [ArtistSummary] with [channelFallback].
  static List<ArtistSummary> sanitizeArtistSummaries(
    List<ArtistSummary> artists, {
    String channelFallback = 'Unknown Artist',
    String? channelId,
  }) {
    final valid = artists
        .where((a) => !isViewCountOrMetadataArtifact(a.name) && a.name.trim().isNotEmpty)
        .toList();
    if (valid.isNotEmpty) {
      return valid;
    }
    return [
      ArtistSummary(
        id: channelId ?? '',
        name: channelFallback,
      ),
    ];
  }

  /// Deduplicates [tracks] semantically (by title + artist) preserving original order.
  static List<Track> deduplicateTracksSemantically(
    Iterable<Track> tracks, {
    Iterable<Track>? existingTracks,
  }) {
    final seenKeys = <String>{};
    final seenIds = <String>{};

    if (existingTracks != null) {
      for (final t in existingTracks) {
        if (t.id.isNotEmpty) seenIds.add(t.id);
        seenKeys.add(computeSemanticKey(t));
      }
    }

    final unique = <Track>[];
    for (final t in tracks) {
      if (t.id.isNotEmpty && !seenIds.add(t.id)) {
        continue;
      }
      final key = computeSemanticKey(t);
      if (seenKeys.add(key)) {
        unique.add(t);
      }
    }
    return unique;
  }

  /// Checks whether two track IDs refer to the same underlying track,
  /// accounting for provider prefix differences (e.g. clean ID vs composite ID).
  static bool isMatchingTrackId(String id1, String id2) {
    if (id1 == id2) return true;
    if (id1.isEmpty || id2.isEmpty) return false;
    final clean1 = id1.contains('::') ? id1.split('::').last : id1;
    final clean2 = id2.contains('::') ? id2.split('::').last : id2;
    return clean1 == clean2;
  }
}
