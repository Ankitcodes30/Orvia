/// Pure, deterministic merge engine for cloud sync.
///
/// Consumes a [CloudSnapshot], a [LocalSnapshot], local-deletion records, and
/// the cross-account adoption ledger; produces a [MergePlan] of mutations for
/// both sides. Contains **no I/O** — no Isar, Firestore, or Flutter imports —
/// so all conflict rules are unit-testable in isolation.
///
/// ## Conflict rules (deterministic, least-destructive)
///
/// - **Playlist metadata**: last-writer-wins on `updatedAt`. Exact ties are
///   treated as "no change".
/// - **Entries**: set-union keyed by [CloudEntryDoc.mediaId]; per-entry
///   last-writer-wins between an alive record and a tombstone (`deletedAt`
///   vs `addedAt`; exact tie → the deletion wins, since a deletion is an
///   explicit user act).
/// - **Ordering**: the side with the newer playlist `updatedAt` determines
///   the order of entries present on both sides; entries that exist only on
///   the losing side are appended (their positions are preserved in the
///   cloud; nothing is discarded).
/// - **Playlist deletion**: tombstone wins over a playlist whose `updatedAt`
///   is older; if the playlist was edited after the deletion, the edit wins
///   and the playlist is resurrected (least destructive).
/// - **Favourites**: per-mediaId LWW (`deletedAt` vs `addedAt`).
/// - **Settings**: per-key LWW on `updatedAt`; only [kSyncableSettingKeys]
///   participate.
/// - **Cross-account holdback**: records adopted from a *different* account
///   (present in `adoptedByOtherUids`) and absent from the current account's
///   cloud are never pushed — they remain playable locally but cannot leak
///   into another account's cloud.
///
/// Clock skew: LWW compares device clocks. This is the pragmatic standard
/// for single-user backup sync; skew only misorders near-simultaneous edits
/// and never loses data silently (the older edit remains in the record
/// history via timestamps).
library merge_engine;

import 'dart:convert' show utf8;

import 'package:crypto/crypto.dart';
import 'package:Orvia/services/cloud_sync/sync_config.dart';
import 'package:Orvia/services/cloud_sync/sync_models.dart';
import 'package:Orvia/services/cloud_sync/sync_record_kind.dart';

/// A locally deleted record that was previously synchronized.
///
/// The local store has no per-record tombstones; instead the sync layer keeps
/// [SyncStateDB] rows, and a row whose local record has disappeared becomes a
/// [LocalDeletion] on the next merge.
class LocalDeletion {
  final SyncRecordKind kind;

  /// Cloud record id (syncId / entryId / mediaId / settings key).
  final String cloudId;

  /// When the deletion is being reconciled (used as the tombstone time).
  final DateTime deletedAt;

  const LocalDeletion({
    required this.kind,
    required this.cloudId,
    required this.deletedAt,
  });
}

/// Canonical string used for content hashing (change detection).
String canonicalPlaylistHash(
  String name,
  String? subtitle,
  String? description,
  String? thumbnailUrl,
  bool isPinned,
  int sortOrder,
  List<String> orderedMediaIds,
) =>
    sha256.convert(utf8.encode([
      name,
      subtitle ?? '',
      description ?? '',
      thumbnailUrl ?? '',
      isPinned ? '1' : '0',
      '$sortOrder',
      orderedMediaIds.join('\u{1}'),
    ].join('\u{0}'))).toString();

class MergeEngine {
  const MergeEngine._();

  /// Merge [cloud] with [local], producing a [MergePlan].
  ///
  /// [adoptedByOtherUids] contains `"kind:recordKey"` strings for records
  /// adopted from accounts other than the current one.
  /// [now] is the timestamp used for tombstones reconciling local deletions.
  static MergePlan merge({
    required CloudSnapshot cloud,
    required LocalSnapshot local,
    required List<LocalDeletion> localDeletions,
    required Set<String> adoptedByOtherUids,
    required String uid,
    DateTime? now,
  }) {
    if (cloud.schemaVersion > kCloudSyncSchemaVersion) {
      return const MergePlan(
        localMutations: [],
        cloudMutations: [],
        adoptions: [],
        schemaTooNew: true,
      );
    }

    final effectiveNow = now ?? DateTime.now().toUtc();

    final deletionsByKind = <SyncRecordKind, Map<String, DateTime>>{};
    for (final d in localDeletions) {
      deletionsByKind.putIfAbsent(d.kind, () => {})[d.cloudId] = d.deletedAt;
    }

    final localMutations = <LocalMutation>[];
    final cloudMutations = <CloudMutation>[];
    final adoptions = <AdoptionRecord>[];

    _mergePlaylists(
      cloud: cloud,
      local: local,
      deletionsByKind: deletionsByKind,
      adoptedByOtherUids: adoptedByOtherUids,
      uid: uid,
      now: effectiveNow,
      localMutations: localMutations,
      cloudMutations: cloudMutations,
      adoptions: adoptions,
    );

    _mergeFavourites(
      cloud: cloud,
      local: local,
      deletionsByKind: deletionsByKind,
      adoptedByOtherUids: adoptedByOtherUids,
      uid: uid,
      now: effectiveNow,
      localMutations: localMutations,
      cloudMutations: cloudMutations,
      adoptions: adoptions,
    );

    _mergeSettings(
      cloud: cloud,
      local: local,
      adoptedByOtherUids: adoptedByOtherUids,
      uid: uid,
      localMutations: localMutations,
      cloudMutations: cloudMutations,
      adoptions: adoptions,
    );

    return MergePlan(
      localMutations: localMutations,
      cloudMutations: cloudMutations,
      adoptions: adoptions,
    );
  }

  // ── Playlists ───────────────────────────────────────────────────────────────

  static void _mergePlaylists({
    required CloudSnapshot cloud,
    required LocalSnapshot local,
    required Map<SyncRecordKind, Map<String, DateTime>> deletionsByKind,
    required Set<String> adoptedByOtherUids,
    required String uid,
    required DateTime now,
    required List<LocalMutation> localMutations,
    required List<CloudMutation> cloudMutations,
    required List<AdoptionRecord> adoptions,
  }) {
    final cloudById = <String, CloudPlaylistDoc>{
      for (final p in cloud.playlists) p.syncId: p,
    };
    final entriesByPlaylist = cloud.entriesByPlaylist;

    // Track which cloud playlists have been claimed (name collisions).
    final claimedCloudIds = <String>{};
    final playlistDeletions = deletionsByKind[SyncRecordKind.playlist] ?? {};
    final entryDeletions = deletionsByKind[SyncRecordKind.entry] ?? {};

    for (final l in local.playlists) {
      CloudPlaylistDoc? c;
      if (l.syncId != null) {
        c = cloudById[l.syncId];
      } else {
        // Name-based fallback match against live cloud playlists.
        final key = l.name.toLowerCase();
        for (final cp in cloud.livePlaylists) {
          if (cp.name.toLowerCase() == key &&
              !claimedCloudIds.contains(cp.syncId)) {
            c = cp;
            break;
          }
        }
      }

      final holdback = l.syncId != null &&
          adoptedByOtherUids.contains('playlist:${l.syncId}');

      if (c != null) {
        claimedCloudIds.add(c.syncId);
        adoptions.add(AdoptionRecord(
          recordKey: c.syncId,
          kind: SyncRecordKind.playlist,
          uid: uid,
        ));

        if (c.deletedAt != null) {
          if (l.updatedAt.isAfter(c.deletedAt!)) {
            // Edited after the deletion happened → resurrect (least destructive).
            cloudMutations.add(PutPlaylistCloud(_localToCloud(l, c.syncId)));
            cloudMutations.add(PutEntriesCloud(
              c.syncId,
              _localEntriesToCloud(c.syncId, l.entries),
            ));
          } else {
            localMutations.add(DeletePlaylistLocal(
              localId: l.localId,
              cloudId: c.syncId,
            ));
          }
          continue;
        }

        final cloudNewer = c.updatedAt.isAfter(l.updatedAt);
        final localNewer = l.updatedAt.isAfter(c.updatedAt);

        if (cloudNewer) {
          final merged = _resolveEntries(
            localEntries: l.entries,
            cloudEntries: entriesByPlaylist[c.syncId] ?? const [],
            winner: _Winner.cloud,
            deletions: entryDeletions,
            holdback: holdback,
            playlistSyncId: c.syncId,
            uid: uid,
          );
          localMutations.add(UpsertPlaylistLocal(c, merged.localOrder));
          if (merged.toPush.isNotEmpty) {
            cloudMutations.add(PutEntriesCloud(c.syncId, merged.toPush));
          }
          _adoptEntries(merged, uid, adoptions, c.syncId);
        } else if (localNewer) {
          cloudMutations.add(PutPlaylistCloud(_localToCloud(l, c.syncId)));
          final merged = _resolveEntries(
            localEntries: l.entries,
            cloudEntries: entriesByPlaylist[c.syncId] ?? const [],
            winner: _Winner.local,
            deletions: entryDeletions,
            holdback: holdback,
            playlistSyncId: c.syncId,
            uid: uid,
          );
          if (merged.toPush.isNotEmpty) {
            cloudMutations.add(PutEntriesCloud(c.syncId, merged.toPush));
          }
          _adoptEntries(merged, uid, adoptions, c.syncId);
        } else {
          // Equal timestamps — union entries defensively in both directions.
          final merged = _resolveEntries(
            localEntries: l.entries,
            cloudEntries: entriesByPlaylist[c.syncId] ?? const [],
            winner: _Winner.neutral,
            deletions: entryDeletions,
            holdback: holdback,
            playlistSyncId: c.syncId,
            uid: uid,
          );
          if (merged.needsLocalApply) {
            localMutations.add(
                UpsertPlaylistLocal(c, merged.localOrder));
          }
          if (merged.toPush.isNotEmpty) {
            cloudMutations.add(PutEntriesCloud(c.syncId, merged.toPush));
          }
          _adoptEntries(merged, uid, adoptions, c.syncId);
        }
      } else {
        // No cloud counterpart.
        final deletionTime = l.syncId != null ? playlistDeletions[l.syncId] : null;
        if (deletionTime != null) {
          // Locally deleted since last sync → push tombstone.
          final cloudCopy = cloudById[l.syncId!];
          final base = cloudCopy ??
              CloudPlaylistDoc(
                syncId: l.syncId!,
                name: l.name,
                isPinned: l.isPinned,
                sortOrder: l.sortOrder,
                createdAt: l.createdAt.toUtc(),
                updatedAt: deletionTime,
              );
          cloudMutations.add(PutPlaylistCloud(base.copyWith(
            deletedAt: deletionTime,
            updatedAt: deletionTime,
          )));
          continue;
        }
        if (holdback) continue;
        // Guest-native or previously-unsynced record → push (self-healing for
        // records that were synced but vanished from the cloud).
        if (l.syncId != null) {
          cloudMutations.add(PutPlaylistCloud(_localToCloud(l, l.syncId!)));
          cloudMutations.add(PutEntriesCloud(
            l.syncId!,
            _localEntriesToCloud(l.syncId!, l.entries),
          ));
          adoptions.add(AdoptionRecord(
            recordKey: l.syncId!,
            kind: SyncRecordKind.playlist,
            uid: uid,
          ));
        }
      }
    }

    // Cloud playlists with no local counterpart.
    for (final c in cloud.playlists) {
      if (claimedCloudIds.contains(c.syncId)) continue;
      if (c.deletedAt != null) continue;
      // Respect local deletions: if this device deleted the playlist after
      // its last sync, don't re-download — the deletions pass tombstones it.
      final deletionTime = playlistDeletions[c.syncId];
      if (deletionTime != null && !c.updatedAt.isAfter(deletionTime)) {
        continue;
      }
      final entries = cloud.liveEntriesOf(c.syncId);
      localMutations.add(UpsertPlaylistLocal(c, entries));
      for (final e in entries) {
        adoptions.add(AdoptionRecord(
          recordKey: e.entryId,
          kind: SyncRecordKind.entry,
          uid: uid,
        ));
      }
      adoptions.add(AdoptionRecord(
        recordKey: c.syncId,
        kind: SyncRecordKind.playlist,
        uid: uid,
      ));
    }

    // Locally deleted, still alive in cloud (record existed locally only as a
    // synced row) → tombstone, unless the cloud was edited after the deletion.
    for (final entry in playlistDeletions.entries) {
      final cloudId = entry.key;
      if (cloudById[cloudId] == null) continue;
      if (claimedCloudIds.contains(cloudId)) continue;
      final c = cloudById[cloudId]!;
      if (c.deletedAt != null) continue; // already tombstoned
      if (c.updatedAt.isAfter(entry.value)) {
        // Cloud edited after our deletion → the cloud-only download loop
        // above already re-downloaded it (least destructive). Nothing to do.
        continue;
      }
      cloudMutations.add(PutPlaylistCloud(c.copyWith(
        deletedAt: entry.value,
        updatedAt: entry.value,
      )));
    }
  }

  static CloudPlaylistDoc _localToCloud(LocalPlaylistData l, String syncId) {
    return CloudPlaylistDoc(
      syncId: syncId,
      name: l.name.length > kMaxSyncPlaylistNameLength
          ? l.name.substring(0, kMaxSyncPlaylistNameLength)
          : l.name,
      subtitle: l.subtitle,
      description: l.description,
      thumbnailUrl: l.thumbnailUrl,
      isPinned: l.isPinned,
      sortOrder: l.sortOrder,
      createdAt: l.createdAt.toUtc(),
      updatedAt: l.updatedAt.toUtc(),
    );
  }

  static List<CloudEntryDoc> _localEntriesToCloud(
    String playlistSyncId,
    List<LocalEntryData> entries,
  ) =>
      entries
          .map((e) => CloudEntryDoc(
                entryId: e.syncId ?? '',
                playlistSyncId: playlistSyncId,
                mediaId: e.mediaId,
                position: e.position,
                addedAt: e.addedAt.toUtc(),
              ))
          .toList();

  static void _adoptEntries(
    _EntryMergeResult merged,
    String uid,
    List<AdoptionRecord> adoptions,
    String playlistSyncId,
  ) {
    for (final e in merged.adoptedCloudEntries) {
      adoptions.add(AdoptionRecord(
        recordKey: e.entryId,
        kind: SyncRecordKind.entry,
        uid: uid,
      ));
    }
    adoptions.add(AdoptionRecord(
      recordKey: playlistSyncId,
      kind: SyncRecordKind.playlist,
      uid: uid,
    ));
  }

  // ── Favourites ──────────────────────────────────────────────────────────────

  static void _mergeFavourites({
    required CloudSnapshot cloud,
    required LocalSnapshot local,
    required Map<SyncRecordKind, Map<String, DateTime>> deletionsByKind,
    required Set<String> adoptedByOtherUids,
    required String uid,
    required DateTime now,
    required List<LocalMutation> localMutations,
    required List<CloudMutation> cloudMutations,
    required List<AdoptionRecord> adoptions,
  }) {
    final localByMedia = <String, LocalFavouriteData>{
      for (final f in local.favourites) f.mediaId: f,
    };
    final cloudByMedia = <String, CloudFavouriteDoc>{
      for (final f in cloud.favourites) f.mediaId: f,
    };
    final favouriteDeletions =
        deletionsByKind[SyncRecordKind.favourite] ?? {};

    // Cloud → local.
    for (final cf in cloud.favourites) {
      final localAdded = localByMedia[cf.mediaId]?.addedAt;
      if (cf.deletedAt != null) {
        if (localAdded != null) {
          if (cf.deletedAt!.isBefore(localAdded)) {
            // Re-added locally after the cloud deletion → push live.
            cloudMutations.add(PutFavouriteCloud(CloudFavouriteDoc(
              mediaId: cf.mediaId,
              addedAt: localAdded.toUtc(),
            )));
          } else {
            localMutations.add(UnlikeLocal(mediaId: cf.mediaId));
          }
        }
      } else if (localAdded == null) {
        final deletionTime = favouriteDeletions[cf.mediaId];
        final cloudReAdded =
            deletionTime != null && cf.addedAt.isAfter(deletionTime);
        final locallyDeleted = deletionTime != null && !cloudReAdded;
        if (!locallyDeleted) {
          // Either a genuine new favourite from the cloud, or the cloud
          // re-liked the song after this device unliked it → resurrect.
          localMutations.add(LikeLocal(
            mediaId: cf.mediaId,
            addedAt: cf.addedAt,
          ));
          adoptions.add(AdoptionRecord(
            recordKey: cf.mediaId,
            kind: SyncRecordKind.favourite,
            uid: uid,
          ));
        }
        // Else: locally unliked after last sync → keep unliked. The deletions
        // pass below pushes the tombstone.
      }
    }

    // Local → cloud.
    for (final lf in local.favourites) {
      if (cloudByMedia.containsKey(lf.mediaId)) continue;
      final deletionTime = favouriteDeletions[lf.mediaId];
      if (deletionTime != null) {
        cloudMutations.add(PutFavouriteCloud(CloudFavouriteDoc(
          mediaId: lf.mediaId,
          addedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          deletedAt: deletionTime,
        )));
        continue;
      }
      if (adoptedByOtherUids.contains('favourite:${lf.mediaId}')) continue;
      cloudMutations.add(PutFavouriteCloud(CloudFavouriteDoc(
        mediaId: lf.mediaId,
        addedAt: lf.addedAt.toUtc(),
      )));
      adoptions.add(AdoptionRecord(
        recordKey: lf.mediaId,
        kind: SyncRecordKind.favourite,
        uid: uid,
      ));
    }

    // Locally deleted favourites still alive in the cloud → tombstone.
    for (final entry in favouriteDeletions.entries) {
      final mediaId = entry.key;
      if (cloudByMedia.containsKey(mediaId) &&
          cloudByMedia[mediaId]!.deletedAt == null) {
        cloudMutations.add(PutFavouriteCloud(CloudFavouriteDoc(
          mediaId: mediaId,
          addedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          deletedAt: entry.value,
        )));
      }
    }
  }

  // ── Settings ────────────────────────────────────────────────────────────────

  static void _mergeSettings({
    required CloudSnapshot cloud,
    required LocalSnapshot local,
    required Set<String> adoptedByOtherUids,
    required String uid,
    required List<LocalMutation> localMutations,
    required List<CloudMutation> cloudMutations,
    required List<AdoptionRecord> adoptions,
  }) {
    final localByKey = <String, LocalSettingData>{
      for (final s in local.settings) s.key: s,
    };
    final cloudByKey = <String, CloudSettingDoc>{
      for (final s in cloud.settings) s.key: s,
    };

    for (final key in kSyncableSettingKeys) {
      final l = localByKey[key];
      final c = cloudByKey[key];

      if (l == null && c == null) continue;

      if (l == null) {
        localMutations.add(ApplySettingLocal(key: key, value: c!.value));
        adoptions.add(AdoptionRecord(
          recordKey: key,
          kind: SyncRecordKind.setting,
          uid: uid,
        ));
        continue;
      }

      if (c == null) {
        if (adoptedByOtherUids.contains('setting:$key')) continue;
        cloudMutations.add(PutSettingCloud(CloudSettingDoc(
          key: key,
          value: l.value,
          updatedAt: l.updatedAt.toUtc(),
        )));
        adoptions.add(AdoptionRecord(
          recordKey: key,
          kind: SyncRecordKind.setting,
          uid: uid,
        ));
        continue;
      }

      if (l.updatedAt.isAfter(c.updatedAt)) {
        cloudMutations.add(PutSettingCloud(CloudSettingDoc(
          key: key,
          value: l.value,
          updatedAt: l.updatedAt.toUtc(),
        )));
      } else if (c.updatedAt.isAfter(l.updatedAt)) {
        localMutations.add(ApplySettingLocal(key: key, value: c.value));
        adoptions.add(AdoptionRecord(
          recordKey: key,
          kind: SyncRecordKind.setting,
          uid: uid,
        ));
      }
    }
  }

  // ── Entry resolution ────────────────────────────────────────────────────────

  static _EntryMergeResult _resolveEntries({
    required List<LocalEntryData> localEntries,
    required List<CloudEntryDoc> cloudEntries,
    required _Winner winner,
    required Map<String, DateTime> deletions,
    required bool holdback,
    required String playlistSyncId,
    required String uid,
  }) {
    final localByMedia = <String, LocalEntryData>{
      for (final e in localEntries) e.mediaId: e,
    };
    final cloudByMedia = <String, CloudEntryDoc>{
      for (final e in cloudEntries) e.mediaId: e,
    };

    // Alive media ids per side after LWW resolution.
    final aliveMedia = <String>{};
    final toPush = <CloudEntryDoc>[];
    final adoptedCloudEntries = <CloudEntryDoc>[];
    var needsLocalApply = false;

    // Pass 1 — LWW between cloud tombstones and local alive entries.
    for (final ce in cloudEntries) {
      if (ce.deletedAt != null) {
        final le = localByMedia[ce.mediaId];
        if (le != null && ce.deletedAt!.isBefore(le.addedAt)) {
          aliveMedia.add(ce.mediaId);
          toPush.add(CloudEntryDoc(
            entryId: ce.entryId,
            playlistSyncId: playlistSyncId,
            mediaId: ce.mediaId,
            position: le.position,
            addedAt: le.addedAt.toUtc(),
          ));
        }
      } else {
        final deletionTime = deletions[ce.entryId];
        if (deletionTime != null &&
            !localByMedia.containsKey(ce.mediaId) &&
            !ce.addedAt.isAfter(deletionTime)) {
          // The entry was removed on this device after its last sync and the
          // cloud hasn't re-added it since → keep it deleted. Push a tombstone
          // instead of resurrecting the row locally.
          toPush.add(CloudEntryDoc(
            entryId: ce.entryId,
            playlistSyncId: playlistSyncId,
            mediaId: ce.mediaId,
            position: ce.position,
            addedAt: ce.addedAt,
            deletedAt: deletionTime,
          ));
        } else {
          aliveMedia.add(ce.mediaId);
        }
      }
    }
    for (final le in localEntries) {
      if (aliveMedia.contains(le.mediaId)) continue;
      final ce = cloudByMedia[le.mediaId];
      if (ce != null && ce.deletedAt != null) continue; // tombstone won
      aliveMedia.add(le.mediaId);
      if (ce == null) {
        // Local-only entry → push (new entry needs a syncId; the applier
        // assigns one if missing).
        if (holdback) continue;
        toPush.add(CloudEntryDoc(
          entryId: le.syncId ?? '',
          playlistSyncId: playlistSyncId,
          mediaId: le.mediaId,
          position: le.position,
          addedAt: le.addedAt.toUtc(),
        ));
      }
    }

    // Pass 2 — final ordering.
    final cloudAliveSorted = cloudEntries
        .where((e) => e.deletedAt == null && aliveMedia.contains(e.mediaId))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final localAlive = localEntries
        .where((e) => aliveMedia.contains(e.mediaId))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final localOnlyAlive = localAlive
        .where((e) => !cloudByMedia.containsKey(e.mediaId) ||
            (cloudByMedia[e.mediaId]!.deletedAt != null &&
                cloudByMedia[e.mediaId]!.deletedAt!
                    .isBefore(e.addedAt)))
        .toList();

    List<_OrderedEntry> finalOrder;
    switch (winner) {
      case _Winner.cloud:
        finalOrder = [
          ...cloudAliveSorted.map(_OrderedEntry.cloud),
          ...localOnlyAlive.map(_OrderedEntry.local),
        ];
      case _Winner.local:
        finalOrder = [
          ...localAlive.map(_OrderedEntry.local),
          ...cloudAliveSorted
              .where((e) => !localByMedia.containsKey(e.mediaId))
              .map(_OrderedEntry.cloud),
        ];
      case _Winner.neutral:
        finalOrder = [
          ...localAlive.map(_OrderedEntry.local),
          ...cloudAliveSorted
              .where((e) => !localByMedia.containsKey(e.mediaId))
              .map(_OrderedEntry.cloud),
        ];
    }

    // Cloud entries that must be applied locally (they are missing locally or
    // the local copy needs cloud ordering).
    final cloudMediaAlive = cloudAliveSorted.map((e) => e.mediaId).toSet();
    final localMedia = localByMedia.keys.toSet();
    if (cloudMediaAlive.difference(localMedia).isNotEmpty) {
      needsLocalApply = true;
    }
    for (final ce in cloudAliveSorted) {
      if (!localByMedia.containsKey(ce.mediaId)) {
        adoptedCloudEntries.add(ce);
      }
    }

    if (winner == _Winner.cloud) needsLocalApply = true;

    // Build the local apply list renumbered 0..N-1.
    final localOrder = <CloudEntryDoc>[];
    for (var i = 0; i < finalOrder.length; i++) {
      final oe = finalOrder[i];
      final mediaId = oe.isCloud ? oe.cloud!.mediaId : oe.local!.mediaId;
      final addedAt = oe.isCloud ? oe.cloud!.addedAt : oe.local!.addedAt;
      final entryId = oe.isCloud ? oe.cloud!.entryId : (oe.local!.syncId ?? '');
      localOrder.add(CloudEntryDoc(
        entryId: entryId,
        playlistSyncId: playlistSyncId,
        mediaId: mediaId,
        position: i,
        addedAt: addedAt.toUtc(),
      ));
    }

    // When local wins, also push the full local ordering so the cloud entry
    // positions converge (executor filters unchanged docs by hash).
    if (winner == _Winner.local) {
      toPush.clear();
      for (var i = 0; i < localAlive.length; i++) {
        final le = localAlive[i];
        toPush.add(CloudEntryDoc(
          entryId: le.syncId ?? '',
          playlistSyncId: playlistSyncId,
          mediaId: le.mediaId,
          position: i,
          addedAt: le.addedAt.toUtc(),
        ));
      }
    }

    return _EntryMergeResult(
      localOrder: localOrder,
      toPush: toPush,
      adoptedCloudEntries: adoptedCloudEntries,
      needsLocalApply: needsLocalApply,
    );
  }
}

enum _Winner { cloud, local, neutral }

class _OrderedEntry {
  final CloudEntryDoc? cloud;
  final LocalEntryData? local;
  const _OrderedEntry.cloud(this.cloud) : local = null;
  const _OrderedEntry.local(this.local) : cloud = null;
  bool get isCloud => cloud != null;
}

class _EntryMergeResult {
  final List<CloudEntryDoc> localOrder;
  final List<CloudEntryDoc> toPush;
  final List<CloudEntryDoc> adoptedCloudEntries;
  final bool needsLocalApply;

  const _EntryMergeResult({
    required this.localOrder,
    required this.toPush,
    required this.adoptedCloudEntries,
    required this.needsLocalApply,
  });
}
