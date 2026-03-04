import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/stock_movement.dart';
import '../../../data/repos/providers.dart';

final stockMovementsProvider = FutureProvider<List<StockMovement>>((ref) async {
  return ref.watch(stockRepoProvider).getRecent();
});
