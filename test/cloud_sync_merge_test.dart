// Unit tests for the pure cloud-sync merge engine.
//
// Run with: flutter test test/cloud_sync_merge_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:Orvia/services/cloud_sync/merge_engine.dart';
import 'package:Orvia/services/cloud_sync/sync_config.dart';
import 'package:Orvia/services/cloud_sync/sync_models.dart';
import 'package:Orvia/services/cloud_sync/sync_record_kind.dart';

DateTime utc(int year, int month, int day, [int h = 0, int m = 0]) =>
    DateTime.utc(year, month, day, h, m);

CloudPlaylistDoc cloudPlaylist(
  String syncId,
  String name, {
  DateTime? updatedAt,
  DateTime? createdAt,
  DateTime? deletedAt,
  bool isPinned = false,
  int sortOrder = 0,
}) =>
    CloudPlaylistDoc(
      syncId: syncId,
      name: name,
      isPinned: isPinned,
      sortOrder: sortOrder,
      createdAt: createdAt ?? utc(2026, 1, 1),
      updatedAt: updatedAt ?? utc(2026, 1, 2),
      deletedAt: deletedAt,
    );

CloudEntryDoc cloudEntry(
  String entryId,
  String playlistSyncId,
  String mediaId,
  int position, {
  DateTime? addedAt,
  DateTime? deletedAt,
}) =>
    CloudEntryDoc(
      entryId: entryId,
      playlistSyncId: playlistSyncId,
      mediaId: mediaId,
      position: position,
      addedAt: addedAt ?? utc(2026, 1, 2),
      deletedAt: deletedAt,
    );

LocalPlaylistData localPlaylist(
  int localId,
  String name, {
  String? syncId,
  DateTime? updatedAt,
  List<LocalEntryData> entries = const [],
  bool isPinned = false,
  int sortOrder = 0,
}) =>
    LocalPlaylistData(
      localId: localId,
      name: name,
      syncId: syncId,
      isPinned: isPinned,
      sortOrder: sortOrder,
      createdAt: utc(2026, 1, 1),
      updatedAt: updatedAt ?? utc(2026, 1, 2),
      entries: entries,
    );

LocalEntryData localEntry(
  int localId,
  String mediaId,
  int position, {
  String? syncId,
  DateTime? addedAt,
}) =>
    LocalEntryData(
      localId: localId,
      mediaId: mediaId,
      position: position,
      addedAt: addedAt ?? utc(2026, 1, 2),
      syncId: syncId,
    );

const uid = 'user-A';

void main() {
  test('schema version newer than supported yields schemaTooNew and no ops',
      () {
    final plan = MergeEngine.merge(
      cloud: CloudSnapshot(
        schemaVersion: kCloudSyncSchemaVersion + 1,
        playlists: [cloudPlaylist('p1', 'X')],
        entries: [],
        favourites: [],
        settings: [],
      ),
      local: const LocalSnapshot(playlists: [], favourites: [], settings: []),
      localDeletions: [],
      adoptedByOtherUids: {},
      uid: uid,
    );

    expect(plan.schemaTooNew, isTrue);
    expect(plan.localMutations, isEmpty);
    expect(plan.cloudMutations, isEmpty);
  });

  test('empty cloud + guest playlist with syncId → playlist is pushed', () {
    final plan = MergeEngine.merge(
      cloud: const CloudSnapshot(
        schemaVersion: kCloudSyncSchemaVersion,
        playlists: [],
        entries: [],
        favourites: [],
        settings: [],
      ),
      local: LocalSnapshot(
        playlists: [
          localPlaylist(1, 'My Mix', syncId: 's-1', entries: [
            localEntry(10, 'saavn::1', 0, syncId: 'e-1'),
            localEntry(11, 'saavn::2', 1, syncId: 'e-2'),
          ]),
        ],
        favourites: [],
        settings: [],
      ),
      localDeletions: [],
      adoptedByOtherUids: {},
      uid: uid,
    );

    final playlistPushes =
        plan.cloudMutations.whereType<PutPlaylistCloud>().toList();
    expect(playlistPushes, hasLength(1));
    expect(playlistPushes.first.playlist.syncId, equals('s-1'));
    expect(playlistPushes.first.playlist.name, equals('My Mix'));

    final entryPushes =
        plan.cloudMutations.whereType<PutEntriesCloud>().toList();
    expect(entryPushes, hasLength(1));
    expect(entryPushes.first.playlistSyncId, equals('s-1'));
    expect(entryPushes.first.entries.map((e) => e.mediaId),
        unorderedEquals(['saavn::1', 'saavn::2']));

    // Every pushed record is adopted by the signing-in account.
    expect(
      plan.adoptions.any((a) =>
          a.recordKey == 's-1' &&
          a.kind == SyncRecordKind.playlist &&
          a.uid == uid),
      isTrue,
    );
  });

  test('cloud-only playlist is downloaded locally with entries and adoptions',
      () {
    final plan = MergeEngine.merge(
      cloud: CloudSnapshot(
        schemaVersion: kCloudSyncSchemaVersion,
        playlists: [cloudPlaylist('s-1', 'From Phone')],
        entries: [
          cloudEntry('e-1', 's-1', 'saavn::9', 0),
          cloudEntry('e-2', 's-1', 'saavn::8', 1),
        ],
        favourites: [],
        settings: [],
      ),
      local: const LocalSnapshot(playlists: [], favourites: [], settings: []),
      localDeletions: [],
      adoptedByOtherUids: {},
      uid: uid,
    );

    final ups = plan.localMutations.whereType<UpsertPlaylistLocal>().toList();
    expect(ups, hasLength(1));
    expect(ups.first.playlist.name, equals('From Phone'));
    expect(ups.first.entries.map((e) => e.mediaId).toList(),
        orderedEquals(['saavn::9', 'saavn::8']));
    expect(ups.first.entries.map((e) => e.position).toList(),
        orderedEquals([0, 1]));

    expect(plan.cloudMutations, isEmpty);
    expect(plan.adoptions.where((a) => a.kind == SyncRecordKind.entry),
        hasLength(2));
  });

  test('cloud playlist matched by name adopts the local record (no duplicate)',
      () {
    final plan = MergeEngine.merge(
      cloud: CloudSnapshot(
        schemaVersion: kCloudSyncSchemaVersion,
        playlists: [cloudPlaylist('s-cloud', 'Road Trip')],
        entries: [cloudEntry('e-1', 's-cloud', 'saavn::1', 0)],
        favourites: [],
        settings: [],
      ),
      local: LocalSnapshot(
        playlists: [
          localPlaylist(1, 'Road Trip', entries: [
            localEntry(10, 'saavn::2', 0, syncId: 'e-local'),
          ]),
        ],
        favourites: [],
        settings: [],
      ),
      localDeletions: [],
      adoptedByOtherUids: {},
      uid: uid,
    );

    // The guest playlist is merged with the cloud record: cloud entry added
    // locally, local-only entry pushed to the cloud — no duplicate playlist.
    final ups = plan.localMutations.whereType<UpsertPlaylistLocal>().toList();
    expect(ups, hasLength(1));
    final localOrderMedia = ups.first.entries.map((e) => e.mediaId).toSet();
    expect(localOrderMedia, containsAll(['saavn::1', 'saavn::2']));

    final pushes = plan.cloudMutations.whereType<PutEntriesCloud>().toList();
    final pushedMedia = pushes.expand((p) => p.entries.map((e) => e.mediaId));
    expect(pushedMedia, contains('saavn::2'));
    expect(plan.cloudMutations.whereType<PutPlaylistCloud>(), isEmpty,
        reason: 'metadata timestamps equal → no metadata push');
  });

  test('local-only playlist adopted by another account is NOT pushed (holdback)',
      () {
    final plan = MergeEngine.merge(
      cloud: const CloudSnapshot(
        schemaVersion: kCloudSyncSchemaVersion,
        playlists: [],
        entries: [],
        favourites: [],
        settings: [],
      ),
      local: LocalSnapshot(
        playlists: [
          localPlaylist(1, 'From Account A', syncId: 's-a'),
        ],
        favourites: [],
        settings: [],
      ),
      localDeletions: [],
      adoptedByOtherUids: {'playlist:s-a'},
      uid: 'user-B',
    );

    expect(plan.cloudMutations, isEmpty);
  });

  test('playlist deletion tombstone wins over stale local copy', () {
    final deletedAt = utc(2026, 5, 1);
    final plan = MergeEngine.merge(
      cloud: CloudSnapshot(
        schemaVersion: kCloudSyncSchemaVersion,
        playlists: [
          cloudPlaylist('s-1', 'Gone', deletedAt: deletedAt,
              updatedAt: deletedAt),
        ],
        entries: [],
        favourites: [],
        settings: [],
      ),
      local: LocalSnapshot(
        playlists: [
          localPlaylist(1, 'Gone', syncId: 's-1', updatedAt: utc(2026, 1, 2)),
        ],
        favourites: [],
        settings: [],
      ),
      localDeletions: [],
      adoptedByOtherUids: {},
      uid: uid,
    );

    final dels = plan.localMutations.whereType<DeletePlaylistLocal>().toList();
    expect(dels, hasLength(1));
    expect(dels.first.localId, equals(1));
    expect(plan.cloudMutations, isEmpty);
  });

  test('local edit after cloud deletion resurrects the playlist', () {
    final deletedAt = utc(2026, 5, 1);
    final plan = MergeEngine.merge(
      cloud: CloudSnapshot(
        schemaVersion: kCloudSyncSchemaVersion,
        playlists: [
          cloudPlaylist('s-1', 'Gone',
              deletedAt: deletedAt, updatedAt: deletedAt),
        ],
        entries: [],
        favourites: [],
        settings: [],
      ),
      local: LocalSnapshot(
        playlists: [
          localPlaylist(1, 'Gone Renamed',
              syncId: 's-1', updatedAt: utc(2026, 6, 1)),
        ],
        favourites: [],
        settings: [],
      ),
      localDeletions: [],
      adoptedByOtherUids: {},
      uid: uid,
    );

    final pushes = plan.cloudMutations.whereType<PutPlaylistCloud>().toList();
    expect(pushes, hasLength(1));
    expect(pushes.first.playlist.deletedAt, isNull,
        reason: 'resurrection pushes a live doc');
    expect(pushes.first.playlist.name, equals('Gone Renamed'));
    expect(plan.localMutations, isEmpty);
  });

  test('locally deleted synced playlist pushes a tombstone instead of '
      're-downloading', () {
    final plan = MergeEngine.merge(
      cloud: CloudSnapshot(
        schemaVersion: kCloudSyncSchemaVersion,
        playlists: [
          cloudPlaylist('s-1', 'To Delete', updatedAt: utc(2026, 1, 2)),
        ],
        entries: [cloudEntry('e-1', 's-1', 'saavn::1', 0)],
        favourites: [],
        settings: [],
      ),
      local: const LocalSnapshot(playlists: [], favourites: [], settings: []),
      localDeletions: [
        LocalDeletion(
            kind: SyncRecordKind.playlist,
            cloudId: 's-1',
            deletedAt: utc(2026, 7, 1)),
      ],
      adoptedByOtherUids: {},
      uid: uid,
    );

    final pushes = plan.cloudMutations.whereType<PutPlaylistCloud>().toList();
    expect(pushes, hasLength(1));
    expect(pushes.first.playlist.deletedAt, isNotNull);
    expect(plan.localMutations.whereType<UpsertPlaylistLocal>(), isEmpty,
        reason: 'must not resurrect a playlist the user deleted');
  });

  test('cloud edit newer than local deletion re-downloads (least destructive)',
      () {
    final plan = MergeEngine.merge(
      cloud: CloudSnapshot(
        schemaVersion: kCloudSyncSchemaVersion,
        playlists: [
          cloudPlaylist('s-1', 'Edited Elsewhere', updatedAt: utc(2026, 8, 1)),
        ],
        entries: [cloudEntry('e-1', 's-1', 'saavn::1', 0)],
        favourites: [],
        settings: [],
      ),
      local: const LocalSnapshot(playlists: [], favourites: [], settings: []),
      localDeletions: [
        LocalDeletion(
            kind: SyncRecordKind.playlist,
            cloudId: 's-1',
            deletedAt: utc(2026, 7, 1)),
      ],
      adoptedByOtherUids: {},
      uid: uid,
    );

    expect(plan.localMutations.whereType<UpsertPlaylistLocal>(), hasLength(1));
    expect(plan.cloudMutations, isEmpty);
  });

  test('cloud newer metadata applied locally; older local edits not pushed',
      () {
    final plan = MergeEngine.merge(
      cloud: CloudSnapshot(
        schemaVersion: kCloudSyncSchemaVersion,
        playlists: [
          cloudPlaylist('s-1', 'Renamed On Phone', updatedAt: utc(2026, 9, 1)),
        ],
        entries: [],
        favourites: [],
        settings: [],
      ),
      local: LocalSnapshot(
        playlists: [
          localPlaylist(1, 'Old Name', syncId: 's-1', updatedAt: utc(2026, 2, 1)),
        ],
        favourites: [],
        settings: [],
      ),
      localDeletions: [],
      adoptedByOtherUids: {},
      uid: uid,
    );

    final ups = plan.localMutations.whereType<UpsertPlaylistLocal>().toList();
    expect(ups, hasLength(1));
    expect(ups.first.playlist.name, equals('Renamed On Phone'));
    expect(plan.cloudMutations.whereType<PutPlaylistCloud>(), isEmpty);
  });

  test('entry deletion on another device removes it locally (tombstone newer)',
      () {
    final deletedAt = utc(2026, 6, 1);
    final plan = MergeEngine.merge(
      cloud: CloudSnapshot(
        schemaVersion: kCloudSyncSchemaVersion,
        playlists: [cloudPlaylist('s-1', 'Mix', updatedAt: utc(2026, 6, 1))],
        entries: [
          cloudEntry('e-1', 's-1', 'saavn::1', 0, deletedAt: deletedAt),
        ],
        favourites: [],
        settings: [],
      ),
      local: LocalSnapshot(
        playlists: [
          localPlaylist(1, 'Mix', syncId: 's-1', updatedAt: utc(2026, 2, 1),
              entries: [
            localEntry(10, 'saavn::1', 0, syncId: 'e-1',
                addedAt: utc(2026, 2, 2)),
          ]),
        ],
        favourites: [],
        settings: []),
      localDeletions: [],
      adoptedByOtherUids: {},
      uid: uid,
    );

    final ups = plan.localMutations.whereType<UpsertPlaylistLocal>().toList();
    expect(ups, hasLength(1));
    expect(ups.first.entries.where((e) => e.mediaId == 'saavn::1'), isEmpty,
        reason: 'entry tombstoned in cloud and newer than local addedAt');
  });

  test('local re-add after cloud tombstone resurrects the entry', () {
    final deletedAt = utc(2026, 6, 1);
    final plan = MergeEngine.merge(
      cloud: CloudSnapshot(
        schemaVersion: kCloudSyncSchemaVersion,
        playlists: [cloudPlaylist('s-1', 'Mix', updatedAt: utc(2026, 6, 1))],
        entries: [
          cloudEntry('e-1', 's-1', 'saavn::1', 0, deletedAt: deletedAt),
        ],
        favourites: [],
        settings: [],
      ),
      local: LocalSnapshot(
        playlists: [
          localPlaylist(1, 'Mix', syncId: 's-1', updatedAt: utc(2026, 7, 1),
              entries: [
            localEntry(10, 'saavn::1', 0, syncId: 'e-1',
                addedAt: utc(2026, 6, 15)),
          ]),
        ],
        favourites: [],
        settings: []),
      localDeletions: [],
      adoptedByOtherUids: {},
      uid: uid,
    );

    final pushes = plan.cloudMutations.whereType<PutEntriesCloud>().toList();
    final pushedLive = pushes
        .expand((p) => p.entries)
        .where((e) => e.mediaId == 'saavn::1' && e.deletedAt == null);
    expect(pushedLive, isNotEmpty, reason: 're-add is newer than tombstone');
  });

  test('locally removed synced entry pushes a tombstone', () {
    final plan = MergeEngine.merge(
      cloud: CloudSnapshot(
        schemaVersion: kCloudSyncSchemaVersion,
        playlists: [cloudPlaylist('s-1', 'Mix', updatedAt: utc(2026, 2, 1))],
        entries: [
          cloudEntry('e-1', 's-1', 'saavn::1', 0),
        ],
        favourites: [],
        settings: [],
      ),
      local: LocalSnapshot(
        playlists: [
          localPlaylist(1, 'Mix', syncId: 's-1', updatedAt: utc(2026, 2, 1)),
        ],
        favourites: [],
        settings: [],
      ),
      localDeletions: [
        LocalDeletion(
            kind: SyncRecordKind.entry, cloudId: 'e-1', deletedAt: utc(2026, 7, 2)),
      ],
      adoptedByOtherUids: {},
      uid: uid,
    );

    final pushes = plan.cloudMutations.whereType<PutEntriesCloud>().toList();
    final tombstones =
        pushes.expand((p) => p.entries).where((e) => e.deletedAt != null);
    expect(tombstones.map((t) => t.entryId), contains('e-1'));
  });

  test('favourites: cloud favourite downloaded, cloud tombstone unlikes, '
      'local new favourite pushes', () {
    final plan = MergeEngine.merge(
      cloud: CloudSnapshot(
        schemaVersion: kCloudSyncSchemaVersion,
        playlists: [],
        entries: [],
        favourites: [
          CloudFavouriteDoc(mediaId: 'saavn::keep', addedAt: utc(2026, 1, 1)),
          CloudFavouriteDoc(
              mediaId: 'saavn::removed',
              addedAt: utc(2026, 1, 1),
              deletedAt: utc(2026, 3, 1)),
        ],
        settings: [],
      ),
      local: LocalSnapshot(
        playlists: [],
        favourites: [
          LocalFavouriteData(mediaId: 'saavn::mine', addedAt: utc(2026, 2, 1)),
          LocalFavouriteData(
              mediaId: 'saavn::removed', addedAt: utc(2026, 1, 1)),
        ],
        settings: [],
      ),
      localDeletions: [],
      adoptedByOtherUids: {},
      uid: uid,
    );

    final likes = plan.localMutations.whereType<LikeLocal>().toList();
    expect(likes.map((l) => l.mediaId), contains('saavn::keep'));

    final unlikes = plan.localMutations.whereType<UnlikeLocal>().toList();
    expect(unlikes.map((l) => l.mediaId), contains('saavn::removed'));

    final pushes = plan.cloudMutations.whereType<PutFavouriteCloud>().toList();
    expect(pushes.map((p) => p.favourite.mediaId), contains('saavn::mine'));
  });

  test('favourite deletion propagates as tombstone', () {
    final plan = MergeEngine.merge(
      cloud: CloudSnapshot(
        schemaVersion: kCloudSyncSchemaVersion,
        playlists: [],
        entries: [],
        favourites: [
          CloudFavouriteDoc(mediaId: 'saavn::1', addedAt: utc(2026, 1, 1)),
        ],
        settings: [],
      ),
      local: const LocalSnapshot(playlists: [], favourites: [], settings: []),
      localDeletions: [
        LocalDeletion(
            kind: SyncRecordKind.favourite,
            cloudId: 'saavn::1',
            deletedAt: utc(2026, 7, 1)),
      ],
      adoptedByOtherUids: {},
      uid: uid,
    );

    final pushes = plan.cloudMutations.whereType<PutFavouriteCloud>().toList();
    expect(pushes, hasLength(1));
    expect(pushes.first.favourite.deletedAt, isNotNull);
    expect(plan.localMutations, isEmpty);
  });

  test('settings: newer local value pushes, newer cloud value applies, '
      'non-whitelisted keys ignored', () {
    final plan = MergeEngine.merge(
      cloud: CloudSnapshot(
        schemaVersion: kCloudSyncSchemaVersion,
        playlists: [],
        entries: [],
        favourites: [],
        settings: [
          CloudSettingDoc(
              key: 'streamQuality', value: 'Low', updatedAt: utc(2026, 5, 1)),
          CloudSettingDoc(
              key: 'downloadPath', value: '/device/path',
              updatedAt: utc(2026, 5, 1)),
        ],
      ),
      local: LocalSnapshot(
        playlists: [],
        favourites: [],
        settings: [
          LocalSettingData(
              key: 'eqEnabled', value: 'true', updatedAt: utc(2026, 5, 1)),
          LocalSettingData(
              key: 'streamQuality', value: 'High', updatedAt: utc(2026, 2, 1)),
          LocalSettingData(
              key: 'downloadPath', value: '/mine', updatedAt: utc(2026, 9, 9)),
        ],
      ),
      localDeletions: [],
      adoptedByOtherUids: {},
      uid: uid,
    );

    final applies = plan.localMutations.whereType<ApplySettingLocal>().toList();
    expect(applies.map((a) => a.key), contains('streamQuality'));
    expect(applies.map((a) => a.key), isNot(contains('downloadPath')));

    final pushes = plan.cloudMutations.whereType<PutSettingCloud>().toList();
    expect(pushes.map((p) => p.setting.key), contains('eqEnabled'));
    expect(pushes.map((p) => p.setting.key), isNot(contains('downloadPath')),
        reason: 'device paths must never be synced');
  });

  test('account switch: A-adopted settings are held back from B', () {
    final plan = MergeEngine.merge(
      cloud: const CloudSnapshot(
        schemaVersion: kCloudSyncSchemaVersion,
        playlists: [],
        entries: [],
        favourites: [],
        settings: [],
      ),
      local: LocalSnapshot(
        playlists: [],
        favourites: [],
        settings: [
          LocalSettingData(
              key: 'countryCode', value: 'IN', updatedAt: utc(2026, 5, 1)),
        ],
      ),
      localDeletions: [],
      adoptedByOtherUids: {'setting:countryCode'},
      uid: 'user-B',
    );

    expect(plan.cloudMutations.whereType<PutSettingCloud>(), isEmpty,
        reason: 'record adopted from account A must not leak into B');
  });
}
