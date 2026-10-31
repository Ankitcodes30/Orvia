import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/plugins/utils/media_id.dart';
import 'package:Orvia/services/db/dao/playlist_dao.dart';
import 'package:Orvia/services/db/dao/track_dao.dart';
import 'package:Orvia/services/db/global_db.dart';
import 'package:Orvia/services/catalogue/dammn_playlist_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late Isar isar;
  late PlaylistDAO playlistDAO;
  late TrackDAO trackDAO;

  setUp(() async {
    await Isar.initializeIsarCore(download: false);
    tempRoot = await Directory.systemTemp.createTemp('orvia_dammn_removal_test_');

    isar = await Isar.open(
      [
        PlaylistDBSchema,
        PlaylistEntryDBSchema,
        TrackDBSchema,
        DownloadDBSchema,
      ],
      directory: tempRoot.path,
      inspector: false,
    );

    trackDAO = TrackDAO(Future.value(isar));
    playlistDAO = PlaylistDAO(Future.value(isar), trackDAO);
  });

  tearDown(() async {
    if (isar.isOpen) {
      await isar.close(deleteFromDisk: true);
    }
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  group('Task C — Dammn Feature Removal & Safe Cleanup', () {
    test('Dammn service ensurePlaylistExists is retired and does not auto-seed into Library', () async {
      await DammnPlaylistService.ensurePlaylistExists(playlistDAO);

      final p = await playlistDAO.getPlaylistByName(DammnPlaylistService.playlistName);
      expect(p, isNull, reason: 'Dammn playlist should no longer be auto-seeded');

      final allPlaylists = await playlistDAO.getAllPlaylists();
      expect(allPlaylists.isEmpty, isTrue);
    });

    test('isTrackProtected and isDammnPlaylist always return false', () async {
      final pId = await playlistDAO.createPlaylist('Dammn');
      expect(pId, isNotNull);

      expect(await playlistDAO.isDammnPlaylist(pId!), isFalse);
      expect(await playlistDAO.isTrackProtected(pId, 'any_media_id'), isFalse);
      expect(DammnPlaylistService.isOriginalTrack('any_media_id'), isFalse);
    });

    test('Existing Dammn playlist entries can have tracks deleted without restriction', () async {
      // Simulate an existing Dammn playlist from a previous app version
      final pId = await playlistDAO.createPlaylist('Dammn');
      expect(pId, isNotNull);

      final dummyTrack = Track(
        id: '$kDefaultSaavnPluginId::track1',
        title: 'Song 1',
        artists: [const ArtistSummary(id: 'a1', name: 'Artist 1')],
        thumbnail: const Artwork(url: 'https://example.com/art.jpg', layout: ImageLayout.square),
        isExplicit: false,
      );

      await playlistDAO.addTrackToPlaylist(pId!, dummyTrack);
      var tracks = await playlistDAO.getPlaylistTracks(pId);
      expect(tracks.length, equals(1));

      // Removing track must succeed without protection refusal
      await playlistDAO.removeTrackFromPlaylist(pId, dummyTrack.id);
      tracks = await playlistDAO.getPlaylistTracks(pId);
      expect(tracks.isEmpty, isTrue, reason: 'Track should be successfully removed without lock');
    });

    test('Existing user custom playlists are completely unaffected', () async {
      final userPId = await playlistDAO.createPlaylist('My Roadtrip Mix');
      expect(userPId, isNotNull);

      final trackA = Track(
        id: '$kDefaultSaavnPluginId::songA',
        title: 'Highway Star',
        artists: [const ArtistSummary(id: 'a2', name: 'Deep Purple')],
        thumbnail: const Artwork(url: 'https://example.com/art.jpg', layout: ImageLayout.square),
        isExplicit: false,
      );

      await playlistDAO.addTrackToPlaylist(userPId!, trackA);
      final tracks = await playlistDAO.getPlaylistTracks(userPId);
      expect(tracks.length, equals(1));
      expect(tracks.first.title, equals('Highway Star'));
    });
  });
}
