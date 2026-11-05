import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;

import 'package:Orvia/core/constants/setting_keys.dart';
import 'package:Orvia/core/models/offline_organizer_models.dart';
import 'package:Orvia/services/db/dao/settings_dao.dart';

/// Service managing offline custom folders and downloaded collection tracking.
class OfflineOrganizerService {
  final SettingsDAO _settingsDao;

  OfflineOrganizerService({required SettingsDAO settingsDao})
      : _settingsDao = settingsDao;

  // ── Folders Management ───────────────────────────────────────────────────

  /// Retrieve all user-created offline folders.
  Future<List<OfflineFolder>> getFolders() async {
    try {
      final jsonStr =
          await _settingsDao.getSettingStr(SettingKeys.offlineFolders);
      if (jsonStr == null || jsonStr.trim().isEmpty) {
        return <OfflineFolder>[];
      }
      final decoded = json.decode(jsonStr);
      if (decoded is List) {
        return decoded
            .map((item) =>
                OfflineFolder.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (e, stack) {
      log('Error reading offline folders: $e',
          name: 'OfflineOrganizerService', error: e, stackTrace: stack);
    }
    return <OfflineFolder>[];
  }

  /// Persist the list of offline folders.
  Future<void> _saveFolders(List<OfflineFolder> folders) async {
    final list = folders.map((f) => f.toMap()).toList();
    await _settingsDao.putSettingStr(
        SettingKeys.offlineFolders, json.encode(list));
  }

  /// Create a new folder with given name.
  Future<OfflineFolder> createFolder(String name) async {
    final folders = await getFolders();
    final trimmedName = name.trim().isEmpty ? 'New Folder' : name.trim();
    final id =
        'folder_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(10000)}';
    final now = DateTime.now();

    final newFolder = OfflineFolder(
      id: id,
      name: trimmedName,
      trackIds: <String>[],
      createdAt: now,
      updatedAt: now,
    );

    folders.add(newFolder);
    await _saveFolders(folders);
    return newFolder;
  }

  /// Rename an existing folder.
  Future<OfflineFolder?> renameFolder(String folderId, String newName) async {
    final folders = await getFolders();
    final index = folders.indexWhere((f) => f.id == folderId);
    if (index == -1) return null;

    final updated = folders[index].copyWith(
      name: newName.trim().isEmpty ? folders[index].name : newName.trim(),
      updatedAt: DateTime.now(),
    );
    folders[index] = updated;
    await _saveFolders(folders);
    return updated;
  }

  /// Calculates the deletion impact of a folder before deletion.
  /// Identifies which tracks are safe because they exist in other folders or collections.
  Future<FolderDeleteImpact> getFolderDeleteImpact(String folderId) async {
    final folders = await getFolders();
    final collections = await getCollections();

    final targetFolder = folders.firstWhere(
      (f) => f.id == folderId,
      orElse: () => OfflineFolder(
        id: '',
        name: '',
        trackIds: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    if (targetFolder.id.isEmpty) {
      return const FolderDeleteImpact(
        totalTracks: 0,
        sharedTracksCount: 0,
        uniqueTracksCount: 0,
        uniqueTrackIds: [],
        sharedTrackIds: [],
      );
    }

    final otherTrackIds = <String>{};
    for (final f in folders) {
      if (f.id != folderId) {
        otherTrackIds.addAll(f.trackIds);
      }
    }
    for (final c in collections) {
      otherTrackIds.addAll(c.requestedTrackIds);
    }

    final sharedTrackIds = <String>[];
    final uniqueTrackIds = <String>[];

    for (final tid in targetFolder.trackIds) {
      if (otherTrackIds.contains(tid)) {
        sharedTrackIds.add(tid);
      } else {
        uniqueTrackIds.add(tid);
      }
    }

    return FolderDeleteImpact(
      totalTracks: targetFolder.trackIds.length,
      sharedTracksCount: sharedTrackIds.length,
      uniqueTracksCount: uniqueTrackIds.length,
      uniqueTrackIds: uniqueTrackIds,
      sharedTrackIds: sharedTrackIds,
    );
  }

  /// Delete a folder.
  Future<bool> deleteFolder(String folderId) async {
    final folders = await getFolders();
    final initialCount = folders.length;
    folders.removeWhere((f) => f.id == folderId);
    if (folders.length != initialCount) {
      await _saveFolders(folders);
      return true;
    }
    return false;
  }

  /// Add tracks to a folder (preventing duplicate entries within the folder).
  Future<bool> addTracksToFolder(
      String folderId, List<String> newTrackIds) async {
    if (newTrackIds.isEmpty) return false;
    final folders = await getFolders();
    final index = folders.indexWhere((f) => f.id == folderId);
    if (index == -1) return false;

    final current = folders[index];
    final updatedList = List<String>.from(current.trackIds);
    bool changed = false;

    for (final tid in newTrackIds) {
      if (!updatedList.contains(tid)) {
        updatedList.add(tid);
        changed = true;
      }
    }

    if (changed) {
      folders[index] = current.copyWith(
        trackIds: updatedList,
        updatedAt: DateTime.now(),
      );
      await _saveFolders(folders);
      return true;
    }
    return false;
  }

  /// Remove tracks from a folder.
  Future<bool> removeTracksFromFolder(
      String folderId, List<String> trackIdsToRemove) async {
    if (trackIdsToRemove.isEmpty) return false;
    final folders = await getFolders();
    final index = folders.indexWhere((f) => f.id == folderId);
    if (index == -1) return false;

    final current = folders[index];
    final updatedList = List<String>.from(current.trackIds)
      ..removeWhere((id) => trackIdsToRemove.contains(id));

    if (updatedList.length != current.trackIds.length) {
      folders[index] = current.copyWith(
        trackIds: updatedList,
        updatedAt: DateTime.now(),
      );
      await _saveFolders(folders);
      return true;
    }
    return false;
  }

  /// Move tracks from one folder to another.
  Future<bool> moveTracks({
    required String sourceFolderId,
    required String targetFolderId,
    required List<String> trackIds,
  }) async {
    if (trackIds.isEmpty || sourceFolderId == targetFolderId) return false;
    final removed = await removeTracksFromFolder(sourceFolderId, trackIds);
    final added = await addTracksToFolder(targetFolderId, trackIds);
    return removed || added;
  }

  /// Copy tracks to a target folder.
  Future<bool> copyTracks({
    required String targetFolderId,
    required List<String> trackIds,
  }) async {
    return addTracksToFolder(targetFolderId, trackIds);
  }

  /// Extract tracks out of a folder (removes from folder without deleting audio file).
  Future<bool> extractTracksFromFolder(
      String folderId, List<String> trackIds) async {
    return removeTracksFromFolder(folderId, trackIds);
  }

  // ── Collections Management ───────────────────────────────────────────────

  /// Retrieve all offline-saved collections.
  Future<List<OfflineCollection>> getCollections() async {
    try {
      final jsonStr =
          await _settingsDao.getSettingStr(SettingKeys.offlineCollections);
      if (jsonStr == null || jsonStr.trim().isEmpty) {
        return <OfflineCollection>[];
      }
      final decoded = json.decode(jsonStr);
      if (decoded is List) {
        return decoded
            .map((item) => OfflineCollection.fromMap(
                Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (e, stack) {
      log('Error reading offline collections: $e',
          name: 'OfflineOrganizerService', error: e, stackTrace: stack);
    }
    return <OfflineCollection>[];
  }

  /// Persist the list of offline collections.
  Future<void> _saveCollections(List<OfflineCollection> collections) async {
    final list = collections.map((c) => c.toMap()).toList();
    await _settingsDao.putSettingStr(
        SettingKeys.offlineCollections, json.encode(list));
  }

  /// Register or update an offline collection from a downloaded playlist or album.
  Future<OfflineCollection> registerCollection({
    required String id,
    required String title,
    required String type,
    String? coverUrl,
    required List<String> trackIds,
  }) async {
    final collections = await getCollections();
    final index = collections.indexWhere((c) => c.id == id);
    final now = DateTime.now();

    if (index >= 0) {
      final existing = collections[index];
      final mergedTracks = List<String>.from(existing.requestedTrackIds);
      for (final tid in trackIds) {
        if (!mergedTracks.contains(tid)) {
          mergedTracks.add(tid);
        }
      }
      final updated = existing.copyWith(
        title: title.isNotEmpty ? title : existing.title,
        coverUrl: coverUrl ?? existing.coverUrl,
        requestedTrackIds: mergedTracks,
        updatedAt: now,
      );
      collections[index] = updated;
      await _saveCollections(collections);
      return updated;
    } else {
      final newCol = OfflineCollection(
        id: id,
        title: title,
        type: type,
        coverUrl: coverUrl,
        requestedTrackIds: trackIds,
        createdAt: now,
        updatedAt: now,
      );
      collections.insert(0, newCol);
      await _saveCollections(collections);
      return newCol;
    }
  }

  /// Delete an offline collection reference.
  Future<bool> deleteCollection(String collectionId) async {
    final collections = await getCollections();
    final initial = collections.length;
    collections.removeWhere((c) => c.id == collectionId);
    if (collections.length != initial) {
      await _saveCollections(collections);
      return true;
    }
    return false;
  }

  /// Reconcile stale track IDs across all folders.
  /// Note: Collection requestedTrackIds are preserved so download progress
  /// and target track membership survive app restarts and partial downloads.
  Future<void> reconcileStaleReferences(
      Set<String> validDownloadedMediaIds) async {
    try {
      final folders = await getFolders();
      bool foldersModified = false;
      for (int i = 0; i < folders.length; i++) {
        final f = folders[i];
        final filtered = f.trackIds
            .where((id) => validDownloadedMediaIds.contains(id))
            .toList();
        if (filtered.length != f.trackIds.length) {
          folders[i] = f.copyWith(
            trackIds: filtered,
            updatedAt: DateTime.now(),
          );
          foldersModified = true;
        }
      }
      if (foldersModified) {
        await _saveFolders(folders);
      }
    } catch (e, stack) {
      log('Error during stale reference reconciliation: $e',
          name: 'OfflineOrganizerService', error: e, stackTrace: stack);
    }
  }
}

