class BackupRecord {
  const BackupRecord({
    required this.id,
    this.driveFileId,
    required this.schemaVersion,
    this.sha256,
    required this.result, // 'success' or 'failed'
    this.error,
    required this.createdAt,
  });

  final String id;
  final String? driveFileId;
  final int schemaVersion;
  final String? sha256;
  final String result;
  final String? error;
  final DateTime createdAt;

  bool get isSuccess => result == 'success';
}
