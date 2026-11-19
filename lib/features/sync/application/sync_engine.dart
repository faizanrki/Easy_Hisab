import 'dart:convert';
import '../../../core/database/db_transaction.dart';
import '../data/sqlite_sync_queue_repository.dart';
import '../domain/cloud_sync_remote_port.dart';
import '../domain/sync_operation.dart';

class SyncEngine {
  SyncEngine({
    required this.queueRepo,
    required this.remote,
    required this.db,
  });

  final SqliteSyncQueueRepository queueRepo;
  final CloudSyncRemotePort remote;
  final DatabaseTransactionPort db;

  int _lastSyncedAt = 0;
  int get lastSyncedAt => _lastSyncedAt;

  Future<int> pushPending(String shopId) async {
    final pending = await queueRepo.getPendingOperations(shopId);
    int successCount = 0;

    for (final op in pending) {
      await queueRepo.markInFlight(op.operationId);
      try {
        Map<String, dynamic> data = {};
        if (op.payload.isNotEmpty) {
          try {
            data = jsonDecode(op.payload) as Map<String, dynamic>;
          } catch (_) {
            data = {'raw_payload': op.payload};
          }
        }

        await remote.uploadEntity(
          shopId: op.shopId,
          entityType: op.entityType,
          entityId: op.entityId,
          data: data,
        );

        await queueRepo.markAccepted(op.operationId);
        successCount++;
      } catch (e) {
        await queueRepo.markFailed(op.operationId, e.toString());
      }
    }

    return successCount;
  }

  Future<int> pullRemote(String shopId) async {
    int pullCount = 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Pull customers
    final remoteCustomers = await remote.fetchRemoteChanges(
      shopId: shopId,
      entityType: 'customer',
      sinceTimestamp: _lastSyncedAt,
    );

    for (final c in remoteCustomers) {
      final id = c['id'] as String?;
      if (id == null) continue;

      final local = await db.executor.rawQuery(
        'SELECT updated_at FROM customers WHERE id = ? AND shop_id = ?',
        [id, shopId],
      );

      final remoteUpdated = c['updated_at'] as int? ?? 0;

      if (local.isEmpty) {
        await db.executor.insert('customers', {
          'id': id,
          'shop_id': shopId,
          'name': c['name'] ?? 'Customer',
          'name_search': (c['name'] as String? ?? '').toLowerCase(),
          'phone': c['phone'],
          'email': c['email'],
          'linked_auth_uid': c['linked_auth_uid'],
          'archived_at': c['archived_at'],
          'created_at': c['created_at'] ?? nowMs,
          'updated_at': remoteUpdated,
        });
        pullCount++;
      } else {
        final localUpdated = local.first['updated_at'] as int? ?? 0;
        // Last-Write-Wins (LWW) conflict resolution
        if (remoteUpdated > localUpdated) {
          await db.executor.rawUpdate(
            '''
            UPDATE customers
            SET name = ?, name_search = ?, phone = ?, email = ?, updated_at = ?
            WHERE id = ? AND shop_id = ?
            ''',
            [
              c['name'],
              (c['name'] as String? ?? '').toLowerCase(),
              c['phone'],
              c['email'],
              remoteUpdated,
              id,
              shopId,
            ],
          );
          pullCount++;
        }
      }
    }

    // Pull products
    final remoteProducts = await remote.fetchRemoteChanges(
      shopId: shopId,
      entityType: 'product',
      sinceTimestamp: _lastSyncedAt,
    );

    for (final p in remoteProducts) {
      final id = p['id'] as String?;
      if (id == null) continue;

      final local = await db.executor.rawQuery(
        'SELECT updated_at FROM products WHERE id = ? AND shop_id = ?',
        [id, shopId],
      );

      final remoteUpdated = p['updated_at'] as int? ?? 0;

      if (local.isEmpty) {
        await db.executor.insert('products', {
          'id': id,
          'shop_id': shopId,
          'name': p['name'] ?? 'Product',
          'name_search': (p['name'] as String? ?? '').toLowerCase(),
          'unit': p['unit'] ?? 'unit',
          'unit_price_paisa': p['unit_price_paisa'] ?? 0,
          'archived_at': p['archived_at'],
          'created_at': p['created_at'] ?? nowMs,
          'updated_at': remoteUpdated,
        });
        pullCount++;
      } else {
        final localUpdated = local.first['updated_at'] as int? ?? 0;
        if (remoteUpdated > localUpdated) {
          await db.executor.rawUpdate(
            '''
            UPDATE products
            SET name = ?, name_search = ?, unit = ?, unit_price_paisa = ?, updated_at = ?
            WHERE id = ? AND shop_id = ?
            ''',
            [
              p['name'],
              (p['name'] as String? ?? '').toLowerCase(),
              p['unit'],
              p['unit_price_paisa'],
              remoteUpdated,
              id,
              shopId,
            ],
          );
          pullCount++;
        }
      }
    }

    _lastSyncedAt = nowMs;
    return pullCount;
  }

  Future<SyncSummary> syncAll(String shopId) async {
    try {
      final pushed = await pushPending(shopId);
      final pulled = await pullRemote(shopId);
      return SyncSummary(pushedCount: pushed, pulledCount: pulled);
    } catch (e) {
      return SyncSummary(error: e.toString());
    }
  }
}
