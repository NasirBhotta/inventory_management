import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventory_managment_sys/data/models/cart_item.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super(const []);

  void add(CartItem item) {
    final index = state.indexWhere((e) => e.productId == item.productId);
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
    state = state.where((e) => e.productId != productId).toList();
  }

  void increment(int productId) {
    final index = state.indexWhere((e) => e.productId == productId);
    if (index == -1) return;
    final updated = [...state];
    final existing = updated[index];
    updated[index] = existing.copyWith(quantity: existing.quantity + 1);
    state = updated;
  }

  void decrement(int productId) {
    final index = state.indexWhere((e) => e.productId == productId);
    if (index == -1) return;
    final updated = [...state];
    final existing = updated[index];
    if (existing.quantity <= 1) {
      updated.removeAt(index);
    } else {
      updated[index] = existing.copyWith(quantity: existing.quantity - 1);
    }
    state = updated;
  }

  void clear() {
    state = const [];
  }

  double get total => state.fold(0, (sum, item) => sum + item.total);
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) => CartNotifier());
