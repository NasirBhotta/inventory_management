import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/empty_state.dart';
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

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  void _addToCart() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selected == null) return;
    ref
        .read(cartProvider.notifier)
        .add(
          CartItem(
            productId: _selected!.id!,
            productName: _selected!.name,
            quantity: int.parse(_qty.text.trim()),
            unitPrice: _selected!.unitPrice,
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
      _showSnack('Sale recorded successfully!');
    } on AppException catch (e) {
      _showSnack(e.message, error: true);
    } catch (e) {
      _showSnack('Failed to finalize sale: $e', error: true);
    } finally {
      setState(() => _finalizing = false);
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
    final cartTotal = ref.read(cartProvider.notifier).total;

    return Row(
      children: [
        // ── Add Item Form ─────────────────────────────────────────────────
        SizedBox(
          width: 300,
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
                      data:
                          (products) => DropdownButtonFormField<Product>(
                            value: _selected,
                            decoration: const InputDecoration(
                              labelText: 'Select Product',
                            ),
                            isExpanded: true,
                            items:
                                products
                                    .map(
                                      (p) => DropdownMenuItem(
                                        value: p,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.name,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              '${Fmt.currency(p.unitPrice)} • Qty: ${p.quantity}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: cs.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) => setState(() => _selected = v),
                            validator:
                                (v) => v == null ? 'Select a product' : null,
                          ),
                    ),
                    if (_selected != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Price: ${Fmt.currency(_selected!.unitPrice)} | Stock: ${_selected!.quantity}',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _qty,
                      label: 'Quantity',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: Validators.nonZeroInt,
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
        // ── Cart ──────────────────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SectionHeader(
                  title: 'Current Bill',
                  action:
                      cart.isEmpty
                          ? null
                          : TextButton.icon(
                            onPressed:
                                () => ref.read(cartProvider.notifier).clear(),
                            icon: const Icon(Icons.clear_all, size: 16),
                            label: const Text('Clear'),
                          ),
                ),
                Expanded(
                  child:
                      cart.isEmpty
                          ? const EmptyState(
                            icon: Icons.shopping_cart_outlined,
                            message: 'Add items to the bill',
                          )
                          : ListView.separated(
                            itemCount: cart.length,
                            separatorBuilder:
                                (_, __) => const Divider(height: 1),
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
                                  '${Fmt.currency(item.unitPrice)} × ${item.quantity}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove, size: 18),
                                      onPressed:
                                          () => ref
                                              .read(cartProvider.notifier)
                                              .decrement(item.productId),
                                      tooltip: 'Decrease quantity',
                                    ),
                                    Text(
                                      item.quantity.toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 18),
                                      onPressed:
                                          () => ref
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
                                      onPressed:
                                          () => ref
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
                // ── Total + Finalize ────────────────────────────────────
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
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _finalizing ? null : _finalizeSale,
                          icon:
                              _finalizing
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
