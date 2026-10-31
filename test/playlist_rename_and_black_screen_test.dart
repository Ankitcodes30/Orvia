import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'package:isar_community/isar.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:Orvia/blocs/library/cubit/library_items_cubit.dart';
import 'package:Orvia/core/models/exported.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/l10n/app_localizations.dart';
import 'package:Orvia/screens/screen/library_views/cubit/current_playlist_cubit.dart';
import 'package:Orvia/screens/screen/library_views/more_opts_sheet.dart';
import 'package:Orvia/services/db/dao/library_dao.dart';
import 'package:Orvia/services/db/dao/playlist_dao.dart';
import 'package:Orvia/services/db/dao/track_dao.dart';
import 'package:Orvia/services/db/db_provider.dart';
import 'package:Orvia/services/db/global_db.dart';

class MockFilePicker extends FilePicker {
  static String testExportDir = '/fake/downloads';

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async {
    return testExportDir;
  }

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => null;

  @override
  Future<bool?> clearTemporaryFiles() async => true;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late Isar isar;
  late PlaylistDAO playlistDAO;
  late TrackDAO trackDAO;
  late LibraryDAO libraryDAO;

  final sampleTracks = [
    Track(
      id: 'saavn:dxrBpjVX',
      title: 'Kesariya',
      artists: const [ArtistSummary(id: 'arijit', name: 'Arijit Singh')],
      album: const AlbumSummary(
          id: 'brahmastra', title: 'Brahmastra', artists: []),
      thumbnail: const Artwork(
          url: '',
          layout: ImageLayout.square),
      durationMs: BigInt.from(268000),
      isExplicit: false,
    ),
    Track(
      id: 'youtube:dQw4w9WgXcQ',
      title: 'Never Gonna Give You Up',
      artists: const [ArtistSummary(id: 'rick', name: 'Rick Astley')],
      album: const AlbumSummary(
          id: 'whenever', title: 'Whenever You Need Somebody', artists: []),
      thumbnail: const Artwork(
          url: '',
          layout: ImageLayout.square),
      durationMs: BigInt.from(212000),
      isExplicit: false,
    ),
  ];

  setUpAll(() async {
    await Isar.initializeIsarCore(download: false);
    tempRoot =
        await Directory.systemTemp.createTemp('orvia_playlist_rename_test_');

    isar = await Isar.open(
      [
        PlaylistDBSchema,
        PlaylistEntryDBSchema,
        TrackDBSchema,
        DownloadDBSchema,
      ],
      name: 'test_db_${DateTime.now().microsecondsSinceEpoch}',
      directory: tempRoot.path,
      inspector: false,
    );

    trackDAO = TrackDAO(Future.value(isar));
    playlistDAO = PlaylistDAO(Future.value(isar), trackDAO);
    libraryDAO = LibraryDAO(Future.value(isar));
    DBProvider.db = Future.value(isar);
    MockFilePicker.testExportDir = tempRoot.path;
    FilePicker.platform = MockFilePicker();
    PackageInfo.setMockInitialValues(
      appName: 'Orvia',
      packageName: 'ls.orvia.musicplayer',
      version: '3.0.7',
      buildNumber: '4',
      buildSignature: '',
    );
  });

  setUp(() async {
    await isar.writeTxn(() async {
      await isar.clear();
    });
  });

  tearDownAll(() async {
    if (isar.isOpen) {
      await isar.close(deleteFromDisk: true);
    }
    try {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Playlist Rename & Persistence Tests', () {
    test('1. LibraryItemsCubit.renamePlaylist updates DB by ID, preserves songs and order, and refreshes state', () async {
      final playlistId = await playlistDAO.createPlaylist(
        'Morning Acoustic',
        description: 'Chill morning songs',
      );
      expect(playlistId, isNotNull);
      await playlistDAO.addTracksToPlaylist(playlistId!, sampleTracks);

      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: libraryDAO,
      );
      await Future.delayed(const Duration(milliseconds: 50));

      // Execute rename
      final success = await cubit.renamePlaylist(playlistId, 'Evening Acoustic');
      expect(success, isTrue);

      // Verify DB persistence
      final updatedDB = await playlistDAO.getPlaylistById(playlistId);
      expect(updatedDB, isNotNull);
      expect(updatedDB!.name, equals('Evening Acoustic'));
      expect(updatedDB.description, equals('Chill morning songs'));

      // Verify songs & ordering in DB are intact
      final tracks = await playlistDAO.getPlaylistTracks(playlistId);
      expect(tracks.length, equals(2));
      expect(tracks[0].mediaId, equals('saavn:dxrBpjVX'));
      expect(tracks[0].title, equals('Kesariya'));
      expect(tracks[1].mediaId, equals('youtube:dQw4w9WgXcQ'));
      expect(tracks[1].title, equals('Never Gonna Give You Up'));

      // Verify old name is gone from DB
      final oldDB = await playlistDAO.getPlaylistByName('Morning Acoustic');
      expect(oldDB, isNull);

      // Verify cubit state reflects updated playlist
      final statePlaylists = cubit.state.playlists;
      expect(statePlaylists.any((p) => p.playlistName == 'Evening Acoustic'), isTrue);
      expect(statePlaylists.any((p) => p.playlistName == 'Morning Acoustic'), isFalse);

      await cubit.close();
    });

    test('2. Renaming preserves identity and survives simulated app restart', () async {
      final playlistId = await playlistDAO.createPlaylist('Work Focus');
      expect(playlistId, isNotNull);
      await playlistDAO.addTracksToPlaylist(playlistId!, sampleTracks);

      // Simulate first session rename
      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: libraryDAO,
      );
      await Future.delayed(const Duration(milliseconds: 50));
      await cubit.renamePlaylist(playlistId, 'Deep Work Focus');
      await cubit.close();

      // Simulate app restart / reopen by reloading directly from DAO
      final loadedAfterRestart = await playlistDAO.loadPlaylist('Deep Work Focus');
      expect(loadedAfterRestart.title, equals('Deep Work Focus'));
      expect(loadedAfterRestart.tracks.length, equals(2));
      expect(loadedAfterRestart.tracks[0].id, equals('saavn:dxrBpjVX'));
      expect(loadedAfterRestart.tracks[1].id, equals('youtube:dQw4w9WgXcQ'));

      // Ensure stable ID was preserved
      final record = await playlistDAO.getPlaylistByName('Deep Work Focus');
      expect(record!.id, equals(playlistId));
    });

    test('3. Empty or whitespace-only name is rejected and does not alter stored data', () async {
      final playlistId = await playlistDAO.createPlaylist('Study Beats');
      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: libraryDAO,
      );
      await Future.delayed(const Duration(milliseconds: 50));

      final emptyResult = await cubit.renamePlaylist(playlistId!, '');
      expect(emptyResult, isFalse);

      final whitespaceResult = await cubit.renamePlaylist(playlistId, '   ');
      expect(whitespaceResult, isFalse);

      final record = await playlistDAO.getPlaylistById(playlistId);
      expect(record!.name, equals('Study Beats'));

      await cubit.close();
    });

    test('4. Duplicate name collision with a different playlist is prevented', () async {
      final p1 = await playlistDAO.createPlaylist('Jazz 1');
      final p2 = await playlistDAO.createPlaylist('Jazz 2');
      expect(p1, isNotNull);
      expect(p2, isNotNull);

      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: libraryDAO,
      );
      await Future.delayed(const Duration(milliseconds: 50));

      // Attempting to rename p2 to 'Jazz 1' should be prevented
      final collisionResult = await cubit.renamePlaylist(p2!, 'Jazz 1');
      expect(collisionResult, isFalse);

      // Verify both playlists kept their names
      final rec1 = await playlistDAO.getPlaylistById(p1!);
      final rec2 = await playlistDAO.getPlaylistById(p2);
      expect(rec1!.name, equals('Jazz 1'));
      expect(rec2!.name, equals('Jazz 2'));

      await cubit.close();
    });

    test('5. CurrentPlaylistCubit.renameCurrentPlaylist updates title in-memory without resetting loaded tracks', () async {
      final pId = await playlistDAO.createPlaylist(
        'Roadtrip 2026',
        description: 'Epic tunes',
      );
      expect(pId, isNotNull);
      await playlistDAO.addTracksToPlaylist(pId!, sampleTracks);

      final currentCubit = CurrentPlaylistCubit(
        playlistDao: playlistDAO,
      );

      await currentCubit.openPlaylist('Roadtrip 2026');

      expect(currentCubit.playlistId, equals(pId));
      expect(currentCubit.state.playlist.title, equals('Roadtrip 2026'));
      expect(currentCubit.state.playlist.tracks.length, equals(2));

      // Call renameCurrentPlaylist
      currentCubit.renameCurrentPlaylist('Roadtrip Summer 2026');

      expect(currentCubit.state.playlist.title, equals('Roadtrip Summer 2026'));
      expect(currentCubit.state.playlist.tracks.length, equals(2));
      expect(currentCubit.state.playlist.tracks[0].title, equals('Kesariya'));
      expect(currentCubit.state.playlist.description, equals('Epic tunes'));
      expect(currentCubit.playlistId, equals(pId));

      await currentCubit.close();
    });
  });

  group('Black-Screen Lifecycle & Route Dismissal Tests', () {
    testWidgets('6. Library 3-dot menu -> Rename does NOT pop the parent route (no black screen)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (homeContext) => Scaffold(
              body: Column(
                children: [
                  const Text('Library Screen Root'),
                  TextButton(
                    onPressed: () {
                      Navigator.of(homeContext).push(
                        MaterialPageRoute<void>(
                          builder: (subContext) => Scaffold(
                            body: Builder(
                              builder: (ctx) => Column(
                                children: [
                                  const Text('Sub Library Route'),
                                  TextButton(
                                    onPressed: () => showPlaylistOptsExtSheet(
                                      ctx,
                                      'Chill Vibes',
                                      playlistId: 101,
                                    ),
                                    child: const Text('Open 3-Dot Menu'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Navigate to Sub Library'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Navigate to sub-route
      await tester.tap(find.text('Navigate to Sub Library'));
      await tester.pumpAndSettle();
      expect(find.text('Sub Library Route'), findsOneWidget);

      // Open 3-dot sheet
      await tester.tap(find.text('Open 3-Dot Menu'));
      await tester.pumpAndSettle();
      expect(find.text('Chill Vibes'), findsOneWidget);
      expect(find.text('Rename Playlist'), findsOneWidget);

      // Tap Rename in bottom sheet
      await tester.tap(find.text('Rename Playlist'));
      await tester.pumpAndSettle();

      // Bottom sheet has been dismissed and Rename dialog is visible
      expect(find.byType(AlertDialog), findsOneWidget);
      // CRITICAL: Sub Library Route must still be mounted behind the dialog!
      expect(find.text('Sub Library Route'), findsOneWidget);

      // Tap Cancel in rename dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog is gone, and the parent Sub Library Route remains visible and interactive
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Sub Library Route'), findsOneWidget);
      expect(find.text('Open 3-Dot Menu'), findsOneWidget);
    });

    testWidgets('7. Opened Playlist Screen -> 3-dot menu -> Rename does NOT pop playlist route (no black screen)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (homeContext) => Scaffold(
              body: Column(
                children: [
                  const Text('Library View'),
                  TextButton(
                    onPressed: () {
                      Navigator.of(homeContext).push(
                        MaterialPageRoute<void>(
                          builder: (playlistRouteContext) => Scaffold(
                            body: Builder(
                              builder: (ctx) => Column(
                                children: [
                                  const Text('Opened Playlist View Screen'),
                                  TextButton(
                                    onPressed: () => showPlaylistOptsInrSheet(
                                      ctx,
                                      Playlist(
                                        title: 'Workout Beats',
                                        tracks: sampleTracks,
                                      ),
                                    ),
                                    child: const Text('Open Playlist 3-Dot'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Open Workout Playlist'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Open playlist
      await tester.tap(find.text('Open Workout Playlist'));
      await tester.pumpAndSettle();
      expect(find.text('Opened Playlist View Screen'), findsOneWidget);

      // Open 3-dot options
      await tester.tap(find.text('Open Playlist 3-Dot'));
      await tester.pumpAndSettle();
      expect(find.text('Workout Beats'), findsOneWidget);
      expect(find.text('Rename Playlist'), findsOneWidget);

      // Tap Rename
      await tester.tap(find.text('Rename Playlist'));
      await tester.pumpAndSettle();

      // Rename dialog is shown and Opened Playlist View Screen is still mounted
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Opened Playlist View Screen'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Playlist View remains fully mounted and interactive
      expect(find.text('Opened Playlist View Screen'), findsOneWidget);
      expect(find.text('Open Playlist 3-Dot'), findsOneWidget);
    });

    testWidgets('8. Library 3-dot menu -> Export does NOT pop the parent route (no black screen)', (tester) async {
      bool exportInvoked = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (homeContext) => Scaffold(
              body: Column(
                children: [
                  const Text('Root Library Screen'),
                  TextButton(
                    onPressed: () {
                      Navigator.of(homeContext).push(
                        MaterialPageRoute<void>(
                          builder: (subContext) => Scaffold(
                            body: Builder(
                              builder: (ctx) => Column(
                                children: [
                                  const Text('Library Playlist Route'),
                                  TextButton(
                                    onPressed: () => showPlaylistOptsExtSheet(
                                      ctx,
                                      'Acoustic Favorites',
                                      playlistId: 102,
                                      onExport: (exportCtx, title) async {
                                        exportInvoked = true;
                                      },
                                    ),
                                    child: const Text('Open Sheet'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Push Library Playlist Route'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Push Library Playlist Route'));
      await tester.pumpAndSettle();
      expect(find.text('Library Playlist Route'), findsOneWidget);

      // Open options bottom sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Export tile is visible
      expect(find.byIcon(MingCute.file_export_line), findsOneWidget);

      // Tap Export: tile InkWell dismisses sheet, waits for sheetRoute.completed, and triggers export
      await tester.tap(find.byIcon(MingCute.file_export_line));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Verify the onExport hook was invoked
      expect(exportInvoked, isTrue);

      // Bottom sheet should be fully dismissed
      expect(find.byIcon(MingCute.file_export_line), findsNothing);

      // CRITICAL: Library Playlist Route MUST still be mounted, visible, and NOT popped (preventing black screen)
      expect(find.text('Library Playlist Route'), findsOneWidget);
      expect(find.text('Open Sheet'), findsOneWidget);
    });
  });
}
