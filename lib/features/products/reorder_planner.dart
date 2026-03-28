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
