import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:easy_hisab/core/database/local_database.dart';
import 'package:easy_hisab/core/domain/entity_id.dart';
import 'package:easy_hisab/features/backup/data/sqlite_backup_service.dart';

void main() {
  sqfliteFfiInit();

  group('Module 12: SqliteBackupService Unit Tests', () {
    late LocalDatabase db;
    late SqliteBackupService backupService;
    const idGen = UuidIdGenerator();

    setUp(() async {
      db = await LocalDatabase.openAt(
        inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      backupService = SqliteBackupService(db, idGen);
    });

    tearDown(() => db.close());

    test('createBackup creates valid snapshot and logs to backup_history', () async {
      final record = await backupService.createBackup();

      expect(record.isSuccess, isTrue);
      expect(record.schemaVersion, 1);
      expect(record.sha256, isNotNull);
      expect(record.sha256!.length, 64); // SHA-256 hex string length

      // Verify row in database
      final rows = await db.executor.rawQuery(
        'SELECT * FROM backup_history WHERE id = ?',
        [record.id],
      );
      expect(rows.length, 1);
      expect(rows.first['result'], 'success');
      expect(rows.first['schema_version'], 1);
      expect(rows.first['sha256'], record.sha256);
    });

    test('getBackupHistory returns descending list of backups', () async {
      await backupService.createBackup();
      await backupService.createBackup();

      final history = await backupService.getBackupHistory();
      expect(history.length, 2);
      expect(history.every((r) => r.isSuccess), isTrue);
    });

    test('verifyIntegrity verifies identical bytes and detects tampering', () {
      final original = utf8.encode('easy_hisab_safe_snapshot_123');
      final expectedSha256 = sha256.convert(original).toString();

      final matches = backupService.verifyIntegrity(original, expectedSha256);
      expect(matches, isTrue);

      final tampered = utf8.encode('tampered_content');
      final tamperedMatches = backupService.verifyIntegrity(tampered, expectedSha256);
      expect(tamperedMatches, isFalse);
    });
  });
}
