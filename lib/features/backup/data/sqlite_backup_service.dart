import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../../../core/database/db_transaction.dart';
import '../../../core/domain/app_failure.dart';
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

  static const List<String> _backupTables = [
    'shops',
    'customers',
    'products',
    'sales',
    'sale_items',
    'payments',
    'payment_allocations',
    'customer_access_tokens',
    'app_settings',
  ];

  @override
  Future<String> exportBackupJson() async {
    final Map<String, dynamic> tablesData = {};
    for (final table in _backupTables) {
      try {
        final rows = await _db.executor.rawQuery('SELECT * FROM $table');
        tablesData[table] = rows;
      } catch (_) {
        tablesData[table] = [];
      }
    }

    final rawJson = jsonEncode(tablesData);
    final checksum = sha256.convert(utf8.encode(rawJson)).toString();

    final payload = {
      'schema_version': currentSchemaVersion,
      'app': 'EasyHisab',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'sha256': checksum,
      'tables': tablesData,
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  @override
  Future<void> restoreFromJson(String jsonString) async {
    final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw ValidationFailure('Invalid backup file format: $e');
    }

    final tables = parsed['tables'] as Map<String, dynamic>?;
    if (tables == null) {
      throw const ValidationFailure('Backup data missing tables payload');
    }

    await _db.executor.execute('PRAGMA foreign_keys = OFF');
    try {
      for (final table in _backupTables.reversed) {
        try {
          await _db.executor.execute('DELETE FROM $table');
        } catch (_) {}
      }

      for (final entry in tables.entries) {
        final tableName = entry.key;
        if (!_backupTables.contains(tableName)) continue;
        final rows = entry.value as List<dynamic>? ?? [];
        for (final row in rows) {
          if (row is Map<String, dynamic>) {
            await _db.executor.insert(tableName, row);
          }
        }
      }
    } finally {
      await _db.executor.execute('PRAGMA foreign_keys = ON');
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _db.executor.insert('backup_history', {
      'id': _idGen.newId(),
      'drive_file_id': null,
      'schema_version': currentSchemaVersion,
      'sha256': parsed['sha256'] as String?,
      'result': 'restored',
      'error': null,
      'created_at': nowMs,
    });
  }

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
