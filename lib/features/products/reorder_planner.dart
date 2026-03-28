import '../../data/models/product.dart';
import '../../data/repos/sale_repo.dart';

class ReorderSuggestion {
  const ReorderSuggestion({
    required this.product,
    required this.recommendedQuantity,
    required this.targetStock,
    required this.averageDailyDemand,
    required this.urgencyScore,
    required this.priorityLabel,
    required this.reason,
    this.daysOfCover,
    this.lastSoldAt,
  });

  final Product product;
  final num recommendedQuantity;
  final double targetStock;
  final double averageDailyDemand;
  final double urgencyScore;
  final String priorityLabel;
  final String reason;
  final double? daysOfCover;
  final DateTime? lastSoldAt;

  double get estimatedCost => recommendedQuantity * product.unitPrice;
  double get shortage =>
      (product.minimumStock - product.quantity).clamp(0, product.minimumStock);
  bool get isDemandDriven => averageDailyDemand > 0;
  bool get isCritical =>
      priorityLabel == 'Critical' || (daysOfCover != null && daysOfCover! <= 3);
}

class ReorderPlan {
  const ReorderPlan(this.suggestions, {required this.demandWindowDays});

  final List<ReorderSuggestion> suggestions;
  final int demandWindowDays;

  int get totalItems => suggestions.length;
  double get totalUnits =>
      suggestions.fold(0.0, (sum, item) => sum + item.recommendedQuantity);
  double get totalCost =>
      suggestions.fold(0, (sum, item) => sum + item.estimatedCost);
  int get criticalItems => suggestions.where((item) => item.isCritical).length;
  int get demandDrivenItems =>
      suggestions.where((item) => item.isDemandDriven).length;
  double? get averageCoverDays {
    final covered =
        suggestions
            .where((item) => item.daysOfCover != null)
            .map((item) => item.daysOfCover!)
            .toList();
    if (covered.isEmpty) return null;
    return covered.reduce((a, b) => a + b) / covered.length;
  }

  bool get isEmpty => suggestions.isEmpty;
}

class SlowMovingSuggestion {
  const SlowMovingSuggestion({
    required this.product,
    required this.averageDailyDemand,
    required this.excessUnits,
    required this.reason,
    this.daysOfCover,
  });

  final Product product;
  final double averageDailyDemand;
  final double excessUnits;
  final String reason;
  final double? daysOfCover;

  double get inventoryValue => product.totalValue;
}

class SlowMovingPlan {
  const SlowMovingPlan(this.suggestions, {required this.demandWindowDays});

  final List<SlowMovingSuggestion> suggestions;
  final int demandWindowDays;

  int get totalItems => suggestions.length;
  double get tiedUpValue =>
      suggestions.fold(0, (sum, item) => sum + item.inventoryValue);
  double get excessUnits =>
      suggestions.fold(0.0, (sum, item) => sum + item.excessUnits);
  bool get isEmpty => suggestions.isEmpty;
}

class ProductInsightSnapshot {
  const ProductInsightSnapshot({
    required this.product,
    required this.averageDailyDemand,
    required this.inventoryValue,
    required this.statusLabel,
    required this.summary,
    this.daysOfCover,
    this.reorderSuggestion,
    this.slowMovingSuggestion,
  });

  final Product product;
  final double averageDailyDemand;
  final double inventoryValue;
  final String statusLabel;
  final String summary;
  final double? daysOfCover;
  final ReorderSuggestion? reorderSuggestion;
  final SlowMovingSuggestion? slowMovingSuggestion;

  bool get needsAttention =>
      reorderSuggestion != null || slowMovingSuggestion != null;
}

ReorderPlan buildReorderPlan(
  List<Product> products, {
  Map<int, ProductDemandSummary> demandByProduct = const {},
  int demandWindowDays = 30,
}) {
  final suggestions =
      products
          .map((product) {
            final demand =
                product.id == null ? null : demandByProduct[product.id];
            final averageDailyDemand =
                demand?.averageDailyDemand(demandWindowDays) ?? 0;
            final daysOfCover = _daysOfCover(product, averageDailyDemand);
            final targetStock = _buildTargetStock(
              product,
              averageDailyDemand: averageDailyDemand,
            );
            final recommendedQuantity = (targetStock - product.quantity).clamp(
              0,
              targetStock,
            );
            final shouldInclude =
                product.isLowStock ||
                (daysOfCover != null &&
                    daysOfCover <= 14 &&
                    recommendedQuantity > 0);
            if (!shouldInclude) {
              return null;
            }

            return ReorderSuggestion(
              product: product,
              recommendedQuantity: recommendedQuantity,
              targetStock: targetStock,
              averageDailyDemand: averageDailyDemand,
              urgencyScore: _urgencyScore(
                product,
                daysOfCover: daysOfCover,
                averageDailyDemand: averageDailyDemand,
              ),
              priorityLabel: _priorityLabel(
                product,
                daysOfCover: daysOfCover,
                averageDailyDemand: averageDailyDemand,
              ),
              reason: _buildReason(
                product,
                daysOfCover: daysOfCover,
                averageDailyDemand: averageDailyDemand,
              ),
              daysOfCover: daysOfCover,
              lastSoldAt: demand?.lastSoldAt,
            );
          })
          .whereType<ReorderSuggestion>()
          .where((suggestion) => suggestion.recommendedQuantity > 0)
          .toList()
        ..sort((a, b) {
          final urgencyCompare = b.urgencyScore.compareTo(a.urgencyScore);
          if (urgencyCompare != 0) return urgencyCompare;
          return a.product.name.toLowerCase().compareTo(
            b.product.name.toLowerCase(),
          );
        });

  return ReorderPlan(suggestions, demandWindowDays: demandWindowDays);
}

SlowMovingPlan buildSlowMovingPlan(
  List<Product> products, {
  Map<int, ProductDemandSummary> demandByProduct = const {},
  int demandWindowDays = 30,
}) {
  final suggestions =
      products
          .map((product) {
            final demand =
                product.id == null ? null : demandByProduct[product.id];
            final averageDailyDemand =
                demand?.averageDailyDemand(demandWindowDays) ?? 0;
            final daysOfCover = _daysOfCover(product, averageDailyDemand);
            final excessUnits = (product.quantity - product.minimumStock).clamp(
              0,
              product.quantity,
            );
            if (product.quantity <= product.minimumStock || excessUnits <= 0) {
              return null;
            }

            if (averageDailyDemand == 0 &&
                product.quantity >= product.minimumStock * 2) {
              return SlowMovingSuggestion(
                product: product,
                averageDailyDemand: averageDailyDemand,
                excessUnits: excessUnits as double,
                reason: 'No sales recorded in the last $demandWindowDays days',
              );
            }

            if (daysOfCover != null && daysOfCover >= 45) {
              return SlowMovingSuggestion(
                product: product,
                averageDailyDemand: averageDailyDemand,
                excessUnits: excessUnits as double,
                daysOfCover: daysOfCover,
                reason: 'Current stock covers about ${daysOfCover.ceil()} days',
              );
            }

            return null;
          })
          .whereType<SlowMovingSuggestion>()
          .toList()
        ..sort((a, b) => b.inventoryValue.compareTo(a.inventoryValue));

  return SlowMovingPlan(suggestions, demandWindowDays: demandWindowDays);
}

ProductInsightSnapshot buildProductInsightSnapshot(
  Product product, {
  ProductDemandSummary? demand,
  ReorderSuggestion? reorderSuggestion,
  SlowMovingSuggestion? slowMovingSuggestion,
  int demandWindowDays = 30,
}) {
  final averageDailyDemand = demand?.averageDailyDemand(demandWindowDays) ?? 0;
  final daysOfCover = _daysOfCover(product, averageDailyDemand);

  if (reorderSuggestion != null) {
    return ProductInsightSnapshot(
      product: product,
      averageDailyDemand: averageDailyDemand,
      inventoryValue: product.totalValue,
      statusLabel: reorderSuggestion.priorityLabel,
      summary: reorderSuggestion.reason,
      daysOfCover: daysOfCover,
      reorderSuggestion: reorderSuggestion,
      slowMovingSuggestion: slowMovingSuggestion,
    );
  }

  if (slowMovingSuggestion != null) {
    return ProductInsightSnapshot(
      product: product,
      averageDailyDemand: averageDailyDemand,
      inventoryValue: product.totalValue,
      statusLabel: 'Slow Moving',
      summary: slowMovingSuggestion.reason,
      daysOfCover: daysOfCover,
      reorderSuggestion: reorderSuggestion,
      slowMovingSuggestion: slowMovingSuggestion,
    );
  }

  return ProductInsightSnapshot(
    product: product,
    averageDailyDemand: averageDailyDemand,
    inventoryValue: product.totalValue,
    statusLabel: 'Healthy',
    summary:
        averageDailyDemand > 0
            ? 'Stock looks balanced against recent demand'
            : 'No recent sales signal yet, but stock is within expected range',
    daysOfCover: daysOfCover,
    reorderSuggestion: reorderSuggestion,
    slowMovingSuggestion: slowMovingSuggestion,
  );
}

double _buildTargetStock(
  Product product, {
  required double averageDailyDemand,
}) {
  final bufferedMinimum = product.minimumStock + (product.minimumStock / 2);
  final safetyFloor = product.minimumStock + 5;
  final demandBuffer = averageDailyDemand * 21;
  return [
    bufferedMinimum,
    safetyFloor,
    demandBuffer,
  ].reduce((a, b) => a > b ? a : b);
}

double? _daysOfCover(Product product, double averageDailyDemand) {
  if (averageDailyDemand <= 0) return null;
  return product.quantity / averageDailyDemand;
}

double _urgencyScore(
  Product product, {
  required double? daysOfCover,
  required double averageDailyDemand,
}) {
  final shortage = (product.minimumStock - product.quantity).clamp(0, 999999);
  final shortageWeight = shortage * 3;
  final coverWeight = daysOfCover == null ? 0 : (30 - daysOfCover).clamp(0, 30);
  final demandWeight = averageDailyDemand * 5;
  return shortageWeight + coverWeight + demandWeight;
}

String _priorityLabel(
  Product product, {
  required double? daysOfCover,
  required double averageDailyDemand,
}) {
  if (product.quantity <= 0 || (daysOfCover != null && daysOfCover <= 3)) {
    return 'Critical';
  }
  if (product.isLowStock || (daysOfCover != null && daysOfCover <= 7)) {
    return 'High';
  }
  if (averageDailyDemand > 0) {
    return 'Medium';
  }
  return 'Planned';
}

String _buildReason(
  Product product, {
  required double? daysOfCover,
  required double averageDailyDemand,
}) {
  if (product.quantity <= 0) {
    return 'Out of stock now';
  }
  if (daysOfCover != null && daysOfCover <= 3) {
    return 'Likely to run out within ${daysOfCover.ceil()} days';
  }
  if (product.isLowStock && averageDailyDemand > 0) {
    return 'Below minimum and still selling steadily';
  }
  if (product.isLowStock) {
    return 'Below configured minimum stock';
  }
  if (daysOfCover != null && daysOfCover <= 14) {
    return 'Current stock covers about ${daysOfCover.ceil()} days';
  }
  return 'Recommended top-up based on recent demand';
}
