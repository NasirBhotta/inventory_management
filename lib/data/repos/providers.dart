import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:inventory_managment_sys/data/database/db_service.dart';
import 'package:inventory_managment_sys/data/repos/backup_repo.dart';
import 'package:inventory_managment_sys/data/repos/product_repo.dart';
import 'package:inventory_managment_sys/data/repos/sale_repo.dart';
import 'package:inventory_managment_sys/data/repos/stock_repo.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
DatabaseService dbService(DbServiceRef ref) {
  return DatabaseService.instance;
}

@Riverpod(keepAlive: true)
ProductRepository productRepo(ProductRepoRef ref) {
  return ProductRepository(ref.watch(dbServiceProvider));
}

@Riverpod(keepAlive: true)
SalesRepository saleRepo(SaleRepoRef ref) {
  return SalesRepository(ref.watch(dbServiceProvider));
}

@Riverpod(keepAlive: true)
StockRepository stockRepo(StockRepoRef ref) {
  return StockRepository(ref.watch(dbServiceProvider));
}

@Riverpod(keepAlive: true)
BackupRepository backupRepo(BackupRepoRef ref) {
  return BackupRepository(ref.watch(dbServiceProvider));
}
