import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:Orvia/blocs/library/cubit/library_items_cubit.dart';
import 'package:Orvia/core/models/media_playlist_model.dart';
import 'package:Orvia/l10n/app_localizations.dart';
import 'package:Orvia/screens/screen/library_views/cubit/current_playlist_cubit.dart';
import 'package:Orvia/screens/screen/library_views/more_opts_sheet.dart';
import 'package:Orvia/services/catalogue/creators_choice_service.dart';
import 'package:Orvia/services/db/dao/library_dao.dart';
import 'package:Orvia/services/db/dao/playlist_dao.dart';
import 'package:Orvia/services/db/dao/track_dao.dart';
import 'package:Orvia/services/db/global_db.dart';
import 'package:Orvia/services/import_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late Isar isar;
  late PlaylistDAO playlistDAO;
  late TrackDAO trackDAO;
  late LibraryDAO libraryDAO;

  setUp(() async {
    await Isar.initializeIsarCore(download: false);
    tempRoot = await Directory.systemTemp.createTemp('orvia_creators_choice_test_');

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
    libraryDAO = LibraryDAO(Future.value(isar));
  });

  tearDown(() async {
    if (isar.isOpen) {
      await isar.close(deleteFromDisk: true);
    }
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  group("Creator's Choice Identity & Ownership Display Tests", () {
    test("1. CreatorsChoiceService identifies Creator's Choice reliably", () {
      expect(CreatorsChoiceService.isCreatorsChoice("Creator's Choice"), isTrue);
      expect(CreatorsChoiceService.isCreatorsChoice("creator's choice"), isTrue);
      expect(CreatorsChoiceService.isCreatorsChoice("Creator’s Choice"), isTrue); // right apostrophe
      expect(CreatorsChoiceService.isCreatorsChoice("Creators Choice"), isTrue);
      expect(CreatorsChoiceService.isCreatorsChoice("My Favorites"), isFalse);
      expect(CreatorsChoiceService.isCreatorsChoice(null), isFalse);
      expect(CreatorsChoiceService.isCreatorsChoice(""), isFalse);
    });

    testWidgets("2. Creator's Choice owner text displays 'by A.K.' vs 'by You' for custom playlist", (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              final ccOwner = CreatorsChoiceService.isCreatorsChoice("Creator's Choice")
                  ? 'A.K.'
                  : l10n.playlistYou;
              final customOwner = CreatorsChoiceService.isCreatorsChoice("My Weekend Mix")
                  ? 'A.K.'
                  : l10n.playlistYou;

              return Scaffold(
                body: Column(
                  children: [
                    Text(l10n.playlistByCreator(ccOwner), key: const ValueKey('cc_owner')),
                    Text(l10n.playlistByCreator(customOwner), key: const ValueKey('custom_owner')),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('cc_owner')), findsOneWidget);
      expect(find.byKey(const ValueKey('custom_owner')), findsOneWidget);

      final ccTextWidget = tester.widget<Text>(find.byKey(const ValueKey('cc_owner')));
      final customTextWidget = tester.widget<Text>(find.byKey(const ValueKey('custom_owner')));

      expect(ccTextWidget.data, equals('by A.K.'));
      expect(customTextWidget.data, equals('by You'));
    });
  });

  group("Creator's Choice Menu Actions Removal & Ordinary Playlist Preservation Tests", () {
    testWidgets("3. More options sheet for Creator's Choice omits Share, Rename, Export, and Delete", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showPlaylistOptsExtSheet(
                    ctx,
                    "Creator's Choice",
                    playlistId: 1,
                  ),
                  child: const Text('Open Menu'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Menu'));
      await tester.pumpAndSettle();

      // Playlist title is displayed
      expect(find.text("Creator's Choice"), findsOneWidget);

      // Verify restricted management actions are ABSENT
      expect(find.text('Share Playlist'), findsNothing);
      expect(find.text('Rename Playlist'), findsNothing);
      expect(find.text('Export File'), findsNothing);
      expect(find.text('Delete Playlist'), findsNothing);
      expect(find.text('Edit Playlist'), findsNothing);

      // Listening/library actions remain present
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Add Playlist to Queue'), findsOneWidget);
      expect(find.text('Pin to Top'), findsOneWidget);
    });

    testWidgets("4. More options sheet for internal Creator's Choice view omits Share, Rename, and Export", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showPlaylistOptsInrSheet(
                    ctx,
                    Playlist(tracks: const [], title: "Creator's Choice"),
                  ),
                  child: const Text('Open Internal Menu'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Internal Menu'));
      await tester.pumpAndSettle();

      expect(find.text("Creator's Choice"), findsOneWidget);
      expect(find.text('Share Playlist'), findsNothing);
      expect(find.text('Rename Playlist'), findsNothing);
      expect(find.text('Export File'), findsNothing);
      expect(find.text('Edit Playlist'), findsNothing);
    });

    testWidgets("5. More options sheet for ordinary user playlist PRESERVES Share, Rename, and Export", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showPlaylistOptsExtSheet(
                    ctx,
                    "My Party Jams",
                    playlistId: 42,
                  ),
                  child: const Text('Open Custom Menu'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Custom Menu'));
      await tester.pumpAndSettle();

      expect(find.text("My Party Jams"), findsOneWidget);

      // All management actions ARE present for ordinary playlists
      expect(find.text('Share Playlist'), findsOneWidget);
      expect(find.text('Rename Playlist'), findsOneWidget);
      expect(find.text('Export File'), findsOneWidget);
      expect(find.text('Pin to Top'), findsOneWidget);
      expect(find.text('Delete Playlist'), findsOneWidget);
    });
  });

  group("Programmatic & Backend Protection Guard Tests", () {
    test("6. Renaming Creator's Choice via LibraryItemsCubit is blocked", () async {
      await CreatorsChoiceService.ensurePlaylistExists(playlistDAO);
      final cc = await playlistDAO.getPlaylistByName(CreatorsChoiceService.playlistName);
      expect(cc, isNotNull);

      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: libraryDAO,
      );

      final renameByIdResult = await cubit.renamePlaylist(cc!.id, 'New Name');
      expect(renameByIdResult, isFalse, reason: 'Renaming by ID must be rejected');

      final renameByNameResult = await cubit.renamePlaylistByName(CreatorsChoiceService.playlistName, 'New Name');
      expect(renameByNameResult, isFalse, reason: 'Renaming by name must be rejected');

      // Verify name remained unchanged in DB
      final dbCheck = await playlistDAO.getPlaylistById(cc.id);
      expect(dbCheck!.name, equals(CreatorsChoiceService.playlistName));

      await cubit.close();
    });

    test("7. Renaming another playlist to Creator's Choice is blocked", () async {
      final customId = await playlistDAO.createPlaylist('Custom Beats');
      expect(customId, isNotNull);

      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: libraryDAO,
      );

      final collisionResult = await cubit.renamePlaylist(customId!, "Creator's Choice");
      expect(collisionResult, isFalse, reason: "Renaming to Creator's Choice must be blocked");

      final dbCheck = await playlistDAO.getPlaylistById(customId);
      expect(dbCheck!.name, equals('Custom Beats'));

      await cubit.close();
    });

    test("8. Deleting Creator's Choice via LibraryItemsCubit is blocked", () async {
      await CreatorsChoiceService.ensurePlaylistExists(playlistDAO);
      final cc = await playlistDAO.getPlaylistByName(CreatorsChoiceService.playlistName);
      expect(cc, isNotNull);

      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: libraryDAO,
      );

      cubit.removePlaylistByName(CreatorsChoiceService.playlistName);
      cubit.removePlaylistById(cc!.id);

      final dbCheck = await playlistDAO.getPlaylistByName(CreatorsChoiceService.playlistName);
      expect(dbCheck, isNotNull, reason: "Creator's Choice must not be deleted");

      await cubit.close();
    });

    test("9. Exporting Creator's Choice via ImportExportService returns null and blocks export", () async {
      await CreatorsChoiceService.ensurePlaylistExists(playlistDAO);

      final result = await ImportExportService.exportPlaylist(CreatorsChoiceService.playlistName);
      expect(result, isNull, reason: "Exporting Creator's Choice must be blocked");
    });

    test("10. CurrentPlaylistCubit protects Creator's Choice from rename and track removal", () async {
      await CreatorsChoiceService.ensurePlaylistExists(playlistDAO);

      final cubit = CurrentPlaylistCubit(
        playlistDao: playlistDAO,
      );

      await cubit.openPlaylist(CreatorsChoiceService.playlistName, deferFirstPage: true);
      expect(cubit.state.playlist.title, equals(CreatorsChoiceService.playlistName));
      expect(cubit.state.totalTracks, equals(CreatorsChoiceService.getVerifiedTracks().length));

      // Attempt rename
      cubit.renameCurrentPlaylist('Renamed Playlist');
      expect(cubit.state.playlist.title, equals(CreatorsChoiceService.playlistName));

      // Attempt track removal
      final allTracks = CreatorsChoiceService.getVerifiedTracks();
      final removeResult = await cubit.removeTrack(allTracks.first);
      expect(removeResult, isNull);
      expect(cubit.state.totalTracks, equals(CreatorsChoiceService.getVerifiedTracks().length));

      await cubit.close();
    });
  });

  group("Creator's Choice Tracks & Playback Integrity Tests", () {
    test("11. Verified Creator's Choice tracks count is exactly 70 with valid playback properties", () {
      final tracks = CreatorsChoiceService.getVerifiedTracks();
      expect(tracks.length, equals(70));

      for (var i = 0; i < tracks.length; i++) {
        final t = tracks[i];
        expect(
          t.id.startsWith(CreatorsChoiceService.pluginId) ||
              t.id.startsWith(CreatorsChoiceService.ytPluginId),
          isTrue,
          reason: 'Track $i should have valid plugin id prefix',
        );
        expect(t.title.trim(), isNotEmpty, reason: 'Track $i title must not be empty');
        expect(t.artists, isNotEmpty, reason: 'Track $i artists must not be empty');
        expect(t.durationMs, isNotNull, reason: 'Track $i duration must not be null');
        expect(t.durationMs! > BigInt.zero, isTrue, reason: 'Track $i duration must be positive');
        expect(t.thumbnail.url, startsWith('https://'), reason: 'Track $i thumbnail URL must be secure https');
      }
    });

    test("12. Seeding populates all 70 tracks into PlaylistDAO without loss", () async {
      await CreatorsChoiceService.ensurePlaylistExists(playlistDAO);

      final cc = await playlistDAO.getPlaylistByName(CreatorsChoiceService.playlistName);
      expect(cc, isNotNull);

      final entries = await playlistDAO.getPlaylistTracks(cc!.id);
      expect(entries.length, equals(70));
      expect(entries.first.title, equals('Naino Ne Baandhi'));
    });
  });
}
