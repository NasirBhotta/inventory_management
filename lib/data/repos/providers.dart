import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:inventory_managment_sys/data/database/db_service.dart';
import 'package:inventory_managment_sys/data/repos/backup_repo.dart';
import 'package:inventory_managment_sys/data/repos/debt_repo.dart';
import 'package:inventory_managment_sys/data/repos/purchase_repo.dart';
import 'package:inventory_managment_sys/data/repos/quotation_repo.dart';
import 'package:inventory_managment_sys/data/repos/product_repo.dart';
import 'package:inventory_managment_sys/data/repos/sale_repo.dart';
import 'package:inventory_managment_sys/data/repos/stock_repo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;

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

final purchaseRepoProvider = Provider<PurchaseOrderRepository>((ref) {
  return PurchaseOrderRepository(ref.watch(dbServiceProvider));
});

final quotationRepoProvider = Provider<QuotationRepository>((ref) {
  return QuotationRepository(ref.watch(dbServiceProvider));
});

final debtRepoProvider = Provider<DebtRepository>((ref) {
  return DebtRepository(ref.watch(dbServiceProvider));
});

