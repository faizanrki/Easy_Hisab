import 'backup_record.dart';

abstract interface class BackupServicePort {
  /// Creates a local database snapshot and logs to backup_history.
  Future<BackupRecord> createBackup();

  /// Exports the entire database as a JSON snapshot string.
  Future<String> exportBackupJson();

  /// Restores the database from a JSON snapshot string.
  Future<void> restoreFromJson(String jsonString);

  /// Retrieves the history of backups created on this device.
  Future<List<BackupRecord>> getBackupHistory();

  /// Verifies SHA256 checksum integrity of backup bytes.
  bool verifyIntegrity(List<int> bytes, String expectedSha256);
}
