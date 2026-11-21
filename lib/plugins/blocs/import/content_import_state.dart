import 'package:equatable/equatable.dart';

import 'package:Orvia/plugins/utils/media_id.dart';
import 'package:Orvia/src/rust/api/plugin/models.dart';

enum ImportPhase {
  idle,
  checkingUrl,
  fetchingInfo,
  fetchingTracks,
  resolving,
  review,
  saving,
  done,
  error,
}

/// Resolution status of a single track during import.
enum TrackResolutionStatus {
  pending,
  resolving,
  resolved,
  failed,
}

/// A track from the import source paired with its resolution state.
class ImportTrackEntry extends Equatable {
  final ImportTrackItem sourceTrack;
  final TrackResolutionStatus status;

  /// Best auto-resolved track (first candidate found).
  final Track? resolvedTrack;

  /// Up to 5 candidate tracks from search results.
  final List<Track> candidates;

  /// User-selected candidate index.
  /// - null  → use [resolvedTrack] (auto best)
  /// - >= 0  → use [candidates[selectedCandidateIndex]]
  /// - -1    → user explicitly skipped this track
  final int? selectedCandidateIndex;

  const ImportTrackEntry({
    required this.sourceTrack,
    this.status = TrackResolutionStatus.pending,
    this.resolvedTrack,
    this.candidates = const [],
    this.selectedCandidateIndex,
  });

  /// Whether the user has explicitly chosen to skip this track.
  bool get isSkipped => selectedCandidateIndex == -1;

  /// The track that will be saved (respects user selection / skip).
  ///
  /// Returns a valid [Track] ONLY when:
  /// 1. The user explicitly chose a valid candidate, OR
  /// 2. Cross-plugin resolution found a high-confidence playable match ([resolvedTrack]), OR
  /// 3. The source track is ALREADY legitimately stamped from an active provider (e.g. JioSaavn).
  ///
  /// NEVER stamps an arbitrary YouTube video ID or Spotify ID as a JioSaavn ID.
  Track? get effectiveTrack {
    if (isSkipped) return null;
    final idx = selectedCandidateIndex;
    if (idx != null && idx >= 0 && idx < candidates.length) {
      return candidates[idx];
    }
    if (resolvedTrack != null) {
      return resolvedTrack;
    }

    // Only preserve source track directly if it is ALREADY legitimately stamped
    // from an authorized active provider (e.g., imported from native JioSaavn collection).
    final rawSourceId = sourceTrack.sourceId;
    if (rawSourceId != null && isStampedId(rawSourceId) && sourceTrack.title.trim().isNotEmpty) {
      final thumb = sourceTrack.thumbnailUrl;
      final artwork = (thumb != null && thumb.isNotEmpty)
          ? Artwork(
              url: thumb,
              urlLow: thumb,
              urlHigh: thumb,
              layout: ImageLayout.square)
          : const Artwork(url: '', layout: ImageLayout.square);

      return Track(
        id: rawSourceId,
        title: sourceTrack.title,
        artists: sourceTrack.artists
            .map((a) => ArtistSummary(id: '', name: a, thumbnail: artwork))
            .toList(),
        album: AlbumSummary(
          id: '',
          title: sourceTrack.albumTitle ?? '',
          artists: const [],
          thumbnail: artwork,
        ),
        durationMs: sourceTrack.durationMs ?? BigInt.zero,
        thumbnail: artwork,
        isExplicit: sourceTrack.isExplicit,
      );
    }

    // Unmatched tracks without a playable resolver mapping are NOT playable
    return null;
  }

  /// Whether this entry has a confirmed, playable track ready to be saved.
  bool get isPlayable => effectiveTrack != null;

  /// Whether this entry could not be matched to a playable audio provider.
  bool get isUnmatched => !isSkipped && effectiveTrack == null;

  ImportTrackEntry copyWith({
    TrackResolutionStatus? status,
    Track? resolvedTrack,
    List<Track>? candidates,
    int? selectedCandidateIndex,
    bool clearSelection = false,
  }) {
    return ImportTrackEntry(
      sourceTrack: sourceTrack,
      status: status ?? this.status,
      resolvedTrack: resolvedTrack ?? this.resolvedTrack,
      candidates: candidates ?? this.candidates,
      selectedCandidateIndex: clearSelection
          ? null
          : (selectedCandidateIndex ?? this.selectedCandidateIndex),
    );
  }

  @override
  List<Object?> get props =>
      [sourceTrack, status, resolvedTrack, candidates, selectedCandidateIndex];
}

class ContentImportState extends Equatable {
  final ImportPhase phase;
  final String? pluginId;
  final String? url;
  final ImportCollectionSummary? collectionInfo;
  final List<ImportTrackEntry> tracks;
  final int resolvedCount;
  final int failedCount;
  final String? error;

  const ContentImportState({
    this.phase = ImportPhase.idle,
    this.pluginId,
    this.url,
    this.collectionInfo,
    this.tracks = const [],
    this.resolvedCount = 0,
    this.failedCount = 0,
    this.error,
  });

  ContentImportState copyWith({
    ImportPhase? phase,
    String? pluginId,
    String? url,
    ImportCollectionSummary? collectionInfo,
    List<ImportTrackEntry>? tracks,
    int? resolvedCount,
    int? failedCount,
    String? error,
    bool clearError = false,
  }) {
    return ContentImportState(
      phase: phase ?? this.phase,
      pluginId: pluginId ?? this.pluginId,
      url: url ?? this.url,
      collectionInfo: collectionInfo ?? this.collectionInfo,
      tracks: tracks ?? this.tracks,
      resolvedCount: resolvedCount ?? this.resolvedCount,
      failedCount: failedCount ?? this.failedCount,
      error: clearError ? null : (error ?? this.error),
    );
  }

  int get totalTracks => tracks.length;

  /// Count of tracks that have a confirmed playable match.
  int get playableCount => tracks.where((t) => t.isPlayable).length;

  /// Count of tracks that failed to resolve to a playable audio provider.
  int get unmatchedCount => tracks.where((t) => t.isUnmatched).length;

  /// Count of tracks explicitly skipped by the user.
  int get skippedCount => tracks.where((t) => t.isSkipped).length;

  @override
  List<Object?> get props => [
        phase,
        pluginId,
        url,
        collectionInfo,
        tracks,
        resolvedCount,
        failedCount,
        error,
      ];
}
