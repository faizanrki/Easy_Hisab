/// Represents a queued local change waiting to sync to the cloud.
class SyncOperation {
  const SyncOperation({
    required this.operationId,
    required this.shopId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.syncStatus,
    required this.attempts,
    required this.createdAt,
    required this.updatedAt,
    this.lastError,
  });

  final String operationId;
  final String shopId;
  final String entityType; // 'shop','customer','product','sale','payment','customer_link','reminder'
  final String entityId;
  final String operation; // 'insert','update','status_change'
  final String payload;
  final String syncStatus; // 'pending','in_flight','accepted','retryable_failed','rejected'
  final int attempts;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastError;

  bool get isPending => syncStatus == 'pending';
  bool get isAccepted => syncStatus == 'accepted';
}

enum SyncState {
  idle,
  syncing,
  offline,
  error,
}

class SyncSummary {
  const SyncSummary({
    this.pushedCount = 0,
    this.pulledCount = 0,
    this.failedCount = 0,
    this.error,
  });

  final int pushedCount;
  final int pulledCount;
  final int failedCount;
  final String? error;

  bool get isSuccess => error == null && failedCount == 0;
}
