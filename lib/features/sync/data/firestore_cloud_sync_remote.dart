import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/cloud_sync_remote_port.dart';

class FirestoreCloudSyncRemote implements CloudSyncRemotePort {
  FirestoreCloudSyncRemote([FirebaseFirestore? firestore])
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String _collectionName(String entityType) {
    switch (entityType) {
      case 'shop':
        return 'shops';
      case 'customer':
        return 'customers';
      case 'product':
        return 'products';
      case 'sale':
        return 'sales';
      case 'payment':
        return 'payments';
      case 'customer_link':
        return 'customer_links';
      default:
        return '${entityType}s';
    }
  }

  @override
  Future<void> uploadEntity({
    required String shopId,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> data,
  }) async {
    final col = _collectionName(entityType);
    final docRef = _firestore
        .collection('shops')
        .doc(shopId)
        .collection(col)
        .doc(entityId);

    final payload = Map<String, dynamic>.from(data)
      ..['server_synced_at'] = FieldValue.serverTimestamp();

    await docRef.set(payload, SetOptions(merge: true));
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRemoteChanges({
    required String shopId,
    required String entityType,
    required int sinceTimestamp,
  }) async {
    final col = _collectionName(entityType);
    final querySnap = await _firestore
        .collection('shops')
        .doc(shopId)
        .collection(col)
        .where('updated_at', isGreaterThan: sinceTimestamp)
        .get();

    return querySnap.docs.map((d) => d.data()).toList();
  }
}
