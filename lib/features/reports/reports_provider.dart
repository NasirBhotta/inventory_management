import 'package:flutter/foundation.dart';
import '../../../data/database/db_service.dart';
import '../../../data/models/product.dart';
import '../../../data/models/stock_movement.dart';
import '../../../data/repos/product_repo.dart';
import '../../../data/repos/sale_repo.dart';
import '../../../data/repos/stock_repo.dart';
import '../../../core/utils/app_logger.dart';

class ReportsProvider extends ChangeNotifier {
  ReportsProvider(DatabaseService db)
    : _productRepo = ProductRepository(db),
      _salesRepo = SalesRepository(db),
      _stockRepo = StockRepository(db);

  final ProductRepository _productRepo;
  final SalesRepository _salesRepo;
  final StockRepository _stockRepo;

  List<Product> _stockSnapshot = [];
  List<StockMovement> _movements = [];
  double _dailySales = 0;
  double _monthlySales = 0;
  bool _loading = false;
  String? _error;
  DateTimeRange? _range;

  List<Product> get stockSnapshot => _stockSnapshot;
  List<StockMovement> get movements => _movements;
  double get dailySales => _dailySales;
  double get monthlySales => _monthlySales;
  bool get loading => _loading;
  String? get error => _error;
  DateTimeRange? get range => _range;

  Future<void> load({DateTimeRange? range}) async {
    _range = range;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final summary = await _salesRepo.getSalesSummary();
      _dailySales = summary['today'] ?? 0;
      _monthlySales = summary['monthly'] ?? 0;
      _stockSnapshot = await _productRepo.getAll();
      _movements = await _stockRepo.getMovements(
        from: range?.start,
        to: range?.end,
      );
    } catch (e) {
      _error = e.toString();
      appLogger.e('ReportsProvider.load failed', error: e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}

class DateTimeRange {
  const DateTimeRange({required this.start, required this.end});
  final DateTime start;
  final DateTime end;
}
