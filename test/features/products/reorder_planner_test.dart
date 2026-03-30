import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_managment_sys/data/models/product.dart';
import 'package:inventory_managment_sys/features/products/reorder_planner.dart';

void main() {
  test('buildReorderPlan returns prioritized reorder suggestions', () {
    final plan = buildReorderPlan([
      const Product(
        id: 1,
        name: 'DAP',
        category: 'Fertilizer',
        unitPrice: 100,
        costPrice: 70,
        quantity: 2,
        minimumStock: 10,
      ),
      const Product(
        id: 2,
        name: 'Urea',
        category: 'Fertilizer',
        unitPrice: 80,
        costPrice: 55,
        quantity: 10,
        minimumStock: 10,
      ),
      const Product(
        id: 3,
        name: 'Seed Pack',
        category: 'Seeds',
        unitPrice: 50,
        costPrice: 30,
        quantity: 25,
        minimumStock: 10,
      ),
    ]);

    expect(plan.totalItems, 2);
    expect(plan.totalUnits, 26);
    expect(plan.totalCost, 1800);

    expect(plan.suggestions.first.product.name, 'DAP');
    expect(plan.suggestions.first.recommendedQuantity, 13);
    expect(plan.suggestions[1].product.name, 'Urea');
    expect(plan.suggestions[1].recommendedQuantity, 13);
  });

  test('buildReorderPlan ignores products above minimum stock', () {
    final plan = buildReorderPlan([
      const Product(
        id: 1,
        name: 'Healthy Stock',
        category: 'General',
        unitPrice: 25,
        costPrice: 15,
        quantity: 50,
        minimumStock: 10,
      ),
    ]);

    expect(plan.isEmpty, isTrue);
    expect(plan.suggestions, isEmpty);
  });
}

