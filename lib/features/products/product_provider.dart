import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/product.dart';
import '../../../data/repos/providers.dart';
import '../../../data/repos/sale_repo.dart';

part 'product_provider.g.dart';

@Riverpod(keepAlive: true)
Future<List<Product>> products(ProductsRef ref) async {
  return ref.watch(productRepoProvider).getAll();
}

@Riverpod(keepAlive: true)
Future<List<String>> categories(CategoriesRef ref) async {
  return ref.watch(productRepoProvider).getCategories();
}

final recentProductDemandProvider =
    FutureProvider.family<Map<int, ProductDemandSummary>, int>((ref, days) async {
  return ref.watch(saleRepoProvider).getRecentProductDemand(days: days);
});
