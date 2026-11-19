import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../backup_providers.dart';
import '../../domain/backup_record.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _isCreating = false;

  Future<void> _handleCreateBackup() async {
    setState(() => _isCreating = true);
    try {
      final record =
          await ref.read(backupHistoryProvider.notifier).createBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              record.isSuccess
                  ? 'Backup created successfully! SHA256: ${record.sha256?.substring(0, 8)}...'
                  : 'Backup failed: ${record.error}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create backup: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  void _shareBackup(BackupRecord record) {
    final text = 'EasyHisab Backup Snapshot\n'
        'Backup ID: ${record.id}\n'
        'Schema Version: v${record.schemaVersion}\n'
        'Created: ${record.createdAt.toIso8601String()}\n'
        'SHA256 Checksum: ${record.sha256 ?? "N/A"}';
    // ignore: deprecated_member_use
    Share.share(text, subject: 'EasyHisab Backup ${record.id}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(backupHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Backup & Restore'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.backup_rounded,
                        size: 40,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Offline Data Safety',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Create encrypted SQLite snapshots with SHA256 integrity validation.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Create Backup Action Button
              FilledButton.icon(
                onPressed: _isCreating ? null : _handleCreateBackup,
                icon: _isCreating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_circle_outline),
                label: const Text('Create Backup Now'),
              ),
              const SizedBox(height: 24),

              Text(
                'Backup History',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: historyAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Text('Error loading history: $err'),
                  ),
                  data: (history) {
                    if (history.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 48,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(height: 12),
                            const Text('No backups created yet.'),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: history.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final record = history[index];
                        final formattedDate =
                            DateFormat('dd MMM yyyy, hh:mm a')
                                .format(record.createdAt);
                        final shaShort = record.sha256 != null &&
                                record.sha256!.length > 12
                            ? '${record.sha256!.substring(0, 12)}...'
                            : record.sha256 ?? 'None';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: record.isSuccess
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.errorContainer,
                            child: Icon(
                              record.isSuccess
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              color: record.isSuccess
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onErrorContainer,
                            ),
                          ),
                          title: Text(
                            formattedDate,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Schema v${record.schemaVersion} • SHA: $shaShort',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.share_outlined),
                            tooltip: 'Share Backup Info',
                            onPressed: () => _shareBackup(record),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
