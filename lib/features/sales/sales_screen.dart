import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/product.dart';
import '../../data/repos/providers.dart';
import '../dashboard/dashboard_provider.dart';
import '../products/product_provider.dart';
import 'cart_provider.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  Product? _selected;
  final _qty = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _finalizing = false;

  double _previewQuantity() => double.tryParse(_qty.text.trim()) ?? 0;

  Product? _resolveSelected(List<Product> products) {
    final selectedId = _selected?.id;
    if (selectedId == null) return null;
    for (final p in products) {
      if (p.id == selectedId) return p;
    }
    return null;
  }

  String? _validateQuantity(String? value) {
    final product = _selected;
    final existingInCart = product == null
        ? 0.0
        : ref
            .read(cartProvider)
            .where((item) => item.productId == product.id)
            .fold<double>(0, (sum, item) => sum + item.quantity);
    final baseError = Validators.nonZeroDouble(value);
    if (baseError != null) return baseError;
    if (product == null) return 'Select a product first';
    final ruleError = Validators.wholeNumberWhenRequired(
      value,
      allowFraction: product.allowFractionalQuantity,
    );
    if (ruleError != null) return ruleError;
    final quantity = double.tryParse(value?.trim() ?? '') ?? 0;
    if (quantity + existingInCart > product.quantity) {
      final available = (product.quantity - existingInCart).clamp(
        0,
        product.quantity,
      );
      return 'Only ${Fmt.qtyWithUnit(available, product.stockUnit)} available';
    }
    return null;
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  void _addToCart() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selected == null) return;
    ref.read(cartProvider.notifier).add(
          CartItem(
            productId: _selected!.id!,
            productName: _selected!.name,
            quantity: double.parse(_qty.text.trim()),
            retailUnitPrice: _selected!.unitPrice,
            stockUnit: _selected!.stockUnit,
            allowFractionalQuantity: _selected!.allowFractionalQuantity,
            wholesaleUnitPrice: _selected!.wholesaleUnitPrice,
            wholesaleMinQuantity: _selected!.wholesaleMinQuantity,
          ),
        );
    _qty.clear();
    setState(() => _selected = null);
  }

  Future<void> _finalizeSale() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;
    setState(() => _finalizing = true);
    try {
      await ref.read(saleRepoProvider).recordSale(cart);
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(productsProvider);
      ref.invalidate(dashboardProvider);
      _showSnack('Sale recorded successfully');
    } on AppException catch (e) {
      _showSnack(e.message, error: true);
    } catch (e) {
      _showSnack('Failed to finalize sale: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _finalizing = false);
      }
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final cart = ref.watch(cartProvider);
    final cs = Theme.of(context).colorScheme;
    final cartNotifier = ref.read(cartProvider.notifier);
    final cartTotal = cartNotifier.total;
    final totalSavings = cartNotifier.totalSavings;

    return Row(
      children: [
        SizedBox(
          width: 320,
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'New Sale',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 16),
                    productsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('$e'),
                      data: (products) {
                        final selected = _resolveSelected(products);
                        if (_selected != null && selected == null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => _selected = null);
                          });
                        }
                        return DropdownButtonFormField<Product>(
                          value: selected,
                          decoration: const InputDecoration(
                            labelText: 'Select Product',
                          ),
                          isExpanded: true,
                          items: products
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      Text(
                                        '${Fmt.currency(p.unitPrice)} per ${p.stockUnit} • Stock: ${Fmt.qtyWithUnit(p.quantity, p.stockUnit)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                      if (p.hasWholesalePricing)
                                        Text(
                                          'Wholesale: ${Fmt.currency(p.wholesaleUnitPrice!)} from ${Fmt.qtyWithUnit(p.wholesaleMinQuantity!, p.stockUnit)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF0F766E),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() => _selected = v);
                            _formKey.currentState?.validate();
                          },
                          validator: (v) => v == null ? 'Select a product' : null,
                        );
                      },
                    ),
                    if (_selected != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Retail: ${Fmt.currency(_selected!.unitPrice)} per ${_selected!.stockUnit} | Stock: ${Fmt.qtyWithUnit(_selected!.quantity, _selected!.stockUnit)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_selected!.hasWholesalePricing)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Wholesale auto-rate: ${Fmt.currency(_selected!.wholesaleUnitPrice!)} when quantity reaches ${Fmt.qtyWithUnit(_selected!.wholesaleMinQuantity!, _selected!.stockUnit)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _selected!.allowFractionalQuantity
                                    ? 'Partial sale allowed'
                                    : 'Whole quantity only',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (_selected!.hasWholesalePricing &&
                                _previewQuantity() > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  _previewQuantity() >=
                                          _selected!.wholesaleMinQuantity!
                                      ? 'Bulk rate will apply for this quantity.'
                                      : 'Add ${Fmt.qtyWithUnit(_selected!.wholesaleMinQuantity! - _previewQuantity(), _selected!.stockUnit)} more to unlock wholesale.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _qty,
                      label: _selected == null
                          ? 'Quantity'
                          : 'Quantity (${_selected!.stockUnit})',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      validator: _validateQuantity,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _addToCart,
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Add to Bill'),
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
                SectionHeader(
                  title: 'Current Bill',
                  action: cart.isEmpty
                      ? null
                      : TextButton.icon(
                          onPressed: () =>
                              ref.read(cartProvider.notifier).clear(),
                          icon: const Icon(Icons.clear_all, size: 16),
                          label: const Text('Clear'),
                        ),
                ),
                Expanded(
                  child: cart.isEmpty
                      ? const EmptyState(
                          icon: Icons.shopping_cart_outlined,
                          message: 'Add items to the bill',
                        )
                      : ListView.separated(
                          itemCount: cart.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final item = cart[i];
                            return ListTile(
                              title: Text(
                                item.productName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                '${item.pricingTierLabel}: ${Fmt.currency(item.unitPrice)} per ${item.stockUnit} • Qty: ${Fmt.qtyWithUnit(item.quantity, item.stockUnit)}'
                                '${item.isWholesaleApplied ? ' • Saved ${Fmt.currency(item.savings)}' : ''}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, size: 18),
                                    onPressed: () => ref
                                        .read(cartProvider.notifier)
                                        .decrement(item.productId),
                                    tooltip: 'Decrease quantity',
                                  ),
                                  Text(
                                    Fmt.qty(item.quantity),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add, size: 18),
                                    onPressed: () => ref
                                        .read(cartProvider.notifier)
                                        .increment(item.productId),
                                    tooltip: 'Increase quantity',
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    Fmt.currency(item.total),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(
                                      Icons.remove_circle_outline,
                                      color: cs.error,
                                      size: 18,
                                    ),
                                    onPressed: () => ref
                                        .read(cartProvider.notifier)
                                        .remove(item.productId),
                                    tooltip: 'Remove item',
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                if (cart.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Amount',
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                Fmt.currency(cartTotal),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: cs.primary,
                                    ),
                              ),
                              if (totalSavings > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Wholesale savings: ${Fmt.currency(totalSavings)}',
                                    style: const TextStyle(
                                      color: Color(0xFF0F766E),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _finalizing ? null : _finalizeSale,
                          icon: _finalizing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.receipt_long),
                          label: const Text('Finalize Sale'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

