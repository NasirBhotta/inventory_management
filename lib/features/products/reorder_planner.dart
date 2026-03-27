import '../../data/models/product.dart';

class ReorderSuggestion {
  const ReorderSuggestion({
    required this.product,
    required this.recommendedQuantity,
    required this.targetStock,
  });

  final Product product;
  final double recommendedQuantity;
  final double targetStock;

  double get estimatedCost => recommendedQuantity * product.unitPrice;
  double get shortage =>
      (product.minimumStock - product.quantity).clamp(0, product.minimumStock);
}

class ReorderPlan {
  const ReorderPlan(this.suggestions);

  final List<ReorderSuggestion> suggestions;

  int get totalItems => suggestions.length;
  double get totalUnits =>
      suggestions.fold(0, (sum, item) => sum + item.recommendedQuantity);
  double get totalCost => suggestions.fold(0, (sum, item) => sum + item.estimatedCost);
  bool get isEmpty => suggestions.isEmpty;
}

ReorderPlan buildReorderPlan(List<Product> products) {
  final suggestions = products
      .where((product) => product.isLowStock)
      .map((product) {
        final targetStock = _buildTargetStock(product);
        final recommendedQuantity =
            (targetStock - product.quantity).clamp(0, targetStock);
        return ReorderSuggestion(
          product: product,
          recommendedQuantity: recommendedQuantity,
          targetStock: targetStock,
        );
      })
      .where((suggestion) => suggestion.recommendedQuantity > 0)
      .toList()
    ..sort((a, b) {
      final shortageCompare = b.shortage.compareTo(a.shortage);
      if (shortageCompare != 0) return shortageCompare;
      return a.product.name.toLowerCase().compareTo(b.product.name.toLowerCase());
    });

  return ReorderPlan(suggestions);
}

double _buildTargetStock(Product product) {
  final bufferedMinimum = product.minimumStock + (product.minimumStock / 2);
  final safetyFloor = product.minimumStock + 5;
  return [bufferedMinimum, safetyFloor].reduce((a, b) => a > b ? a : b);
}
