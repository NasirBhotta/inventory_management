import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventory_managment_sys/data/models/quotation.dart';
import 'package:inventory_managment_sys/data/repos/providers.dart';

final quotationsProvider = FutureProvider<List<Quotation>>((ref) async {
  return ref.watch(quotationRepoProvider).getAll();
});
