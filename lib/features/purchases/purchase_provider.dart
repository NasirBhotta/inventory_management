import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventory_managment_sys/data/models/purchase_order.dart';
import 'package:inventory_managment_sys/data/repos/providers.dart';

final purchaseOrdersProvider = FutureProvider<List<PurchaseOrder>>((ref) async {
  return ref.watch(purchaseRepoProvider).getAll();
});
