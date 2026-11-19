import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependency_providers.dart';
import '../../shop/presentation/shop_providers.dart';
import '../application/sync_engine.dart';
import '../data/in_memory_cloud_sync_remote.dart';
import '../data/sqlite_sync_queue_repository.dart';
import '../domain/cloud_sync_remote_port.dart';
import '../domain/sync_operation.dart';

/// The remote cloud interface. Defaults to [InMemoryCloudSyncRemote] for offline/testing.
final cloudSyncRemoteProvider = Provider<CloudSyncRemotePort>((ref) {
  return InMemoryCloudSyncRemote();
});

final syncQueueRepositoryProvider = Provider<SqliteSyncQueueRepository>((ref) {
  final db = ref.watch(dbTransactionProvider);
  return SqliteSyncQueueRepository(db);
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final queueRepo = ref.watch(syncQueueRepositoryProvider);
  final remote = ref.watch(cloudSyncRemoteProvider);
  final db = ref.watch(dbTransactionProvider);
  return SyncEngine(queueRepo: queueRepo, remote: remote, db: db);
});

class SyncStatusNotifier extends Notifier<SyncState> {
  @override
  SyncState build() => SyncState.idle;

  Future<SyncSummary> triggerSync(String shopId) async {
    state = SyncState.syncing;
    try {
      final engine = ref.read(syncEngineProvider);
      final summary = await engine.syncAll(shopId);
      state = summary.isSuccess ? SyncState.idle : SyncState.error;
      await ref.read(pendingSyncCountProvider.notifier).reload();
      return summary;
    } catch (_) {
      state = SyncState.error;
      rethrow;
    }
  }
}

final syncStatusProvider =
    NotifierProvider<SyncStatusNotifier, SyncState>(SyncStatusNotifier.new);

class PendingSyncCountNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final activeShop = ref.watch(activeShopContextProvider);
    if (activeShop == null) return 0;
    final repo = ref.watch(syncQueueRepositoryProvider);
    return repo.getPendingCount(activeShop.shopId);
  }

  Future<void> reload() async {
    final activeShop = ref.read(activeShopContextProvider);
    if (activeShop == null) {
      state = const AsyncValue.data(0);
      return;
    }
    final repo = ref.read(syncQueueRepositoryProvider);
    final count = await repo.getPendingCount(activeShop.shopId);
    state = AsyncValue.data(count);
  }
}

final pendingSyncCountProvider =
    AsyncNotifierProvider<PendingSyncCountNotifier, int>(
  PendingSyncCountNotifier.new,
);
