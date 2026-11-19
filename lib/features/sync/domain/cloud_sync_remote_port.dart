/// Contract for talking to cloud storage (Firestore in prod, In-Memory in test).
abstract interface class CloudSyncRemotePort {
  /// Uploads or merges an entity document into the cloud backend.
  Future<void> uploadEntity({
    required String shopId,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> data,
  });

  /// Fetches entities modified in the cloud since [sinceTimestamp] ms.
  Future<List<Map<String, dynamic>>> fetchRemoteChanges({
    required String shopId,
    required String entityType,
    required int sinceTimestamp,
  });
}
