import '../domain/cloud_sync_remote_port.dart';

/// In-memory remote storage simulation for testing sync without live Firebase credentials.
class InMemoryCloudSyncRemote implements CloudSyncRemotePort {
  // key: "$shopId/$entityType/$entityId" -> data Map
  final Map<String, Map<String, dynamic>> _storage = {};

  bool simulateNetworkFailure = false;

  @override
  Future<void> uploadEntity({
    required String shopId,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> data,
  }) async {
    if (simulateNetworkFailure) {
      throw Exception('Simulated network timeout connecting to Cloud Firestore');
    }

    final key = '$shopId/$entityType/$entityId';
    final existing = _storage[key] ?? {};
    final merged = Map<String, dynamic>.from(existing)..addAll(data);
    merged['server_synced_at'] = DateTime.now().millisecondsSinceEpoch;
    _storage[key] = merged;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRemoteChanges({
    required String shopId,
    required String entityType,
    required int sinceTimestamp,
  }) async {
    if (simulateNetworkFailure) {
      throw Exception('Simulated network failure reading Cloud Firestore');
    }

    final prefix = '$shopId/$entityType/';
    final results = <Map<String, dynamic>>[];

    for (final entry in _storage.entries) {
      if (entry.key.startsWith(prefix)) {
        final serverTime = entry.value['server_synced_at'] as int? ?? 0;
        final updatedAt = entry.value['updated_at'] as int? ?? serverTime;
        if (updatedAt > sinceTimestamp) {
          results.add(Map<String, dynamic>.from(entry.value));
        }
      }
    }

    return results;
  }

  Map<String, dynamic>? getEntity({
    required String shopId,
    required String entityType,
    required String entityId,
  }) {
    return _storage['$shopId/$entityType/$entityId'];
  }

  void clear() => _storage.clear();
}
