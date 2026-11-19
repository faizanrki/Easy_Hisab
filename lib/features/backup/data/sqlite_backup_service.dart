import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../../../core/database/db_transaction.dart';
import '../../../core/domain/entity_id.dart';
import '../domain/backup_record.dart';
import '../domain/backup_service_port.dart';

class SqliteBackupService implements BackupServicePort {
  const SqliteBackupService(
    this._db, [
    this._idGen = const UuidIdGenerator(),
  ]);

  final DatabaseTransactionPort _db;
  final IdGenerator _idGen;

  static const int currentSchemaVersion = 1;

  @override
  Future<BackupRecord> createBackup() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final backupId = _idGen.newId();

    try {
      // Dump tables snapshot to compute SHA256 integrity hash
      final tables = [
        'shops',
        'customers',
        'products',
        'sales',
        'sale_items',
        'payments',
        'payment_allocations',
      ];

      final buffer = StringBuffer();
      for (final t in tables) {
        final rows = await _db.executor.rawQuery('SELECT * FROM $t ORDER BY 1');
        buffer.write(jsonEncode(rows));
      }

      final bytes = utf8.encode(buffer.toString());
      final digest = sha256.convert(bytes);
      final sha256Hex = digest.toString();

      await _db.executor.insert('backup_history', {
        'id': backupId,
        'drive_file_id': null,
        'schema_version': currentSchemaVersion,
        'sha256': sha256Hex,
        'result': 'success',
        'error': null,
        'created_at': nowMs,
      });

      return BackupRecord(
        id: backupId,
        schemaVersion: currentSchemaVersion,
        sha256: sha256Hex,
        result: 'success',
        createdAt: DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
      );
    } catch (e) {
      await _db.executor.insert('backup_history', {
        'id': backupId,
        'drive_file_id': null,
        'schema_version': currentSchemaVersion,
        'sha256': null,
        'result': 'failed',
        'error': e.toString(),
        'created_at': nowMs,
      });

      return BackupRecord(
        id: backupId,
        schemaVersion: currentSchemaVersion,
        result: 'failed',
        error: e.toString(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
      );
    }
  }

  @override
  Future<List<BackupRecord>> getBackupHistory() async {
    final rows = await _db.executor.rawQuery(
      '''
      SELECT * FROM backup_history
      ORDER BY created_at DESC
      ''',
    );

    return rows.map((r) {
      final createdAtMs = r['created_at'] as int;
      return BackupRecord(
        id: r['id'] as String,
        driveFileId: r['drive_file_id'] as String?,
        schemaVersion: r['schema_version'] as int,
        sha256: r['sha256'] as String?,
        result: r['result'] as String,
        error: r['error'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs, isUtc: true),
      );
    }).toList();
  }

  @override
  bool verifyIntegrity(List<int> bytes, String expectedSha256) {
    final digest = sha256.convert(bytes);
    return digest.toString().toLowerCase() == expectedSha256.toLowerCase();
  }
}
