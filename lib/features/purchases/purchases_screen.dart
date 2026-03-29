import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';
import '../../data/models/product.dart';
import '../../data/models/purchase_order.dart';
import '../../data/repos/providers.dart';
import '../products/product_provider.dart';
import '../products/reorder_planner.dart';
import '../stock/stock_provider.dart';
import 'purchase_provider.dart';

class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});

  static const int demandWindowDays = 30;

  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supplier = TextEditingController();
  final _quantity = TextEditingController();
  final _unitCost = TextEditingController();
  final _note = TextEditingController();

  Product? _selectedProduct;
  PurchaseOrderStatus? _statusFilter;
  String _search = '';

  @override
  void dispose() {
    _supplier.dispose();
    _quantity.dispose();
    _unitCost.dispose();
    _note.dispose();
    super.dispose();
  }

  Product? _resolveSelectedProduct(List<Product> products) {
    final id = _selectedProduct?.id;
    if (id == null) return null;
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  void _applySuggestion(ReorderSuggestion suggestion) {
    setState(() {
      _selectedProduct = suggestion.product;
      _quantity.text = suggestion.recommendedQuantity
          .toStringAsFixed(suggestion.product.allowFractionalQuantity ? 2 : 0)
          .replaceFirst(RegExp(r'\.?0+$'), '');
      _unitCost.text = suggestion.product.unitPrice.toStringAsFixed(2);
      if (_note.text.trim().isEmpty) {
        _note.text =
            'Suggested by reorder planner (${suggestion.priorityLabel})';
      }
    });
  }

  String? _validateQuantity(String? value) {
    final baseError = Validators.nonZeroDouble(value);
    if (baseError != null) return baseError;
    final product = _selectedProduct;
    if (product == null) return 'Select a product first';
    return Validators.wholeNumberWhenRequired(
      value,
      allowFraction: product.allowFractionalQuantity,
      message: 'This product can only be ordered in whole quantities',
    );
  }

  Future<void> _createOrder() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final product = _selectedProduct;
    if (product?.id == null) {
      _showSnack('Select a product', error: true);
      return;
    }

    try {
      await ref
          .read(purchaseRepoProvider)
          .create(
            productId: product!.id!,
            supplierName: _supplier.text,
            quantity: double.parse(_quantity.text.trim()),
            unitCost: double.parse(_unitCost.text.trim()),
            note: _note.text,
          );
      _supplier.clear();
      _quantity.clear();
      _unitCost.clear();
      _note.clear();
      setState(() => _selectedProduct = null);
      _refreshState();
      _showSnack('Purchase order created');
    } on AppException catch (e) {
      _showSnack(e.message, error: true);
    } catch (e) {
      _showSnack('Failed to create purchase order: $e', error: true);
    }
  }

  Future<void> _handleOrderAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      _refreshState();
      _showSnack(successMessage);
    } on AppException catch (e) {
      _showSnack(e.message, error: true);
    } catch (e) {
      _showSnack('Action failed: $e', error: true);
    }
  }

  void _refreshState() {
    ref.invalidate(purchaseOrdersProvider);
    ref.invalidate(productsProvider);
    ref.invalidate(stockMovementsProvider);
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final ordersAsync = ref.watch(purchaseOrdersProvider);
    final demandAsync = ref.watch(
      recentProductDemandProvider(PurchasesScreen.demandWindowDays),
    );
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 360,
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Text(
                      'Create Purchase Order',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Turn low stock into a supplier order and receive it into stock later.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    productsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('$e'),
                      data: (products) {
                        final selected = _resolveSelectedProduct(products);
                        if (_selectedProduct != null && selected == null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted)
                              setState(() => _selectedProduct = null);
                          });
                        }
                        return DropdownButtonFormField<Product>(
                          isExpanded: true,
                          value: selected,
                          decoration: const InputDecoration(
                            labelText: 'Product',
                          ),
                          items:
                              products
                                  .map(
                                    (product) => DropdownMenuItem<Product>(
                                      value: product,
                                      child: Text(
                                        '${product.name} (${Fmt.qtyWithUnit(product.quantity, product.stockUnit)})',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedProduct = value;
                              if (value != null &&
                                  _unitCost.text.trim().isEmpty) {
                                _unitCost.text = value.unitPrice
                                    .toStringAsFixed(2);
                              }
                            });
                            _formKey.currentState?.validate();
                          },
                          validator:
                              (value) => value == null ? 'Required' : null,
                        );
                      },
                    ),
                    if (_selectedProduct != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Current stock: ${Fmt.qtyWithUnit(_selectedProduct!.quantity, _selectedProduct!.stockUnit)} | Minimum: ${Fmt.qtyWithUnit(_selectedProduct!.minimumStock, _selectedProduct!.stockUnit)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _supplier,
                      label: 'Supplier Name',
                      validator: Validators.required,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _quantity,
                      label:
                          _selectedProduct == null
                              ? 'Order Quantity'
                              : 'Order Quantity (${_selectedProduct!.stockUnit})',
                      validator: _validateQuantity,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _unitCost,
                      label: 'Unit Cost (PKR)',
                      validator: Validators.nonZeroDouble,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppTextField(controller: _note, label: 'Note', maxLines: 2),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _createOrder,
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('Create Order'),
                    ),
                    const SizedBox(height: 24),
                    const SectionHeader(title: 'Quick Suggestions'),
                    demandAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error:
                          (_, __) => const Text('Demand signals unavailable'),
                      data: (demandByProduct) {
                        return productsAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (products) {
                            final plan = buildReorderPlan(
                              products,
                              demandByProduct: demandByProduct,
                              demandWindowDays:
                                  PurchasesScreen.demandWindowDays,
                            );
                            if (plan.suggestions.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text('No urgent restocks right now'),
                              );
                            }
                            return Column(
                              children:
                                  plan.suggestions.take(4).map((suggestion) {
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      child: ListTile(
                                        title: Text(
                                          suggestion.product.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${suggestion.priorityLabel} | Buy ${Fmt.qtyWithUnit(suggestion.recommendedQuantity, suggestion.product.stockUnit)} | ${suggestion.reason}',
                                        ),
                                        trailing: TextButton(
                                          onPressed:
                                              () =>
                                                  _applySuggestion(suggestion),
                                          child: const Text('Use'),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SectionHeader(title: 'Purchase Orders'),
                ordersAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error:
                      (e, _) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text('Error: $e'),
                      ),
                  data: (orders) {
                    final openOrders =
                        orders
                            .where(
                              (order) =>
                                  order.status == PurchaseOrderStatus.draft ||
                                  order.status == PurchaseOrderStatus.ordered,
                            )
                            .toList();
                    final totalSpend = openOrders.fold<double>(
                      0,
                      (sum, order) => sum + order.totalCost,
                    );
                    final receivedToday =
                        orders
                            .where(
                              (order) =>
                                  order.receivedAt != null &&
                                  _isToday(order.receivedAt!),
                            )
                            .length;

                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _PurchaseMetric(
                                label: 'Open Orders',
                                value: openOrders.length.toString(),
                                color: const Color(0xFF0F766E),
                                icon: Icons.pending_actions_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _PurchaseMetric(
                                label: 'Committed Spend',
                                value: Fmt.currency(totalSpend),
                                color: cs.primary,
                                icon: Icons.payments_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _PurchaseMetric(
                                label: 'Received Today',
                                value: receivedToday.toString(),
                                color: const Color(0xFF7C2D12),
                                icon: Icons.inventory_2_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            SizedBox(
                              width: 180,
                              child: DropdownButtonFormField<
                                PurchaseOrderStatus?
                              >(
                                value: _statusFilter,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Status',
                                  isDense: true,
                                ),
                                items: [
                                  const DropdownMenuItem<PurchaseOrderStatus?>(
                                    value: null,
                                    child: Text('All'),
                                  ),
                                  ...PurchaseOrderStatus.values.map(
                                    (status) =>
                                        DropdownMenuItem<PurchaseOrderStatus?>(
                                          value: status,
                                          child: Text(status.label),
                                        ),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() => _statusFilter = value);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  hintText:
                                      'Search by product, supplier or note...',
                                  prefixIcon: Icon(Icons.search, size: 18),
                                  isDense: true,
                                ),
                                onChanged: (value) {
                                  setState(() => _search = value.toLowerCase());
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ordersAsync.when(
                    loading:
                        () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (orders) {
                      final filtered =
                          orders.where((order) {
                            if (_statusFilter != null &&
                                order.status != _statusFilter) {
                              return false;
                            }
                            if (_search.isEmpty) return true;
                            final haystack =
                                [
                                  order.productName,
                                  order.productCategory,
                                  order.supplierName,
                                  order.note,
                                ].join(' ').toLowerCase();
                            return haystack.contains(_search);
                          }).toList();

                      if (filtered.isEmpty) {
                        return const EmptyState(
                          icon: Icons.shopping_bag_outlined,
                          message: 'No purchase orders match these filters',
                        );
                      }

                      return ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final order = filtered[index];
                          final statusColor = _statusColor(
                            context,
                            order.status,
                          );
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: statusColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        foregroundColor: statusColor,
                                        child: Icon(
                                          _statusIcon(order.status),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    order.productName,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                                _StatusBadge(
                                                  label: order.status.label,
                                                  color: statusColor,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${order.supplierName} | ${order.productCategory}',
                                              style: TextStyle(
                                                color: cs.onSurfaceVariant,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 10,
                                              runSpacing: 10,
                                              children: [
                                                _DetailPill(
                                                  label:
                                                      'Qty ${Fmt.qtyWithUnit(order.orderedQuantity, order.stockUnit)}',
                                                ),
                                                _DetailPill(
                                                  label:
                                                      'Unit ${Fmt.currency(order.unitCost)}',
                                                ),
                                                _DetailPill(
                                                  label:
                                                      'Total ${Fmt.currency(order.totalCost)}',
                                                ),
                                                _DetailPill(
                                                  label:
                                                      'Created ${Fmt.date(order.createdAt)}',
                                                ),
                                              ],
                                            ),
                                            if (order.note
                                                .trim()
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 10),
                                              Text(order.note),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      if (order.canPlace)
                                        FilledButton.tonalIcon(
                                          onPressed:
                                              () => _handleOrderAction(
                                                () => ref
                                                    .read(purchaseRepoProvider)
                                                    .place(order.id!),
                                                'Purchase order marked as ordered',
                                              ),
                                          icon: const Icon(Icons.send_outlined),
                                          label: const Text('Mark Ordered'),
                                        ),
                                      if (order.canPlace)
                                        const SizedBox(width: 8),
                                      if (order.canReceive)
                                        FilledButton.icon(
                                          onPressed:
                                              () => _handleOrderAction(
                                                () => ref
                                                    .read(purchaseRepoProvider)
                                                    .receive(order.id!),
                                                'Stock received into inventory',
                                              ),
                                          icon: const Icon(
                                            Icons.move_to_inbox_outlined,
                                          ),
                                          label: const Text('Receive Stock'),
                                        ),
                                      if (order.canReceive)
                                        const SizedBox(width: 8),
                                      if (order.canCancel)
                                        OutlinedButton.icon(
                                          onPressed:
                                              () => _handleOrderAction(
                                                () => ref
                                                    .read(purchaseRepoProvider)
                                                    .cancel(order.id!),
                                                'Purchase order cancelled',
                                              ),
                                          icon: const Icon(Icons.close),
                                          label: const Text('Cancel'),
                                        ),
                                      const Spacer(),
                                      if (order.orderedAt != null)
                                        Text(
                                          'Ordered: ${Fmt.date(order.orderedAt!)}',
                                          style: TextStyle(
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                      if (order.receivedAt != null) ...[
                                        const SizedBox(width: 12),
                                        Text(
                                          'Received: ${Fmt.date(order.receivedAt!)}',
                                          style: TextStyle(
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return now.year == date.year &&
        now.month == date.month &&
        now.day == date.day;
  }

  Color _statusColor(BuildContext context, PurchaseOrderStatus status) {
    final cs = Theme.of(context).colorScheme;
    switch (status) {
      case PurchaseOrderStatus.draft:
        return cs.primary;
      case PurchaseOrderStatus.ordered:
        return const Color(0xFFB45309);
      case PurchaseOrderStatus.received:
        return const Color(0xFF0F766E);
      case PurchaseOrderStatus.cancelled:
        return cs.error;
    }
  }

  IconData _statusIcon(PurchaseOrderStatus status) {
    switch (status) {
      case PurchaseOrderStatus.draft:
        return Icons.edit_note_outlined;
      case PurchaseOrderStatus.ordered:
        return Icons.local_shipping_outlined;
      case PurchaseOrderStatus.received:
        return Icons.inventory_rounded;
      case PurchaseOrderStatus.cancelled:
        return Icons.block_outlined;
    }
  }
}

class _PurchaseMetric extends StatelessWidget {
  const _PurchaseMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(label),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
