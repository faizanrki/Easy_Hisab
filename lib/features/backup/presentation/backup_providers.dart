import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependency_providers.dart';
import '../data/sqlite_backup_service.dart';
import '../domain/backup_record.dart';
import '../domain/backup_service_port.dart';

final backupServiceProvider = Provider<BackupServicePort>((ref) {
  final db = ref.watch(dbTransactionProvider);
  final ids = ref.watch(idGeneratorProvider);
  return SqliteBackupService(db, ids);
});

class BackupHistoryNotifier extends AsyncNotifier<List<BackupRecord>> {
  @override
  Future<List<BackupRecord>> build() async {
    final service = ref.watch(backupServiceProvider);
    return service.getBackupHistory();
  }

  Future<BackupRecord> createBackup() async {
    final service = ref.read(backupServiceProvider);
    final record = await service.createBackup();
    // Refresh history
    state = AsyncValue.data(await service.getBackupHistory());
    return record;
  }

  Future<String> exportBackup() async {
    final service = ref.read(backupServiceProvider);
    return service.exportBackupJson();
  }

  Future<void> restoreBackup(String jsonString) async {
    final service = ref.read(backupServiceProvider);
    await service.restoreFromJson(jsonString);
    state = AsyncValue.data(await service.getBackupHistory());
  }
}

final backupHistoryProvider =
    AsyncNotifierProvider<BackupHistoryNotifier, List<BackupRecord>>(
  BackupHistoryNotifier.new,
);
