/// Data models for the cloud-sync subsystem.
///
/// These are plain Dart view-models used by the pure [MergeEngine] and by the
/// Firestore data source. They deliberately do not import Isar or Firebase so
/// merge logic can be unit-tested without any external dependency.
///
/// Timestamps are compared as UTC instants. Values read from Firestore arrive
/// as UTC `DateTime`s; values extracted locally are converted with
/// `DateTime.toUtc()` before entering the merge.
library sync_models;

import 'package:Orvia/services/cloud_sync/sync_config.dart';
import 'package:Orvia/services/cloud_sync/sync_record_kind.dart';

/// A playlist record as stored in the cloud.
class CloudPlaylistDoc {
  final String syncId;
  final String name;
  final String? subtitle;
  final String? description;
  final String? thumbnailUrl;
  final bool isPinned;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Non-null means the playlist was deleted (tombstone). Tombstoned docs are
  /// retained so deletion can propagate and stale devices can reconcile.
  final DateTime? deletedAt;

  const CloudPlaylistDoc({
    required this.syncId,
    required this.name,
    this.subtitle,
    this.description,
    this.thumbnailUrl,
    required this.isPinned,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  CloudPlaylistDoc copyWith({
    String? name,
    String? subtitle,
    String? description,
    String? thumbnailUrl,
    bool? isPinned,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) =>
      CloudPlaylistDoc(
        syncId: syncId,
        name: name ?? this.name,
        subtitle: subtitle ?? this.subtitle,
        description: description ?? this.description,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        isPinned: isPinned ?? this.isPinned,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt,
      );

  Map<String, dynamic> toFirestore() => {
        'syncId': syncId,
        'name': name,
        'subtitle': subtitle,
        'description': description,
        'thumbnailUrl': thumbnailUrl,
        'isPinned': isPinned,
        'sortOrder': sortOrder,
        'createdAt': createdAt.toUtc().millisecondsSinceEpoch,
        'updatedAt': updatedAt.toUtc().millisecondsSinceEpoch,
        'deletedAt': deletedAt?.toUtc().millisecondsSinceEpoch,
      };

  factory CloudPlaylistDoc.fromFirestore(Map<String, dynamic> map) =>
      CloudPlaylistDoc(
        syncId: (map['syncId'] as String?) ?? '',
        name: (map['name'] as String?) ?? '',
        subtitle: map['subtitle'] as String?,
        description: map['description'] as String?,
        thumbnailUrl: map['thumbnailUrl'] as String?,
        isPinned: (map['isPinned'] as bool?) ?? false,
        sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
        createdAt: _msToUtc(map['createdAt']),
        updatedAt: _msToUtc(map['updatedAt']),
        deletedAt: map['deletedAt'] == null
            ? null
            : _msToUtc(map['deletedAt']),
      );

  static DateTime _msToUtc(dynamic ms) => ms is num && ms > 0
      ? DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true)
      : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

/// A playlist-entry record as stored in the cloud (subcollection of a
/// playlist doc).
class CloudEntryDoc {
  /// Document id (stable UUID). Never derived from position — entries move.
  final String entryId;

  /// Sync id of the owning playlist (denormalized for convenience).
  final String playlistSyncId;

  /// Orvia composite media id (`"{pluginId}::{localId}"`).
  final String mediaId;

  final int position;
  final DateTime addedAt;
  final DateTime? deletedAt;

  const CloudEntryDoc({
    required this.entryId,
    required this.playlistSyncId,
    required this.mediaId,
    required this.position,
    required this.addedAt,
    this.deletedAt,
  });

  bool entryBelongsTo(String playlistSyncId) =>
      this.playlistSyncId == playlistSyncId;

  Map<String, dynamic> toFirestore() => {
        'entryId': entryId,
        'mediaId': mediaId,
        'position': position,
        'addedAt': addedAt.toUtc().millisecondsSinceEpoch,
        'deletedAt': deletedAt?.toUtc().millisecondsSinceEpoch,
      };

  factory CloudEntryDoc.fromFirestore(Map<String, dynamic> map) =>
      CloudEntryDoc(
        entryId: (map['entryId'] as String?) ?? '',
        playlistSyncId: (map['playlistSyncId'] as String?) ?? '',
        mediaId: (map['mediaId'] as String?) ?? '',
        position: (map['position'] as num?)?.toInt() ?? 0,
        addedAt: CloudPlaylistDoc._msToUtc(map['addedAt']),
        deletedAt: map['deletedAt'] == null
            ? null
            : CloudPlaylistDoc._msToUtc(map['deletedAt']),
      );
}

/// A favourite record as stored in the cloud. Keyed by [mediaId].
class CloudFavouriteDoc {
  final String mediaId;
  final DateTime addedAt;
  final DateTime? deletedAt;

  const CloudFavouriteDoc({
    required this.mediaId,
    required this.addedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toFirestore() => {
        'addedAt': addedAt.toUtc().millisecondsSinceEpoch,
        'deletedAt': deletedAt?.toUtc().millisecondsSinceEpoch,
      };

  factory CloudFavouriteDoc.fromFirestore(Map<String, dynamic> map) =>
      CloudFavouriteDoc(
        mediaId: (map['mediaId'] as String?) ?? '',
        addedAt: CloudPlaylistDoc._msToUtc(map['addedAt']),
        deletedAt: map['deletedAt'] == null
            ? null
            : CloudPlaylistDoc._msToUtc(map['deletedAt']),
      );
}

/// A user preference as stored in the cloud.
class CloudSettingDoc {
  final String key;
  final String value;
  final DateTime updatedAt;

  const CloudSettingDoc({
    required this.key,
    required this.value,
    required this.updatedAt,
  });

  Map<String, dynamic> toFirestore() => {
        'value': value,
        'updatedAt': updatedAt.toUtc().millisecondsSinceEpoch,
      };

  factory CloudSettingDoc.fromFirestore(Map<String, dynamic> map) =>
      CloudSettingDoc(
        key: (map['key'] as String?) ?? '',
        value: (map['value'] as String?) ?? '',
        updatedAt: CloudPlaylistDoc._msToUtc(map['updatedAt']),
      );
}

/// A complete snapshot of one account's cloud state.
class CloudSnapshot {
  final int schemaVersion;
  final List<CloudPlaylistDoc> playlists;
  final List<CloudEntryDoc> entries;
  final List<CloudFavouriteDoc> favourites;
  final List<CloudSettingDoc> settings;

  const CloudSnapshot({
    this.schemaVersion = kCloudSyncSchemaVersion,
    required this.playlists,
    required this.entries,
    required this.favourites,
    required this.settings,
  });

  /// Playlists that are alive (not tombstoned).
  Iterable<CloudPlaylistDoc> get livePlaylists =>
      playlists.where((p) => p.deletedAt == null);

  /// Entries belonging to [playlistSyncId], alive only, sorted by position.
  List<CloudEntryDoc> liveEntriesOf(String playlistSyncId) {
    final list = entries
        .where((e) => e.entryBelongsTo(playlistSyncId) && e.deletedAt == null)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return list;
  }

  /// Entries grouped by playlist sync id.
  Map<String, List<CloudEntryDoc>> get entriesByPlaylist {
    final map = <String, List<CloudEntryDoc>>{};
    for (final e in entries) {
      map.putIfAbsent(e.playlistSyncId, () => []).add(e);
    }
    return map;
  }
}

/// Local counterpart of a synced playlist (Isar-agnostic view).
class LocalPlaylistData {
  /// Isar auto-increment id (device-local).
  final int localId;
  final String name;
  final String? subtitle;
  final String? description;
  final String? thumbnailUrl;
  final bool isPinned;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Stable cloud id (may be null for guest-native records).
  final String? syncId;

  /// Alive entries ordered by position, deduplicated by mediaId.
  final List<LocalEntryData> entries;

  const LocalPlaylistData({
    required this.localId,
    required this.name,
    this.subtitle,
    this.description,
    this.thumbnailUrl,
    required this.isPinned,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.syncId,
    required this.entries,
  });
}

/// Local counterpart of a playlist entry.
class LocalEntryData {
  final int localId;
  final String mediaId;
  final int position;
  final DateTime addedAt;
  final String? syncId;

  const LocalEntryData({
    required this.localId,
    required this.mediaId,
    required this.position,
    required this.addedAt,
    this.syncId,
  });
}

/// Local counterpart of a favourite (membership in the "Liked" playlist).
class LocalFavouriteData {
  final String mediaId;
  final DateTime addedAt;

  const LocalFavouriteData({required this.mediaId, required this.addedAt});
}

/// Local counterpart of a synced preference.
class LocalSettingData {
  final String key;
  final String value;
  final DateTime updatedAt;

  const LocalSettingData({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
}

/// Everything the merge engine needs to know about the local store.
class LocalSnapshot {
  final List<LocalPlaylistData> playlists;
  final List<LocalFavouriteData> favourites;
  final List<LocalSettingData> settings;

  const LocalSnapshot({
    required this.playlists,
    required this.favourites,
    required this.settings,
  });
}

// ── Merge plan mutations ──────────────────────────────────────────────────────

/// A mutation that must be applied to the local store.
sealed class LocalMutation {
  const LocalMutation();
}

/// Create or update a local playlist from the cloud, replacing its entries.
class UpsertPlaylistLocal extends LocalMutation {
  final CloudPlaylistDoc playlist;
  final List<CloudEntryDoc> entries;

  const UpsertPlaylistLocal(this.playlist, this.entries);
}

/// Delete a local playlist because a newer cloud tombstone won.
class DeletePlaylistLocal extends LocalMutation {
  final int localId;
  final String cloudId;

  const DeletePlaylistLocal({required this.localId, required this.cloudId});
}

/// Mark a track as liked locally (cloud favourite won).
class LikeLocal extends LocalMutation {
  final String mediaId;
  final DateTime addedAt;

  const LikeLocal({required this.mediaId, required this.addedAt});
}

/// Mark a track as unliked locally (cloud tombstone won).
class UnlikeLocal extends LocalMutation {
  final String mediaId;

  const UnlikeLocal({required this.mediaId});
}

/// Apply a preference value locally (cloud version won).
class ApplySettingLocal extends LocalMutation {
  final String key;
  final String value;

  const ApplySettingLocal({required this.key, required this.value});
}

/// A mutation that must be pushed to the cloud.
sealed class CloudMutation {
  const CloudMutation();
}

/// Upsert playlist metadata in the cloud (live doc or tombstone).
class PutPlaylistCloud extends CloudMutation {
  final CloudPlaylistDoc playlist;

  const PutPlaylistCloud(this.playlist);
}

/// Upsert entries (live or tombstoned) for a cloud playlist.
class PutEntriesCloud extends CloudMutation {
  final String playlistSyncId;
  final List<CloudEntryDoc> entries;

  const PutEntriesCloud(this.playlistSyncId, this.entries);
}

/// Upsert a favourite (live or tombstone).
class PutFavouriteCloud extends CloudMutation {
  final CloudFavouriteDoc favourite;

  const PutFavouriteCloud(this.favourite);
}

/// Upsert a preference.
class PutSettingCloud extends CloudMutation {
  final CloudSettingDoc setting;

  const PutSettingCloud(this.setting);
}

/// Records that were adopted (downloaded) from the cloud for [uid] and must
/// be recorded in the adoption ledger.
class AdoptionRecord {
  final String recordKey;
  final SyncRecordKind kind;
  final String uid;

  const AdoptionRecord({
    required this.recordKey,
    required this.kind,
    required this.uid,
  });
}

/// The complete, deterministic result of merging local and cloud state.
class MergePlan {
  final List<LocalMutation> localMutations;
  final List<CloudMutation> cloudMutations;
  final List<AdoptionRecord> adoptions;

  /// True when the cloud snapshot's schema version is newer than the one
  /// this build understands. No mutations were produced.
  final bool schemaTooNew;

  const MergePlan({
    required this.localMutations,
    required this.cloudMutations,
    required this.adoptions,
    this.schemaTooNew = false,
  });

  bool get isEmpty =>
      localMutations.isEmpty &&
      cloudMutations.isEmpty &&
      adoptions.isEmpty &&
      !schemaTooNew;
}
