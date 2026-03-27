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
import '../../data/models/stock_movement.dart';
import '../../data/repos/providers.dart';
import '../products/product_provider.dart';
import 'stock_provider.dart';

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  final _formKey = GlobalKey<FormState>();
  Product? _selected;
  MovementType _type = MovementType.in_;
  MovementType? _historyType;
  String _historySearch = '';
  final _qty = TextEditingController();
  final _note = TextEditingController();

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
    final baseError = Validators.nonZeroDouble(value);
    if (baseError != null) return baseError;
    if (product == null) return 'Select a product first';
    final ruleError = Validators.wholeNumberWhenRequired(
      value,
      allowFraction: product.allowFractionalQuantity,
      message: 'This product only allows whole-number stock changes',
    );
    if (ruleError != null) return ruleError;
    final quantity = double.tryParse(value?.trim() ?? '') ?? 0;
    if (_type == MovementType.out && quantity > product.quantity) {
      return 'Only ${Fmt.qtyWithUnit(product.quantity, product.stockUnit)} available';
    }
    return null;
  }

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selected == null) {
      _showSnack('Select a product', error: true);
      return;
    }
    try {
      await ref.read(stockRepoProvider).move(
            productId: _selected!.id!,
            type: _type,
            quantity: double.parse(_qty.text.trim()),
            note: _note.text,
          );
      _qty.clear();
      _note.clear();
      ref.invalidate(stockMovementsProvider);
      ref.invalidate(productsProvider);
      _showSnack('Stock ${_type.label} recorded');
    } on AppException catch (e) {
      _showSnack(e.message, error: true);
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
    final movementsAsync = ref.watch(stockMovementsProvider);
    final cs = Theme.of(context).colorScheme;

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
                      'Stock Movement',
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
                                  child: Text(
                                    '${p.name} (${Fmt.qtyWithUnit(p.quantity, p.stockUnit)})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() => _selected = v);
                            _formKey.currentState?.validate();
                          },
                          validator: (v) => v == null ? 'Required' : null,
                        );
                      },
                    ),
                    if (_selected != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Current stock: ${Fmt.qtyWithUnit(_selected!.quantity, _selected!.stockUnit)} • ${_selected!.allowFractionalQuantity ? 'Partial changes allowed' : 'Whole quantity only'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SegmentedButton<MovementType>(
                      segments: const [
                        ButtonSegment(
                          value: MovementType.in_,
                          label: Text('Stock IN'),
                          icon: Icon(Icons.add_circle_outline),
                        ),
                        ButtonSegment(
                          value: MovementType.out,
                          label: Text('Stock OUT'),
                          icon: Icon(Icons.remove_circle_outline),
                        ),
                      ],
                      selected: {_type},
                      onSelectionChanged: (s) {
                        setState(() => _type = s.first);
                        _formKey.currentState?.validate();
                      },
                    ),
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
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _note,
                      label: 'Note (optional)',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _submit,
                      icon: Icon(
                        _type == MovementType.in_ ? Icons.add : Icons.remove,
                      ),
                      label: Text('Record ${_type.label}'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () {
                        setState(() => _selected = null);
                        _qty.clear();
                        _note.clear();
                      },
                      child: const Text('Clear Form'),
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
                const SectionHeader(title: 'Movement History'),
                Row(
                  children: [
                    SegmentedButton<MovementType?>(
                      segments: const [
                        ButtonSegment<MovementType?>(value: null, label: Text('All')),
                        ButtonSegment<MovementType?>(
                          value: MovementType.in_,
                          label: Text('IN'),
                        ),
                        ButtonSegment<MovementType?>(
                          value: MovementType.out,
                          label: Text('OUT'),
                        ),
                      ],
                      selected: {_historyType},
                      onSelectionChanged: (s) => setState(() => _historyType = s.first),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'Search by product or note...',
                          prefixIcon: Icon(Icons.search, size: 18),
                        ),
                        onChanged: (v) => setState(() => _historySearch = v.toLowerCase()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: movementsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('$e')),
                    data: (movements) {
                      final filtered = movements
                          .where((m) => _historyType == null || m.type == _historyType)
                          .where((m) {
                        if (_historySearch.isEmpty) return true;
                        return m.productName.toLowerCase().contains(_historySearch) ||
                            m.note.toLowerCase().contains(_historySearch);
                      }).toList();
                      if (filtered.isEmpty) {
                        return const EmptyState(
                          icon: Icons.swap_horiz,
                          message: 'No matching movements',
                        );
                      }
                      return ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final m = filtered[i];
                          final isIn = m.type == MovementType.in_;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  (isIn ? Colors.green : cs.error).withValues(alpha: 0.1),
                              child: Icon(
                                isIn ? Icons.arrow_downward : Icons.arrow_upward,
                                color: isIn ? Colors.green : cs.error,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              m.productName,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              m.note.isEmpty
                                  ? Fmt.dateTime(m.movementDate)
                                  : '${m.note} • ${Fmt.dateTime(m.movementDate)}',
                            ),
                            trailing: Text(
                              '${isIn ? '+' : '-'}${Fmt.qtyWithUnit(m.quantity, m.stockUnit)}',
                              style: TextStyle(
                                color: isIn ? Colors.green : cs.error,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
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
}
