import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventory_managment_sys/data/repos/providers.dart';
import 'package:inventory_managment_sys/data/repos/sale_repo.dart';

class ProfitService {
  const ProfitService(this._salesRepo);

  final SalesRepository _salesRepo;

  Future<double> getTotalProfitToday() => _salesRepo.getTotalProfitToday();

  Future<double> getTotalProfitByDateRange(DateTime start, DateTime end) {
    return _salesRepo.getTotalProfitByDateRange(start, end);
  }

  Future<List<ProductProfitSummary>> getProfitPerProduct({
    DateTime? start,
    DateTime? end,
  }) {
    return _salesRepo.getProfitPerProduct(start: start, end: end);
  }

  Future<List<ProductProfitSummary>> getTopProfitProducts({int limit = 5}) {
    return _salesRepo.getTopProfitProducts(limit: limit);
  }
}

final profitProvider = Provider<ProfitService>((ref) {
  return ProfitService(ref.watch(saleRepoProvider));
});

final totalProfitTodayProvider = FutureProvider<double>((ref) async {
  return ref.watch(profitProvider).getTotalProfitToday();
});

final totalProfitByDateRangeProvider =
    FutureProvider.family<double, DateTimeRange>((ref, range) async {
  return ref
      .watch(profitProvider)
      .getTotalProfitByDateRange(range.start, range.end);
});

final profitPerProductProvider =
    FutureProvider.family<List<ProductProfitSummary>, DateTimeRange?>((
  ref,
  range,
) async {
  return ref.watch(profitProvider).getProfitPerProduct(
        start: range?.start,
        end: range?.end,
      );
});

final topProfitProductsProvider =
    FutureProvider.family<List<ProductProfitSummary>, int>((ref, limit) async {
  return ref.watch(profitProvider).getTopProfitProducts(limit: limit);
});

final productProfitSummaryProvider =
    FutureProvider.family<ProductProfitSummary?, int>((ref, productId) async {
  final summaries = await ref.watch(profitProvider).getProfitPerProduct();
  for (final summary in summaries) {
    if (summary.productId == productId) return summary;
  }
  return null;
});

