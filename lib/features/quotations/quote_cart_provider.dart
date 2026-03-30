import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventory_managment_sys/data/models/cart_item.dart';

class QuoteCartNotifier extends StateNotifier<List<CartItem>> {
  QuoteCartNotifier() : super(const []);

  void add(CartItem item) {
    final index = state.indexWhere((entry) => entry.productId == item.productId);
    if (index == -1) {
      state = [...state, item];
      return;
    }
    final updated = [...state];
    final existing = updated[index];
    updated[index] = existing.copyWith(quantity: existing.quantity + item.quantity);
    state = updated;
  }

  void remove(int productId) {
    state = state.where((entry) => entry.productId != productId).toList();
  }

  void clear() {
    state = const [];
  }

  double get total => state.fold(0, (sum, item) => sum + item.total);
}

final quoteCartProvider =
    StateNotifierProvider<QuoteCartNotifier, List<CartItem>>(
  (ref) => QuoteCartNotifier(),
);
