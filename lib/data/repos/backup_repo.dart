import 'dart:io';
import 'package:inventory_managment_sys/core/utils/app_formatters.dart';
import 'package:inventory_managment_sys/data/database/db_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/app_logger.dart';

class BackupInfo {
  const BackupInfo({required this.path, required this.createdAt});
  final String path;
  final DateTime createdAt;
  String get fileName => p.basename(path);
}

class BackupRepository {
  BackupRepository(this._db);
  final DatabaseService _db;

  Future<Directory> _backupDir() async {
    final dir = await getApplicationSupportDirectory();
    final bdir = Directory(p.join(dir.path, AppConstants.backupFolder));
    if (!bdir.existsSync()) bdir.createSync(recursive: true);
    return bdir;
  }

  Future<BackupInfo> createBackup() async {
    try {
      final bdir = await _backupDir();
      final stamp = Fmt.backupTimestamp(DateTime.now());
      final dest = p.join(bdir.path, 'inventory_$stamp.db');
      final dbPath = await _db.dbPath;
      await File(dbPath).copy(dest);
      appLogger.i('Backup created: $dest');
      return BackupInfo(path: dest, createdAt: DateTime.now());
    } catch (e, st) {
      appLogger.e('Backup failed', error: e, stackTrace: st);
      throw DatabaseException('Backup failed', e);
    }
  }

  Future<List<BackupInfo>> listBackups() async {
    final bdir = await _backupDir();
    final files =
        bdir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.db'))
            .toList()
          ..sort((a, b) => b.path.compareTo(a.path));

    return files.map((f) {
      final stat = f.statSync();
      return BackupInfo(path: f.path, createdAt: stat.modified);
    }).toList();
  }

  Future<void> restoreBackup(String backupPath) async {
    try {
      final source = File(backupPath);
      if (!source.existsSync()) {
        throw const AppException('Backup file not found');
      }
      final dbPath = await _db.dbPath;
      await source.copy(dbPath);
      await _db.reopenFrom(dbPath);
      appLogger.i('Restored from: $backupPath');
    } catch (e, st) {
      appLogger.e('Restore failed', error: e, stackTrace: st);
      throw DatabaseException('Restore failed', e);
    }
  }
}
