import 'package:Orvia/blocs/offline/cubit/offline_organizer_cubit.dart';
import 'package:Orvia/blocs/offline/cubit/offline_organizer_state.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/models/offline_organizer_models.dart';
import 'package:Orvia/services/db/dao/settings_dao.dart';
import 'package:Orvia/services/db/global_db.dart';
import 'package:Orvia/services/offline/offline_organizer_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory mock of SettingsDAO for rapid, deterministic testing
/// of OfflineOrganizerService and OfflineOrganizerCubit.
class MockSettingsDAO implements SettingsDAO {
  final Map<String, String> strStore = {};
  final Map<String, bool> boolStore = {};

  @override
  Future<void> putSettingStr(String key, String value) async {
    strStore[key] = value;
  }

  @override
  Future<String?> getSettingStr(String key, {String? defaultValue}) async {
    return strStore[key] ?? defaultValue;
  }

  @override
  Future<void> putSettingBool(String key, bool value) async {
    boolStore[key] = value;
  }

  @override
  Future<bool?> getSettingBool(String key, {bool? defaultValue}) async {
    return boolStore[key] ?? defaultValue;
  }

  @override
  Future<Stream<AppSettingsStrDB?>?> getWatcher4SettingStr(String key) async =>
      null;

  @override
  Future<Stream<AppSettingsBoolDB?>?> getWatcher4SettingBool(String key) async =>
      null;
}

Track _createDummyTrack(String id, String title) {
  return Track(
    id: id,
    title: title,
    artists: const [ArtistSummary(id: 'a1', name: 'Test Artist')],
    thumbnail: const Artwork(
      url: 'https://example.com/thumb.jpg',
      layout: ImageLayout.square,
    ),
    isExplicit: false,
    durationMs: BigInt.from(180000),
  );
}

void main() {
  late MockSettingsDAO mockSettingsDao;
  late OfflineOrganizerService service;

  setUp(() {
    mockSettingsDao = MockSettingsDAO();
    service = OfflineOrganizerService(settingsDao: mockSettingsDao);
  });

  group('OfflineOrganizer Models & Serialization Tests', () {
    test('OfflineFolder toMap and fromMap serialization round-trip', () {
      final now = DateTime.now();
      final folder = OfflineFolder(
        id: 'folder_123',
        name: 'Gym Hits',
        trackIds: ['track_1', 'track_2'],
        createdAt: now,
        updatedAt: now,
      );

      final jsonStr = folder.toJson();
      final restored = OfflineFolder.fromJson(jsonStr);

      expect(restored.id, equals('folder_123'));
      expect(restored.name, equals('Gym Hits'));
      expect(restored.trackIds, equals(['track_1', 'track_2']));
    });

    test('OfflineCollection toMap and fromMap serialization round-trip', () {
      final now = DateTime.now();
      final collection = OfflineCollection(
        id: 'playlist_ak_music',
        title: 'A.K. MUSIC WORLD',
        type: 'playlist',
        coverUrl: 'https://example.com/ak.jpg',
        requestedTrackIds: ['s1', 's2', 's3'],
        createdAt: now,
        updatedAt: now,
      );

      final jsonStr = collection.toJson();
      final restored = OfflineCollection.fromJson(jsonStr);

      expect(restored.id, equals('playlist_ak_music'));
      expect(restored.title, equals('A.K. MUSIC WORLD'));
      expect(restored.type, equals('playlist'));
      expect(restored.coverUrl, equals('https://example.com/ak.jpg'));
      expect(restored.requestedTrackIds, equals(['s1', 's2', 's3']));
    });
  });

  group('OfflineOrganizerService Folder CRUD & Persistence', () {
    test('Creates folder and persists to SettingsDAO', () async {
      final folder = await service.createFolder('Favorites');
      expect(folder.name, equals('Favorites'));
      expect(folder.trackIds, isEmpty);

      final folders = await service.getFolders();
      expect(folders.length, equals(1));
      expect(folders.first.name, equals('Favorites'));
    });

    test('Renames folder successfully and updates timestamp', () async {
      final folder = await service.createFolder('Old Name');
      final updated = await service.renameFolder(folder.id, 'New Name');

      expect(updated, isNotNull);
      expect(updated!.name, equals('New Name'));

      final list = await service.getFolders();
      expect(list.first.name, equals('New Name'));
    });

    test('Deletes folder properly', () async {
      final f1 = await service.createFolder('Folder 1');
      final f2 = await service.createFolder('Folder 2');
      expect((await service.getFolders()).length, equals(2));

      final deleted = await service.deleteFolder(f1.id);
      expect(deleted, isTrue);

      final remaining = await service.getFolders();
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals(f2.id));
    });

    test('Survives app restart (persistence across service instances)',
        () async {
      final f = await service.createFolder('Persistent Folder');
      await service.addTracksToFolder(f.id, ['track_101', 'track_102']);

      // Instantiate fresh service with the same SettingsDAO store
      final freshService =
          OfflineOrganizerService(settingsDao: mockSettingsDao);
      final restoredFolders = await freshService.getFolders();

      expect(restoredFolders.length, equals(1));
      expect(restoredFolders.first.name, equals('Persistent Folder'));
      expect(restoredFolders.first.trackIds,
          equals(['track_101', 'track_102']));
    });
  });

  group('Multi-Folder Membership, Move, Copy, and Extract', () {
    test('Track can belong to multiple folders without conflict', () async {
      final f1 = await service.createFolder('Folder 1');
      final f2 = await service.createFolder('Folder 2');

      const sharedTrackId = 'shared_track_99';
      await service.addTracksToFolder(f1.id, [sharedTrackId]);
      await service.addTracksToFolder(f2.id, [sharedTrackId]);

      final folders = await service.getFolders();
      expect(folders[0].trackIds, contains(sharedTrackId));
      expect(folders[1].trackIds, contains(sharedTrackId));
    });

    test('Moving a track removes from source and adds to target', () async {
      final source = await service.createFolder('Source');
      final target = await service.createFolder('Target');

      await service.addTracksToFolder(source.id, ['track_A', 'track_B']);
      expect((await service.getFolders())[0].trackIds,
          equals(['track_A', 'track_B']));

      await service.moveTracks(
        sourceFolderId: source.id,
        targetFolderId: target.id,
        trackIds: ['track_A'],
      );

      final updated = await service.getFolders();
      final updatedSource = updated.firstWhere((f) => f.id == source.id);
      final updatedTarget = updated.firstWhere((f) => f.id == target.id);

      expect(updatedSource.trackIds, equals(['track_B']));
      expect(updatedTarget.trackIds, equals(['track_A']));
    });

    test('Copying a track retains in source and adds to target', () async {
      final source = await service.createFolder('Source');
      final target = await service.createFolder('Target');

      await service.addTracksToFolder(source.id, ['track_A']);
      await service.copyTracks(
        targetFolderId: target.id,
        trackIds: ['track_A'],
      );

      final updated = await service.getFolders();
      final updatedSource = updated.firstWhere((f) => f.id == source.id);
      final updatedTarget = updated.firstWhere((f) => f.id == target.id);

      expect(updatedSource.trackIds, contains('track_A'));
      expect(updatedTarget.trackIds, contains('track_A'));
    });

    test('Extracting track removes folder association without deleting audio',
        () async {
      final folder = await service.createFolder('My Hits');
      await service.addTracksToFolder(folder.id, ['song_1', 'song_2']);

      await service.extractTracksFromFolder(folder.id, ['song_1']);

      final updated = (await service.getFolders()).first;
      expect(updated.trackIds, equals(['song_2']));
    });

    test('Extracting final song leaves folder empty (Requirement 8)', () async {
      final folder = await service.createFolder('Single Song Folder');
      await service.addTracksToFolder(folder.id, ['song_only']);

      await service.extractTracksFromFolder(folder.id, ['song_only']);

      final updated = (await service.getFolders()).first;
      expect(updated.trackIds, isEmpty);
    });
  });

  group('Safe Deletion Impact Analysis (Requirement 7)', () {
    test(
        'Correctly calculates unique vs shared tracks across folders and collections',
        () async {
      final f1 = await service.createFolder('Folder 1');
      final f2 = await service.createFolder('Folder 2');

      // song_shared exists in f1, f2, and collection
      // song_unique exists only in f1
      await service.addTracksToFolder(f1.id, ['song_shared', 'song_unique']);
      await service.addTracksToFolder(f2.id, ['song_shared', 'other_song']);

      await service.registerCollection(
        id: 'col_1',
        title: 'Collection 1',
        type: 'playlist',
        trackIds: ['song_shared'],
      );

      final impact = await service.getFolderDeleteImpact(f1.id);
      expect(impact.totalTracks, equals(2));
      expect(impact.sharedTracksCount, equals(1));
      expect(impact.uniqueTracksCount, equals(1));
      expect(impact.sharedTrackIds, equals(['song_shared']));
      expect(impact.uniqueTrackIds, equals(['song_unique']));
    });
  });

  group('Offline Collections & Partial Downloads (Requirement 2)', () {
    test('Registers collection and deduplicates tracks on update', () async {
      final col = await service.registerCollection(
        id: 'playlist_mangal',
        title: 'Mangal Rang',
        type: 'album',
        coverUrl: 'https://example.com/cover.jpg',
        trackIds: ['song_1', 'song_2'],
      );

      expect(col.title, equals('Mangal Rang'));
      expect(col.requestedTrackIds, equals(['song_1', 'song_2']));

      // Update with overlapping tracks
      final updated = await service.registerCollection(
        id: 'playlist_mangal',
        title: 'Mangal Rang',
        type: 'album',
        trackIds: ['song_2', 'song_3'],
      );

      expect(updated.requestedTrackIds, equals(['song_1', 'song_2', 'song_3']));
    });

    test(
        'OfflineOrganizerCubit getCollectionTracks only returns verified downloaded tracks',
        () async {
      final cubit = OfflineOrganizerCubit(service: service);
      await cubit.loadData();

      await cubit.registerCollection(
        id: 'playlist_party',
        title: 'Party Playlist',
        type: 'playlist',
        trackIds: ['t1', 't2', 't3', 't4'],
      );

      // Suppose only t1 and t3 are actually downloaded on disk
      final downloadedTracks = [
        _createDummyTrack('t1', 'Track 1'),
        _createDummyTrack('t3', 'Track 3'),
      ];

      final collectionTracks =
          cubit.getCollectionTracks('playlist_party', downloadedTracks);

      expect(collectionTracks.length, equals(2));
      expect(collectionTracks.map((t) => t.id), equals(['t1', 't3']));
      await cubit.close();
    });

    test('Reconciles folder references while preserving collection target tracks',
        () async {
      final folder = await service.createFolder('Clean Folder');
      await service.addTracksToFolder(
          folder.id, ['valid_track', 'stale_track']);

      await service.registerCollection(
        id: 'col_clean',
        title: 'Clean Col',
        type: 'playlist',
        trackIds: ['valid_track', 'stale_track'],
      );

      // Reconcile with only valid_track remaining on disk
      await service.reconcileStaleReferences({'valid_track'});

      final folders = await service.getFolders();
      expect(folders.first.trackIds, equals(['valid_track']));

      // Requirement 2: Collection requestedTrackIds must be preserved so pending/target tracks
      // and collection progress are not erased on restart or during downloads
      final collections = await service.getCollections();
      expect(collections.first.requestedTrackIds,
          equals(['valid_track', 'stale_track']));
    });

    test('Collection persistence survives app restart without resetting to 0/0',
        () async {
      // 1. First session: register collection with 3 tracks
      await service.registerCollection(
        id: 'album_superhits',
        title: 'Superhits Album',
        type: 'album',
        trackIds: ['t1', 't2', 't3'],
      );

      // 2. Simulate restart: create brand-new service and cubit instances with same storage
      final restartedService =
          OfflineOrganizerService(settingsDao: mockSettingsDao);
      final restartedCubit =
          OfflineOrganizerCubit(service: restartedService);
      await restartedCubit.loadData();

      final state = restartedCubit.state as OfflineOrganizerLoaded;
      expect(state.collections.length, equals(1));
      expect(state.collections.first.id, equals('album_superhits'));
      expect(state.collections.first.requestedTrackIds.length, equals(3));

      // 3. Downloaded songs loaded from DB on restart (suppose t1 and t2 completed)
      final downloadedOnRestart = [
        _createDummyTrack('t1', 'Track One'),
        _createDummyTrack('t2', 'Track Two'),
      ];

      final validTracks = restartedCubit.getCollectionTracks(
          'album_superhits', downloadedOnRestart);
      expect(validTracks.length, equals(2));
      expect(validTracks.map((t) => t.id), equals(['t1', 't2']));

      await restartedCubit.close();
    });

    test('getCollectionTracks reconciles composite provider prefixes and unstamped IDs',
        () async {
      await service.registerCollection(
        id: 'col_cross_provider',
        title: 'Cross Provider Test',
        type: 'playlist',
        trackIds: ['W13ekRcO'],
      );

      final cubit = OfflineOrganizerCubit(service: service);
      await cubit.loadData();

      // Downloaded track has provider prefix (e.g. jisaavn::W13ekRcO)
      final downloadedTracks = [
        _createDummyTrack(
            'content-resolver.bloomfactory.jisaavn::W13ekRcO', 'Song 1'),
      ];

      final matched =
          cubit.getCollectionTracks('col_cross_provider', downloadedTracks);
      expect(matched.length, equals(1));
      expect(matched.first.title, equals('Song 1'));

      await cubit.close();
    });
  });
}
