import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:Orvia/screens/widgets/database_recovery_screen.dart';
import 'package:Orvia/services/db/db_provider.dart';
import 'package:Orvia/services/storage_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DB Startup Protection - Error Classification (P1)', () {
    test('correctly identifies transient locks and sharing violations', () {
      expect(
        DBProvider.classifyDbError('OS Error: sharing violation, errno = 32'),
        equals(DbInitErrorType.transientLock),
      );
      expect(
        DBProvider.classifyDbError('IsarError: Database file is locked or busy'),
        equals(DbInitErrorType.transientLock),
      );
      expect(
        DBProvider.classifyDbError('Resource temporarily unavailable'),
        equals(DbInitErrorType.transientLock),
      );
      expect(
        DBProvider.classifyDbError('OS Error: Access denied, errno = 5'),
        equals(DbInitErrorType.transientLock),
      );
    });

    test('correctly identifies MDBX corruption and invalid headers', () {
      expect(
        DBProvider.classifyDbError('MDBX_CORRUPTED: Page checksum failed'),
        equals(DbInitErrorType.corruption),
      );
      expect(
        DBProvider.classifyDbError('Bad magic number: invalid database file'),
        equals(DbInitErrorType.corruption),
      );
      expect(
        DBProvider.classifyDbError('Invalid page format or truncated database'),
        equals(DbInitErrorType.corruption),
      );
    });

    test('classifies unhandled errors as unknown', () {
      expect(
        DBProvider.classifyDbError('Out of memory while allocating buffer'),
        equals(DbInitErrorType.unknown),
      );
    });
  });

  group('DB Startup Protection - Quarantine & Backup Preservation (P1)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('orvia_db_safety_test_');
      DBProvider.appSuppDir = tempDir.path;
      DBProvider.appDocDir = tempDir.path;
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('safeQuarantineDatabaseFile creates verified copy and preserves original',
        () async {
      final dbFile = File(p.join(tempDir.path, 'dbv3.isar'));
      final dummyContent = List<int>.generate(2048, (i) => i % 256);
      await dbFile.writeAsBytes(dummyContent);

      final originalHash = await DBProvider.computeFileSha256(dbFile);

      // Perform quarantine
      final quarantinedPath =
          await DBProvider.safeQuarantineDatabaseFile(dbFile);

      expect(quarantinedPath, isNotNull);
      final quarantinedFile = File(quarantinedPath!);

      // 1. Quarantined file exists
      expect(await quarantinedFile.exists(), isTrue);

      // 2. Original file is NOT deleted or corrupted
      expect(await dbFile.exists(), isTrue);
      expect(await dbFile.length(), equals(dummyContent.length));

      // 3. Quarantined file has exact matching byte length and SHA-256 hash
      expect(await quarantinedFile.length(), equals(dummyContent.length));
      final copyHash = await DBProvider.computeFileSha256(quarantinedFile);
      expect(copyHash, equals(originalHash));

      // 4. Filename is collision-safe with timestamp and PID
      expect(p.basename(quarantinedPath), startsWith('dbv3_corrupted_'));
      expect(p.basename(quarantinedPath), endsWith('.isar'));
    });
  });

  group('DB Startup Protection - Restore Format Detection (P1)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir =
          await Directory.systemTemp.createTemp('orvia_restore_format_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('detects .isar and .db snapshot formats', () async {
      final isarFile = File(p.join(tempDir.path, 'backup.isar'));
      await isarFile.writeAsString('binary content');
      final type1 = await StorageBackupService.detectPayloadType(isarFile);
      expect(type1, equals(RestorePayloadType.isarSnapshot));

      final dbFile = File(p.join(tempDir.path, 'backup.db'));
      await dbFile.writeAsString('binary content');
      final type2 = await StorageBackupService.detectPayloadType(dbFile);
      expect(type2, equals(RestorePayloadType.isarSnapshot));
    });

    test('detects legacy full json backup format', () async {
      final jsonFile = File(p.join(tempDir.path, 'full_backup.json'));
      await jsonFile.writeAsString(
          '{"playlists": [], "media_items": [], "_meta": {}}');
      final type = await StorageBackupService.detectPayloadType(jsonFile);
      expect(type, equals(RestorePayloadType.legacyFullJson));
    });

    test('rejects unsupported arbitrary file formats', () async {
      final txtFile = File(p.join(tempDir.path, 'random.txt'));
      await txtFile.writeAsString('not a valid backup format');
      final type = await StorageBackupService.detectPayloadType(txtFile);
      expect(type, equals(RestorePayloadType.unsupported));
    });
  });

  group('DB Startup Protection - Recovery Screen UI (P1)', () {
    testWidgets('renders transient error UI with retry action',
        (tester) async {
      bool recovered = false;
      const error = DbInitError(
        type: DbInitErrorType.transientLock,
        message:
            'The database is currently locked by another Orvia process. Please close other Orvia instances and click Retry.',
        rawError: 'OS Error 32: sharing violation',
        dbPath: 'C:/mock/dbv3.isar',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DatabaseRecoveryScreen(
            error: error,
            onRecovered: () {
              recovered = true;
            },
          ),
        ),
      );

      expect(find.text('Database File is Busy or Locked'), findsOneWidget);
      expect(find.text('Retry Connection'), findsOneWidget);
      expect(find.text('Restore from Backup (.isar / .json)'), findsOneWidget);
      expect(find.text('Safely Archive & Start Fresh'), findsOneWidget);
      expect(recovered, isFalse);
    });

    testWidgets('renders corruption error UI with safety backup notice',
        (tester) async {
      const error = DbInitError(
        type: DbInitErrorType.corruption,
        message: 'The local database file appears corrupted or unreadable.',
        rawError: 'MDBX_CORRUPTED: bad magic',
        dbPath: 'C:/mock/dbv3.isar',
        quarantinedCopyPath: 'C:/mock/dbv3_corrupted_12345_99.isar',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DatabaseRecoveryScreen(
            error: error,
            onRecovered: () {},
          ),
        ),
      );

      expect(find.text('Database Startup Protection'), findsOneWidget);
      expect(find.text('Safety Backup Preserved'), findsOneWidget);
      expect(
        find.textContaining('C:/mock/dbv3_corrupted_12345_99.isar'),
        findsOneWidget,
      );
    });
  });
}
