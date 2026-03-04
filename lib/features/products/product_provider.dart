import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/product.dart';
import '../../../data/repos/providers.dart';

part 'product_provider.g.dart';

@Riverpod(keepAlive: true)
Future<List<Product>> products(ProductsRef ref) async {
  return ref.watch(productRepoProvider).getAll();
}

@Riverpod(keepAlive: true)
Future<List<String>> categories(CategoriesRef ref) async {
  return ref.watch(productRepoProvider).getCategories();
}
