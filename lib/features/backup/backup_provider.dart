import 'package:flutter/foundation.dart';
import 'package:inventory_managment_sys/data/database/db_service.dart';
import 'package:inventory_managment_sys/data/repos/backup_repo.dart';
import '../../../core/utils/app_logger.dart';

class BackupProvider extends ChangeNotifier {
  BackupProvider(DatabaseService db) : _repo = BackupRepository(db);
  final BackupRepository _repo;

  List<BackupInfo> _backups = [];
  bool _loading = false;
  String? _error;
  String? _successMessage;

  List<BackupInfo> get backups => _backups;
  bool get loading => _loading;
  String? get error => _error;
  String? get successMessage => _successMessage;

  Future<void> loadBackups() async {
    _loading = true;
    notifyListeners();
    try {
      _backups = await _repo.listBackups();
    } catch (e) {
      _error = e.toString();
      appLogger.e('BackupProvider.loadBackups failed', error: e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> createBackup() async {
    _loading = true;
    _error = null;
    _successMessage = null;
    notifyListeners();
    try {
      final info = await _repo.createBackup();
      _successMessage = 'Backup created: ${info.fileName}';
      await loadBackups();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> restoreBackup(String path) async {
    _loading = true;
    _error = null;
    _successMessage = null;
    notifyListeners();
    try {
      await _repo.restoreBackup(path);
      _successMessage = 'Restore successful';
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    _error = null;
    _successMessage = null;
    notifyListeners();
  }
}
