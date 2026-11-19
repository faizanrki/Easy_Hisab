import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:easy_hisab/core/database/local_database.dart';
import 'package:easy_hisab/features/sync/application/sync_engine.dart';
import 'package:easy_hisab/features/sync/data/in_memory_cloud_sync_remote.dart';
import 'package:easy_hisab/features/sync/data/sqlite_sync_queue_repository.dart';

void main() {
  sqfliteFfiInit();

  group('Module 10: Sync Engine Unit Tests', () {
    late LocalDatabase db;
    late SqliteSyncQueueRepository queueRepo;
    late InMemoryCloudSyncRemote remote;
    late SyncEngine engine;
    const shopId = 'shop_123';

    setUp(() async {
      db = await LocalDatabase.openAt(
        inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      queueRepo = SqliteSyncQueueRepository(db);
      remote = InMemoryCloudSyncRemote();
      engine = SyncEngine(queueRepo: queueRepo, remote: remote, db: db);

      // Seed shop
      const nowMs = 1763560000000;
      await db.executor.insert('shops', {
        'id': shopId,
        'name': 'Lahore Kiryana Store',
        'contact_phone': '03001234567',
        'address': 'Main Bazar',
        'created_at': nowMs,
        'updated_at': nowMs,
      });
    });

    tearDown(() => db.close());

    test('pushPending uploads outbox items to remote and marks done', () async {
      const nowMs = 1763560000000;
      final customerData = {
        'id': 'cust_1',
        'shop_id': shopId,
        'name': 'Ali Raza',
        'phone': '03009988776',
      };

      // Queue an insert operation in sync_queue
      await db.executor.insert('sync_queue', {
        'operation_id': 'op_1',
        'shop_id': shopId,
        'entity_type': 'customer',
        'entity_id': 'cust_1',
        'operation': 'insert',
        'payload': jsonEncode(customerData),
        'sync_status': 'pending',
        'attempts': 0,
        'created_at': nowMs,
        'updated_at': nowMs,
      });

      expect(await queueRepo.getPendingCount(shopId), 1);

      // Push pending
      final pushed = await engine.pushPending(shopId);
      expect(pushed, 1);

      // Verify remote received document
      final remoteDoc = remote.getEntity(
        shopId: shopId,
        entityType: 'customer',
        entityId: 'cust_1',
      );
      expect(remoteDoc, isNotNull);
      expect(remoteDoc?['name'], 'Ali Raza');

      // Verify status in SQLite is now accepted
      final row = await db.executor.rawQuery(
        'SELECT sync_status FROM sync_queue WHERE operation_id = ?',
        ['op_1'],
      );
      expect(row.first['sync_status'], 'accepted');
      expect(await queueRepo.getPendingCount(shopId), 0);
    });

    test('pushPending marks failed on network error and does not drop row', () async {
      const nowMs = 1763560000000;
      remote.simulateNetworkFailure = true;

      await db.executor.insert('sync_queue', {
        'operation_id': 'op_fail',
        'shop_id': shopId,
        'entity_type': 'product',
        'entity_id': 'prod_1',
        'operation': 'insert',
        'payload': jsonEncode({'id': 'prod_1', 'name': 'Milk'}),
        'sync_status': 'pending',
        'attempts': 0,
        'created_at': nowMs,
        'updated_at': nowMs,
      });

      final pushed = await engine.pushPending(shopId);
      expect(pushed, 0);

      final row = await db.executor.rawQuery(
        'SELECT sync_status, attempts, last_error FROM sync_queue WHERE operation_id = ?',
        ['op_fail'],
      );
      expect(row.first['sync_status'], 'retryable_failed');
      expect(row.first['attempts'], 1);
      expect(row.first['last_error'], isNotNull);
    });

    test('pullRemote applies remote additions to local SQLite', () async {
      await remote.uploadEntity(
        shopId: shopId,
        entityType: 'product',
        entityId: 'prod_remote_1',
        data: {
          'id': 'prod_remote_1',
          'name': 'Tapal Danedar Tea 950g',
          'unit': 'pack',
          'unit_price_paisa': 145000,
          'updated_at': 1763570000000,
        },
      );

      final pulled = await engine.pullRemote(shopId);
      expect(pulled, 1);

      final localRows = await db.executor.rawQuery(
        'SELECT * FROM products WHERE id = ?',
        ['prod_remote_1'],
      );
      expect(localRows.length, 1);
      expect(localRows.first['name'], 'Tapal Danedar Tea 950g');
      expect(localRows.first['unit_price_paisa'], 145000);
    });

    test('pullRemote resolves conflicts using Last-Write-Wins (LWW)', () async {
      // Local product: older timestamp
      await db.executor.insert('products', {
        'id': 'prod_conflict',
        'shop_id': shopId,
        'name': 'Old Name',
        'name_search': 'old name',
        'unit': 'kg',
        'unit_price_paisa': 10000,
        'created_at': 1763560000000,
        'updated_at': 1763560000000,
      });

      // Remote product: newer timestamp
      await remote.uploadEntity(
        shopId: shopId,
        entityType: 'product',
        entityId: 'prod_conflict',
        data: {
          'id': 'prod_conflict',
          'name': 'New Updated Name',
          'unit': 'kg',
          'unit_price_paisa': 12000,
          'updated_at': 1763580000000, // Newer than local
        },
      );

      final pulled = await engine.pullRemote(shopId);
      expect(pulled, 1);

      final updatedLocal = await db.executor.rawQuery(
        'SELECT name, unit_price_paisa FROM products WHERE id = ?',
        ['prod_conflict'],
      );
      expect(updatedLocal.first['name'], 'New Updated Name');
      expect(updatedLocal.first['unit_price_paisa'], 12000);
    });
  });
}
