import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../auth/presentation/auth_providers.dart';
import '../../../customers/customers_public.dart';
import '../../../products/products_public.dart';
import '../../../sales/presentation/sale_providers.dart';
import '../../../shop/shop_public.dart';
import '../backup_providers.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _isCreating = false;
  bool _isRestoring = false;
  String? _googleDriveAccount;

  @override
  void initState() {
    super.initState();
    _checkGoogleAccount();
  }

  void _checkGoogleAccount() {
    final user = ref.read(authServiceProvider).currentUser;
    if (user != null && user.email != null && user.email!.contains('@gmail.com')) {
      _googleDriveAccount = user.email;
    }
  }

  Future<void> _handleConnectGoogleDrive() async {
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId:
            '80143681231-qdjv369q92chcon90jkipdi51a2n6icv.apps.googleusercontent.com',
      );
      final account = await GoogleSignIn.instance.authenticate();
      setState(() {
        _googleDriveAccount = account.email;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Drive connected as ${account.email}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not connect Google Drive: $e')),
        );
      }
    }
  }

  Future<void> _handleCreateAndExportBackup() async {
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
          SnackBar(content: Text('Failed to export backup: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _shareBackupJson() async {
    try {
      final jsonString =
          await ref.read(backupHistoryProvider.notifier).exportBackup();
      await SharePlus.instance.share(
        ShareParams(
          text: jsonString,
          subject:
              'EasyHisab_Backup_${DateTime.now().millisecondsSinceEpoch}.json',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share backup: $e')),
        );
      }
    }
  }

  Future<void> _showRestoreDialog() async {
    final textController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Database Backup'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste the EasyHisab backup JSON snapshot below. All current records will be safely restored to the snapshot state.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'Paste backup JSON here...',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste_rounded),
                    tooltip: 'Paste from Clipboard',
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        textController.text = data!.text!;
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Restoring will update existing store data with the backup contents.',
                        style: TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore Now'),
          ),
        ],
      ),
    );

    if (confirmed == true && textController.text.trim().isNotEmpty) {
      setState(() => _isRestoring = true);
      try {
        await ref
            .read(backupHistoryProvider.notifier)
            .restoreBackup(textController.text.trim());

        // Invalidate active providers so all screens update immediately
        ref.invalidate(activeShopProvider);
        ref.invalidate(customerListProvider);
        ref.invalidate(productListProvider);
        ref.invalidate(recentSalesProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Database restored successfully from backup!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Restore failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isRestoring = false);
        }
      }
    }
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
              // Google Drive Cloud Backup Integration Card
              Card(
                elevation: 1,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cloud_sync_rounded,
                              size: 28, color: Color(0xFF1B5E20)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Google Drive Cloud Backup',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  _googleDriveAccount != null
                                      ? 'Connected: $_googleDriveAccount'
                                      : 'Connect your Google account for automatic cloud backups',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: _googleDriveAccount != null
                                        ? Colors.green.shade800
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontWeight: _googleDriveAccount != null
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_googleDriveAccount == null)
                        FilledButton.tonalIcon(
                          onPressed: _handleConnectGoogleDrive,
                          icon: const Icon(Icons.add_to_drive_rounded, size: 18),
                          label: const Text('Connect Google Drive'),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: _isCreating
                                    ? null
                                    : _handleCreateAndExportBackup,
                                icon: const Icon(Icons.cloud_upload_outlined,
                                    size: 18),
                                label: const Text('Backup to Drive'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    _isRestoring ? null : _showRestoreDialog,
                                icon: const Icon(
                                    Icons.cloud_download_outlined,
                                    size: 18),
                                label: const Text('Restore from Drive'),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Local Backup & Restore Action Bar
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed:
                          _isCreating ? null : _handleCreateAndExportBackup,
                      icon: _isCreating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.backup_rounded, size: 18),
                      label: const Text('Create Backup Now'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _isRestoring ? null : _showRestoreDialog,
                      icon: _isRestoring
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.restore_rounded, size: 18),
                      label: const Text('Restore Backup'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

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

                        final isRestored = record.result == 'restored';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isRestored
                                ? Colors.blue.shade100
                                : record.isSuccess
                                    ? theme.colorScheme.primaryContainer
                                    : theme.colorScheme.errorContainer,
                            child: Icon(
                              isRestored
                                  ? Icons.settings_backup_restore_rounded
                                  : record.isSuccess
                                      ? Icons.check_circle_outline
                                      : Icons.error_outline,
                              color: isRestored
                                  ? Colors.blue.shade900
                                  : record.isSuccess
                                      ? theme.colorScheme.onPrimaryContainer
                                      : theme.colorScheme.onErrorContainer,
                            ),
                          ),
                          title: Text(
                            formattedDate,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            isRestored
                                ? 'Database Restored from Snapshot'
                                : 'Schema v${record.schemaVersion} • SHA: $shaShort',
                          ),
                          trailing: isRestored
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.share_outlined),
                                  tooltip: 'Share Backup',
                                  onPressed: _shareBackupJson,
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
