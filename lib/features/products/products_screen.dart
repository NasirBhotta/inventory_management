import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/product.dart';
import '../../data/repos/providers.dart';
import 'product_provider.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});
  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _cat = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController();
  final _min = TextEditingController();
  Product? _editing;
  String _search = '';
  String? _selectedCategory;
  bool _lowStockOnly = false;

  @override
  void dispose() {
    _name.dispose();
    _cat.dispose();
    _price.dispose();
    _stock.dispose();
    _min.dispose();
    super.dispose();
  }

  void _clearForm() {
    _editing = null;
    _name.clear();
    _cat.clear();
    _price.clear();
    _stock.clear();
    _min.clear();
    _formKey.currentState?.reset();
  }

  void _loadForEdit(Product p) {
    _editing = p;
    _name.text = p.name;
    _cat.text = p.category;
    _price.text = p.unitPrice.toString();
    _stock.text = p.quantity.toString();
    _min.text = p.minimumStock.toString();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final repo = ref.read(productRepoProvider);
    try {
      final product = Product(
        id: _editing?.id,
        name: _name.text.trim(),
        category: _cat.text.trim(),
        unitPrice: double.parse(_price.text.trim()),
        quantity: int.parse(_stock.text.trim()),
        minimumStock: int.parse(_min.text.trim()),
      );
      if (_editing == null) {
        await repo.insert(product);
        _showSnack('Product added');
      } else {
        await repo.update(product);
        _showSnack('Product updated');
      }
      _clearForm();
      ref.invalidate(productsProvider);
      ref.invalidate(categoriesProvider);
    } on AppException catch (e) {
      _showSnack(e.message, error: true);
    }
  }

  Future<void> _delete(Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete Product'),
            content: Text('Delete "${p.name}"? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (ok == true) {
      await ref.read(productRepoProvider).delete(p.id!);
      ref.invalidate(productsProvider);
      ref.invalidate(categoriesProvider);
      _showSnack('Deleted "${p.name}"');
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
    final categoriesAsync = ref.watch(categoriesProvider);
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
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
                      _editing == null ? 'Add Product' : 'Edit Product',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _name,
                      label: 'Product Name',
                      validator: Validators.required,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _cat,
                      label: 'Category',
                      validator: Validators.required,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _price,
                      label: 'Unit Price (PKR)',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      validator: Validators.positiveDouble,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _stock,
                      label: 'Opening Stock',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: Validators.positiveInt,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _min,
                      label: 'Minimum Stock',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: Validators.positiveInt,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _submit,
                      child: Text(_editing == null ? 'Add Product' : 'Update'),
                    ),
                    if (_editing != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _clearForm,
                        child: const Text('Cancel'),
                      ),
                    ],
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
                const SectionHeader(title: 'Product Catalog'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search products...',
                          prefixIcon: Icon(Icons.search, size: 18),
                          isDense: true,
                        ),
                        onChanged:
                            (v) => setState(() => _search = v.toLowerCase()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 180,
                      child: categoriesAsync.when(
                        loading:
                            () => const SizedBox(
                              height: 36,
                              child: LinearProgressIndicator(),
                            ),
                        error:
                            (_, __) => const Text(
                              'Categories unavailable',
                              overflow: TextOverflow.ellipsis,
                            ),
                        data:
                            (categories) => DropdownButtonFormField<String?>(
                              isExpanded: true,
                              value: _selectedCategory,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('All'),
                                ),
                                ...categories.map(
                                  (c) => DropdownMenuItem<String?>(
                                    value: c,
                                    child: Text(
                                      c,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged:
                                  (v) => setState(() => _selectedCategory = v),
                            ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilterChip(
                      label: const Text('Low stock'),
                      selected: _lowStockOnly,
                      onSelected: (v) => setState(() => _lowStockOnly = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: productsAsync.when(
                    loading:
                        () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (products) {
                      final filtered =
                          products
                              .where(
                                (p) =>
                                    _search.isEmpty ||
                                    p.name.toLowerCase().contains(_search) ||
                                    p.category.toLowerCase().contains(_search),
                              )
                              .where(
                                (p) =>
                                    _selectedCategory == null ||
                                    p.category == _selectedCategory,
                              )
                              .where((p) => !_lowStockOnly || p.isLowStock)
                              .toList();
                      if (filtered.isEmpty) {
                        return const EmptyState(
                          icon: Icons.inventory_2,
                          message: 'No products found',
                        );
                      }
                      return DataTable2(
                        columnSpacing: 16,
                        horizontalMargin: 12,
                        columns: const [
                          DataColumn2(label: Text('Name'), size: ColumnSize.L),
                          DataColumn2(label: Text('Category')),
                          DataColumn2(label: Text('Price'), numeric: true),
                          DataColumn2(label: Text('Qty'), numeric: true),
                          DataColumn2(label: Text('Min'), numeric: true),
                          DataColumn2(label: Text('Value'), numeric: true),
                          DataColumn2(
                            label: Text('Status'),
                            size: ColumnSize.S,
                          ),
                          DataColumn2(label: Text(''), size: ColumnSize.S),
                        ],
                        rows:
                            filtered
                                .map(
                                  (p) => DataRow2(
                                    cells: [
                                      DataCell(
                                        Text(
                                          p.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      DataCell(Text(p.category)),
                                      DataCell(Text(Fmt.currency(p.unitPrice))),
                                      DataCell(Text(Fmt.qty(p.quantity))),
                                      DataCell(Text(p.minimumStock.toString())),
                                      DataCell(Text(Fmt.currency(p.totalValue))),
                                      DataCell(
                                        p.isLowStock
                                            ? Chip(
                                              label: Text(
                                                'Low',
                                                style: TextStyle(
                                                  color: cs.onError,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              backgroundColor: cs.error,
                                              padding: EdgeInsets.zero,
                                              visualDensity:
                                                  VisualDensity.compact,
                                            )
                                            : Chip(
                                              label: Text(
                                                'OK',
                                                style: TextStyle(
                                                  color: cs.onPrimary,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              backgroundColor: cs.primary,
                                              padding: EdgeInsets.zero,
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 18,
                                              ),
                                              onPressed: () => _loadForEdit(p),
                                              tooltip: 'Edit',
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.delete_outline,
                                                size: 18,
                                                color: cs.error,
                                              ),
                                              onPressed: () => _delete(p),
                                              tooltip: 'Delete',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
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
