import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/models/product.dart';
import '../../../data/repos/providers.dart';

part 'dashboard_provider.g.dart';

class DashboardStats {
  const DashboardStats({
    required this.totalProducts,
    required this.totalUnits,
    required this.totalValue,
    required this.lowStockCount,
    required this.todaySales,
    required this.monthSales,
    required this.outstandingDebt,
    required this.lowStockItems,
    required this.totalProfitToday,
    required this.totalProfit14Days,
  });

  final int totalProducts;
  final double totalUnits;
  final double totalValue;
  final int lowStockCount;
  final double todaySales;
  final double monthSales;
  final double outstandingDebt;
  final List<Product> lowStockItems;
  final double totalProfitToday;
  final double totalProfit14Days;
}

@riverpod
Future<DashboardStats> dashboard(DashboardRef ref) async {
  final products = await ref.watch(productRepoProvider).getAll();
  final salesRepo = ref.watch(saleRepoProvider);
  final sales = await salesRepo.getSummary();
  final outstandingDebt = await ref.watch(debtRepoProvider).getOutstandingTotal();
  final lowStock = products.where((p) => p.isLowStock).toList();
  final now = DateTime.now();
  final last14DaysStart = now.subtract(const Duration(days: 13));

  return DashboardStats(
    totalProducts: products.length,
    totalUnits: products.fold(0.0, (s, p) => s + p.quantity),
    totalValue: products.fold(0.0, (s, p) => s + p.totalValue),
    lowStockCount: lowStock.length,
    todaySales: sales['today'] ?? 0,
    monthSales: sales['month'] ?? 0,
    outstandingDebt: outstandingDebt,
    lowStockItems: lowStock,
    totalProfitToday: await salesRepo.getTotalProfitToday(),
    totalProfit14Days: await salesRepo.getTotalProfitByDateRange(last14DaysStart, now),
  );
}
