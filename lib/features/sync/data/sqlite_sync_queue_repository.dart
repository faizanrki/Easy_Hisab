import '../../../core/database/db_transaction.dart';
import '../domain/sync_operation.dart';

class SqliteSyncQueueRepository {
  const SqliteSyncQueueRepository(this._db);

  final DatabaseTransactionPort _db;

  Future<List<SyncOperation>> getPendingOperations(
    String shopId, {
    int limit = 50,
  }) async {
    final rows = await _db.executor.rawQuery(
      '''
      SELECT * FROM sync_queue
      WHERE shop_id = ? AND sync_status IN ('pending', 'retryable_failed') AND attempts < 5
      ORDER BY created_at ASC
      LIMIT ?
      ''',
      [shopId, limit],
    );

    return rows.map((r) {
      final createdAtMs = r['created_at'] as int;
      final updatedAtMs = r['updated_at'] as int? ?? createdAtMs;
      return SyncOperation(
        operationId: r['operation_id'] as String,
        shopId: r['shop_id'] as String,
        entityType: r['entity_type'] as String,
        entityId: r['entity_id'] as String,
        operation: r['operation'] as String,
        payload: r['payload'] as String,
        syncStatus: r['sync_status'] as String,
        attempts: r['attempts'] as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs, isUtc: true),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs, isUtc: true),
        lastError: r['last_error'] as String?,
      );
    }).toList();
  }

  Future<void> markInFlight(String operationId) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _db.executor.rawUpdate(
      '''
      UPDATE sync_queue
      SET sync_status = 'in_flight', attempts = attempts + 1, updated_at = ?
      WHERE operation_id = ?
      ''',
      [nowMs, operationId],
    );
  }

  Future<void> markAccepted(String operationId) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _db.executor.rawUpdate(
      '''
      UPDATE sync_queue
      SET sync_status = 'accepted', updated_at = ?
      WHERE operation_id = ?
      ''',
      [nowMs, operationId],
    );
  }

  Future<void> markFailed(String operationId, String error) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _db.executor.rawUpdate(
      '''
      UPDATE sync_queue
      SET sync_status = 'retryable_failed', last_error = ?, updated_at = ?
      WHERE operation_id = ?
      ''',
      [error, nowMs, operationId],
    );
  }

  Future<int> getPendingCount(String shopId) async {
    final res = await _db.executor.rawQuery(
      '''
      SELECT COUNT(*) as cnt FROM sync_queue
      WHERE shop_id = ? AND sync_status IN ('pending', 'in_flight', 'retryable_failed')
      ''',
      [shopId],
    );
    return (res.first['cnt'] as num?)?.toInt() ?? 0;
  }
}
