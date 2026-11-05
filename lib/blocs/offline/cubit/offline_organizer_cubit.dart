import 'dart:async';
import 'package:Orvia/blocs/downloader/cubit/downloader_cubit.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/models/offline_organizer_models.dart';
import 'package:Orvia/plugins/utils/media_id.dart';
import 'package:Orvia/services/offline/offline_organizer_service.dart';
import 'package:bloc/bloc.dart';

import 'offline_organizer_state.dart';

class OfflineOrganizerCubit extends Cubit<OfflineOrganizerState> {
  final OfflineOrganizerService _service;
  final DownloaderCubit? _downloaderCubit;
  StreamSubscription? _downloaderSub;

  OfflineOrganizerCubit({
    required OfflineOrganizerService service,
    DownloaderCubit? downloaderCubit,
  })  : _service = service,
        _downloaderCubit = downloaderCubit,
        super(OfflineOrganizerInitial()) {
    loadData();
    if (_downloaderCubit != null) {
      _downloaderSub = _downloaderCubit.stream.listen((downState) {
        // When downloaded list changes, check if we need to reconcile
        final validIds = downState.downloaded.map((t) => t.id).toSet();
        if (validIds.isNotEmpty) {
          _service.reconcileStaleReferences(validIds);
        }
      });
    }
  }

  /// Load folders and collections from storage.
  Future<void> loadData() async {
    try {
      final folders = await _service.getFolders();
      final collections = await _service.getCollections();
      emit(OfflineOrganizerLoaded(
        folders: folders,
        collections: collections,
      ));
    } catch (_) {
      emit(const OfflineOrganizerLoaded(
        folders: [],
        collections: [],
      ));
    }
  }

  /// Create a new custom folder.
  Future<OfflineFolder> createFolder(String name) async {
    final folder = await _service.createFolder(name);
    await loadData();
    return folder;
  }

  /// Rename an existing folder.
  Future<OfflineFolder?> renameFolder(String folderId, String newName) async {
    final updated = await _service.renameFolder(folderId, newName);
    await loadData();
    return updated;
  }

  /// Analyze folder deletion impact.
  Future<FolderDeleteImpact> getFolderDeleteImpact(String folderId) {
    return _service.getFolderDeleteImpact(folderId);
  }

  /// Delete a folder safely.
  /// If [deleteAudioFiles] is true, only audio files UNIQUE to this folder
  /// (not present in any other folder or collection) are removed from disk.
  Future<bool> deleteFolder(
    String folderId, {
    bool deleteAudioFiles = false,
    DownloaderCubit? downloaderCubit,
  }) async {
    if (deleteAudioFiles) {
      final cubit = downloaderCubit ?? _downloaderCubit;
      if (cubit != null) {
        final impact = await _service.getFolderDeleteImpact(folderId);
        final downloaded = cubit.state.downloaded;
        for (final uniqueId in impact.uniqueTrackIds) {
          final track = downloaded.cast<Track?>().firstWhere(
                (t) => t?.id == uniqueId,
                orElse: () => null,
              );
          if (track != null) {
            await cubit.removeDownload(track);
          }
        }
      }
    }

    final success = await _service.deleteFolder(folderId);
    await loadData();
    return success;
  }

  /// Add tracks to a folder.
  Future<bool> addTracksToFolder(String folderId, List<String> trackIds) async {
    final success = await _service.addTracksToFolder(folderId, trackIds);
    await loadData();
    return success;
  }

  /// Remove tracks from a folder.
  Future<bool> removeTracksFromFolder(
      String folderId, List<String> trackIds) async {
    final success = await _service.removeTracksFromFolder(folderId, trackIds);
    await loadData();
    return success;
  }

  /// Move tracks from one folder to another.
  Future<bool> moveTracks({
    required String sourceFolderId,
    required String targetFolderId,
    required List<String> trackIds,
  }) async {
    final success = await _service.moveTracks(
      sourceFolderId: sourceFolderId,
      targetFolderId: targetFolderId,
      trackIds: trackIds,
    );
    await loadData();
    return success;
  }

  /// Copy tracks to a target folder.
  Future<bool> copyTracks({
    required String targetFolderId,
    required List<String> trackIds,
  }) async {
    final success = await _service.copyTracks(
      targetFolderId: targetFolderId,
      trackIds: trackIds,
    );
    await loadData();
    return success;
  }

  /// Extract tracks out of a folder (removes folder reference, audio file remains).
  Future<bool> extractTracksFromFolder(
      String folderId, List<String> trackIds) async {
    final success = await _service.extractTracksFromFolder(folderId, trackIds);
    await loadData();
    return success;
  }

  /// Register or update an offline collection.
  Future<OfflineCollection> registerCollection({
    required String id,
    required String title,
    required String type,
    String? coverUrl,
    required List<String> trackIds,
  }) async {
    final col = await _service.registerCollection(
      id: id,
      title: title,
      type: type,
      coverUrl: coverUrl,
      trackIds: trackIds,
    );
    await loadData();
    return col;
  }

  /// Delete an offline collection.
  Future<bool> deleteCollection(String collectionId) async {
    final success = await _service.deleteCollection(collectionId);
    await loadData();
    return success;
  }

  /// Get verified downloaded tracks belonging to a folder.
  List<Track> getFolderTracks(
      String folderId, List<Track> allDownloadedTracks) {
    if (state is! OfflineOrganizerLoaded) return const [];
    final currentFolders = (state as OfflineOrganizerLoaded).folders;
    final folder = currentFolders.cast<OfflineFolder?>().firstWhere(
          (f) => f?.id == folderId,
          orElse: () => null,
        );
    if (folder == null) return const [];

    final trackMap = {for (final t in allDownloadedTracks) t.id: t};
    final result = <Track>[];
    for (final tid in folder.trackIds) {
      final track = trackMap[tid];
      if (track != null) {
        result.add(track);
      }
    }
    return result;
  }

  /// Get verified downloaded tracks belonging to a collection.
  List<Track> getCollectionTracks(
      String collectionId, List<Track> allDownloadedTracks) {
    if (state is! OfflineOrganizerLoaded) return const [];
    final collections = (state as OfflineOrganizerLoaded).collections;
    final col = collections.cast<OfflineCollection?>().firstWhere(
          (c) => c?.id == collectionId,
          orElse: () => null,
        );
    if (col == null) return const [];

    final result = <Track>[];
    final matchedIds = <String>{};

    // 1. Match via requestedTrackIds (with robust ID reconciliation)
    for (final tid in col.requestedTrackIds) {
      Track? matched;
      for (final t in allDownloadedTracks) {
        if (t.id == tid || isMatchingTrackId(t.id, tid)) {
          matched = t;
          break;
        }
      }
      if (matched != null && !matchedIds.contains(matched.id)) {
        matchedIds.add(matched.id);
        result.add(matched);
      }
    }

    // 2. For album collections, also match downloaded tracks with matching album identity
    if (col.type == 'album') {
      final cleanAlbumId = col.id.replaceFirst('album_', '');
      final normTitle = col.title.trim().toLowerCase();

      for (final t in allDownloadedTracks) {
        if (matchedIds.contains(t.id)) continue;

        bool isAlbumMatch = false;
        if (t.album?.id != null && t.album!.id.isNotEmpty) {
          if (isMatchingTrackId(t.album!.id, col.id) ||
              isMatchingTrackId(t.album!.id, cleanAlbumId)) {
            isAlbumMatch = true;
          }
        }

        if (!isAlbumMatch &&
            normTitle.isNotEmpty &&
            t.album?.title.trim().toLowerCase() == normTitle) {
          isAlbumMatch = true;
        }

        if (isAlbumMatch) {
          matchedIds.add(t.id);
          result.add(t);
        }
      }
    }

    return result;
  }

  @override
  Future<void> close() {
    _downloaderSub?.cancel();
    return super.close();
  }
}
