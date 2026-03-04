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
    required this.lowStockItems,
  });
  final int totalProducts;
  final int totalUnits;
  final double totalValue;
  final int lowStockCount;
  final double todaySales;
  final double monthSales;
  final List<Product> lowStockItems;
}

@riverpod
Future<DashboardStats> dashboard(DashboardRef ref) async {
  final products = await ref.watch(productRepoProvider).getAll();
  final sales = await ref.watch(saleRepoProvider).getSummary();
  final lowStock = products.where((p) => p.isLowStock).toList();

  return DashboardStats(
    totalProducts: products.length,
    totalUnits: products.fold(0, (s, p) => s + p.quantity),
    totalValue: products.fold(0.0, (s, p) => s + p.totalValue),
    lowStockCount: lowStock.length,
    todaySales: sales['today'] ?? 0,
    monthSales: sales['month'] ?? 0,
    lowStockItems: lowStock,
  );
}
