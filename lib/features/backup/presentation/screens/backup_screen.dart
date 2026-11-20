import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../auth/presentation/auth_providers.dart';
import '../../../customers/customers_public.dart';
import '../../../products/products_public.dart';
import '../../../sales/presentation/sale_providers.dart';
import '../../../shop/shop_public.dart';
import '../../data/google_drive_backup_service.dart';
import '../backup_providers.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _driveService = GoogleDriveBackupService();
  bool _isCreating = false;
  bool _isRestoring = false;
  bool _isDriveBusy = false;
  String? _googleDriveAccount;
  DateTime? _lastDriveSyncAt;

  @override
  void initState() {
    super.initState();
    _checkGoogleAccount();
  }

  void _checkGoogleAccount() {
    final user = ref.read(authServiceProvider).currentUser;
    if (user != null &&
        user.email != null &&
        user.email!.toLowerCase().contains('gmail.com')) {
      _googleDriveAccount = user.email;
    }
  }

  Future<void> _handleConnectGoogleDrive() async {
    setState(() => _isDriveBusy = true);
    try {
      final auth = await _driveService.connectAndAuthorize(interactive: true);
      setState(() {
        _googleDriveAccount = auth.email;
      });

      // Automatically create and upload backup to Google Drive on connect.
      final record =
          await ref.read(backupHistoryProvider.notifier).createBackup();
      if (record.isSuccess) {
        final jsonString =
            await ref.read(backupHistoryProvider.notifier).exportBackup();
        final uploadedAt = await _driveService.uploadBackup(
          jsonContent: jsonString,
          headers: auth.headers,
        );
        if (mounted) {
          setState(() => _lastDriveSyncAt = uploadedAt);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Google Drive connected (${auth.email}) & automatic backup saved!',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not connect/backup to Google Drive: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDriveBusy = false);
      }
    }
  }

  Future<void> _handleBackupToDrive() async {
    setState(() {
      _isDriveBusy = true;
      _isCreating = true;
    });
    try {
      final auth = await _driveService.connectAndAuthorize(interactive: true);
      final record =
          await ref.read(backupHistoryProvider.notifier).createBackup();
      if (!record.isSuccess) {
        throw StateError(record.error ?? 'Local snapshot failed');
      }
      final jsonString =
          await ref.read(backupHistoryProvider.notifier).exportBackup();
      final uploadedAt = await _driveService.uploadBackup(
        jsonContent: jsonString,
        headers: auth.headers,
      );
      if (mounted) {
        setState(() {
          _googleDriveAccount = auth.email;
          _lastDriveSyncAt = uploadedAt;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup automatically uploaded to Drive (${auth.email})!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Drive backup failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDriveBusy = false;
          _isCreating = false;
        });
      }
    }
  }

  Future<void> _handleRestoreFromDrive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from Google Drive?'),
        content: const Text(
          'EasyHisab will automatically fetch your latest backup from Google Drive and restore your shops, customers, products, and udhar records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.cloud_download_rounded, size: 18),
            label: const Text('Restore Automatically'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDriveBusy = true;
      _isRestoring = true;
    });
    try {
      final auth = await _driveService.connectAndAuthorize(interactive: true);
      final jsonString =
          await _driveService.downloadLatestBackup(auth.headers);

      await ref.read(backupHistoryProvider.notifier).restoreBackup(jsonString);

      ref.invalidate(activeShopProvider);
      ref.invalidate(customerListProvider);
      ref.invalidate(productListProvider);
      ref.invalidate(recentSalesProvider);

      if (mounted) {
        setState(() => _googleDriveAccount = auth.email);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data automatically restored from Google Drive!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Drive restore failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDriveBusy = false;
          _isRestoring = false;
        });
      }
    }
  }

  Future<void> _handleCreateLocalBackup() async {
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

  Future<void> _handleBackupTapRestore(String formattedDate) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: Text(
          'Choose how you want to restore your store data (snapshot from $formattedDate):',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'json'),
            icon: const Icon(Icons.code_rounded, size: 18),
            label: const Text('Local JSON'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, 'drive'),
            icon: const Icon(Icons.cloud_download_rounded, size: 18),
            label: const Text('Google Drive'),
          ),
        ],
      ),
    );

    if (choice == 'drive') {
      await _executeDriveRestore();
    } else if (choice == 'json') {
      await _showLocalJsonRestoreDialog();
    }
  }

  Future<void> _showLocalJsonRestoreDialog() async {
    final textController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from Local JSON'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste the EasyHisab backup JSON snapshot below. All current records will be restored to the snapshot state.',
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

        ref.invalidate(activeShopProvider);
        ref.invalidate(customerListProvider);
        ref.invalidate(productListProvider);
        ref.invalidate(recentSalesProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Database restored successfully from JSON backup!'),
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

  Future<void> _executeDriveRestore() async {
    setState(() {
      _isDriveBusy = true;
      _isRestoring = true;
    });
    try {
      final auth = await _driveService.connectAndAuthorize(interactive: true);
      final jsonString =
          await _driveService.downloadLatestBackup(auth.headers);

      await ref.read(backupHistoryProvider.notifier).restoreBackup(jsonString);

      ref.invalidate(activeShopProvider);
      ref.invalidate(customerListProvider);
      ref.invalidate(productListProvider);
      ref.invalidate(recentSalesProvider);

      if (mounted) {
        setState(() => _googleDriveAccount = auth.email);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data automatically restored from Google Drive!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Drive restore failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDriveBusy = false;
          _isRestoring = false;
        });
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
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B5E20)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.cloud_sync_rounded,
                              size: 26,
                              color: Color(0xFF1B5E20),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Google Drive Auto Backup',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  _googleDriveAccount != null
                                      ? 'Connected: $_googleDriveAccount'
                                      : 'Connect Google Drive to auto-save & auto-restore backups',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: _googleDriveAccount != null
                                        ? Colors.green.shade800
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontWeight: _googleDriveAccount != null
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                                if (_lastDriveSyncAt != null)
                                  Text(
                                    'Last Drive sync: ${DateFormat('dd MMM, hh:mm a').format(_lastDriveSyncAt!)}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_googleDriveAccount == null)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            onPressed:
                                _isDriveBusy ? null : _handleConnectGoogleDrive,
                            icon: _isDriveBusy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.add_to_drive_rounded,
                                    size: 18),
                            label: Text(
                              _isDriveBusy
                                  ? 'Connecting & Backing Up...'
                                  : 'Connect Google Drive',
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: _isDriveBusy
                                    ? null
                                    : _handleBackupToDrive,
                                icon: _isDriveBusy && _isCreating
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.cloud_upload_outlined,
                                        size: 18),
                                label: const Text('Backup to Drive'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isDriveBusy
                                    ? null
                                    : _handleRestoreFromDrive,
                                icon: _isDriveBusy && _isRestoring
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.cloud_download_outlined,
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
                          _isCreating ? null : _handleCreateLocalBackup,
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
                      onPressed:
                          _isRestoring ? null : _showLocalJsonRestoreDialog,
                      icon: _isRestoring
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.restore_rounded, size: 18),
                      label: const Text('Restore JSON'),
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
                          onTap: isRestored || _isRestoring
                              ? null
                              : () => _handleBackupTapRestore(formattedDate),
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
                                : 'Tap to restore • Schema v${record.schemaVersion} • SHA: $shaShort',
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
