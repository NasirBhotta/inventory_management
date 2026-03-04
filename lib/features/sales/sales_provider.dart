import 'package:flutter/foundation.dart';
import '../../../data/database/db_service.dart';
import '../../../data/models/sale.dart';
import '../../../data/repos/sale_repo.dart';
import '../../../core/utils/app_logger.dart';

class SalesProvider extends ChangeNotifier {
  SalesProvider(DatabaseService db) : _repo = SalesRepository(db);
  final SalesRepository _repo;

  List<Sale> _sales = [];
  final List<CartItem> _cart = [];
  bool _loading = false;
  String? _error;

  List<Sale> get sales => _sales;
  List<CartItem> get cart => List.unmodifiable(_cart);
  bool get loading => _loading;
  String? get error => _error;
  bool get cartEmpty => _cart.isEmpty;
  double get cartTotal => _cart.fold(0, (s, i) => s + i.lineTotal);

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _sales = await _repo.getSales();
    } catch (e) {
      _error = e.toString();
      appLogger.e('SalesProvider.load failed', error: e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void addToCart(CartItem item) {
    final idx = _cart.indexWhere((c) => c.productId == item.productId);
    if (idx != -1) {
      final current = _cart[idx];
      _cart[idx] = current.copyWith(quantity: current.quantity + item.quantity);
    } else {
      _cart.add(item);
    }
    notifyListeners();
  }

  void removeFromCart(int productId) {
    _cart.removeWhere((c) => c.productId == productId);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  Future<bool> finalizeSale({String? note}) async {
    if (_cart.isEmpty) return false;
    try {
      await _repo.createSale(_cart, note: note);
      _cart.clear();
      await load();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
