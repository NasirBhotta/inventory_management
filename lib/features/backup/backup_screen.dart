import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventory_managment_sys/core/errors/app_exceptions.dart';
import 'package:inventory_managment_sys/core/widgets/section_header.dart';
import 'package:inventory_managment_sys/data/database/db_service.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});
  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _loading = false;
  List<Map<String, Object?>> _backups = [];

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    final list = await DatabaseService.instance.listBackups();
    setState(() => _backups = list);
  }

  Future<void> _createBackup() async {
    setState(() => _loading = true);
    try {
      final path = await DatabaseService.instance.backup();
      _showSnack('Backup created:\n$path');
      _loadBackups();
    } on AppException catch (e) {
      _showSnack(e.message, error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _restore() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Restore Backup'),
            content: const Text(
              'This will overwrite current data with the latest backup. Are you sure?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Restore'),
              ),
            ],
          ),
    );
    if (ok != true) return;
    setState(() => _loading = true);
    try {
      final path = await DatabaseService.instance.restoreLatest();
      _showSnack('Restored from:\n$path');
    } on AppException catch (e) {
      _showSnack(e.message, error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Backup & Restore',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _loading ? null : _createBackup,
                icon:
                    _loading
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.backup),
                label: const Text('Create Backup'),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: (_loading || _backups.isEmpty) ? null : _restore,
                icon: const Icon(Icons.restore),
                label: const Text('Restore Latest'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SectionHeader(title: 'Backup Files (${_backups.length})'),
          Expanded(
            child:
                _backups.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off,
                            size: 64,
                            color: cs.onSurfaceVariant.withOpacity(0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No backups yet',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                    : ListView.separated(
                      itemCount: _backups.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final b = _backups[i];
                        final path = b['path'] as String;
                        final size = b['size'] as int;
                        final fileName =
                            path.split(Platform.pathSeparator).last;
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.storage,
                              color: cs.primary,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            fileName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            path,
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            '${(size / 1024).toStringAsFixed(1)} KB',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
