import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_managment_sys/data/models/purchase_order.dart';

void main() {
  test('purchase order exposes allowed actions by status', () {
    PurchaseOrder build(PurchaseOrderStatus status) => PurchaseOrder(
      id: 1,
      productId: 1,
      productName: 'DAP',
      productCategory: 'Fertilizer',
      supplierName: 'Agri Trader',
      orderedQuantity: 12,
      unitCost: 95,
      stockUnit: 'bag',
      note: '',
      status: status,
      createdAt: DateTime(2026, 3, 29),
    );

    expect(build(PurchaseOrderStatus.draft).canPlace, isTrue);
    expect(build(PurchaseOrderStatus.draft).canReceive, isTrue);
    expect(build(PurchaseOrderStatus.draft).canCancel, isTrue);

    expect(build(PurchaseOrderStatus.ordered).canPlace, isFalse);
    expect(build(PurchaseOrderStatus.ordered).canReceive, isTrue);
    expect(build(PurchaseOrderStatus.ordered).canCancel, isTrue);

    expect(build(PurchaseOrderStatus.received).canReceive, isFalse);
    expect(build(PurchaseOrderStatus.received).canCancel, isFalse);

    expect(build(PurchaseOrderStatus.cancelled).canPlace, isFalse);
    expect(build(PurchaseOrderStatus.cancelled).canReceive, isFalse);
  });

  test('purchase order calculates total cost', () {
    final order = PurchaseOrder(
      id: 2,
      productId: 3,
      productName: 'Urea',
      productCategory: 'Fertilizer',
      supplierName: 'Wholesale Depot',
      orderedQuantity: 5,
      unitCost: 1200,
      stockUnit: 'bag',
      note: 'Urgent',
      status: PurchaseOrderStatus.ordered,
      createdAt: DateTime(2026, 3, 29),
    );

    expect(order.totalCost, 6000);
  });
}
