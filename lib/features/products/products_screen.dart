import 'dart:io';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';
import '../../data/models/product.dart';
import '../../data/repos/providers.dart';
import 'product_provider.dart';
import 'reorder_planner.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  static const int demandWindowDays = 30;

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
  final _stockUnit = TextEditingController(text: 'unit');
  Product? _editing;
  String _search = '';
  String? _selectedCategory;
  bool _lowStockOnly = false;
  bool _slowMovingOnly = false;
  bool _allowFractionalQuantity = false;

  @override
  void dispose() {
    _name.dispose();
    _cat.dispose();
    _price.dispose();
    _stock.dispose();
    _min.dispose();
    _stockUnit.dispose();
    super.dispose();
  }

  void _clearForm() {
    _editing = null;
    _allowFractionalQuantity = false;
    _name.clear();
    _cat.clear();
    _price.clear();
    _stock.clear();
    _min.clear();
    _stockUnit.text = 'unit';
    _formKey.currentState?.reset();
    setState(() {});
  }

  void _loadForEdit(Product p) {
    _editing = p;
    _allowFractionalQuantity = p.allowFractionalQuantity;
    _name.text = p.name;
    _cat.text = p.category;
    _price.text = p.unitPrice.toString();
    _stock.text = p.quantity.toString();
    _min.text = p.minimumStock.toString();
    _stockUnit.text = p.stockUnit;
    setState(() {});
  }

  String? _validateStockField(String? value, {required String label}) {
    final baseError = Validators.positiveDouble(value);
    if (baseError != null) return baseError;
    final ruleError = Validators.wholeNumberWhenRequired(
      value,
      allowFraction: _allowFractionalQuantity,
      message: '$label must be a whole number for sealed products',
    );
    if (ruleError != null) return ruleError;
    return null;
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
        quantity: double.parse(_stock.text.trim()),
        minimumStock: double.parse(_min.text.trim()),
        stockUnit: _stockUnit.text.trim(),
        allowFractionalQuantity: _allowFractionalQuantity,
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
      builder: (_) => AlertDialog(
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

  void _showProductInsights(
    Product product, {
    required ProductInsightSnapshot insight,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ProductInsightsSheet(insight: insight),
    );
  }

  Future<void> _exportReorderPlan(ReorderPlan plan) async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final exportDir = Directory(p.join(appDir.path, 'exports'))
        ..createSync(recursive: true);
      final file = File(
        p.join(exportDir.path, 'reorder_plan_${Fmt.fileDate(DateTime.now())}.csv'),
      );

      final sb = StringBuffer()
        ..writeln('Reorder Plan')
        ..writeln('Generated At,${DateTime.now().toIso8601String()}')
        ..writeln('Items,${plan.totalItems}')
        ..writeln('Units,${plan.totalUnits}')
        ..writeln('Estimated Cost,${plan.totalCost}')
        ..writeln('Demand Window Days,${plan.demandWindowDays}')
        ..writeln()
        ..writeln(
          'Product,Category,Priority,Reason,Current Qty,Minimum,Target Qty,Recommended Buy,Unit,Unit Price,Estimated Cost,Avg Daily Demand,Days Of Cover,Partial Qty Allowed',
        );

      for (final suggestion in plan.suggestions) {
        final product = suggestion.product;
        sb.writeln(
          '"${product.name.replaceAll('"', '""')}","${product.category.replaceAll('"', '""')}","${suggestion.priorityLabel}","${suggestion.reason.replaceAll('"', '""')}",${product.quantity},${product.minimumStock},${suggestion.targetStock},${suggestion.recommendedQuantity},"${product.stockUnit}",${product.unitPrice},${suggestion.estimatedCost},${suggestion.averageDailyDemand},${suggestion.daysOfCover ?? ''},${product.allowFractionalQuantity ? 'Yes' : 'No'}',
        );
      }

      await file.writeAsString(sb.toString());
      if (!mounted) return;
      _showSnack('Reorder plan exported to: ${file.path}');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to export reorder plan: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final recentDemandAsync =
        ref.watch(recentProductDemandProvider(ProductsScreen.demandWindowDays));
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 340,
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: ListView(
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
                      controller: _stockUnit,
                      label: 'Stock Unit',
                      validator: Validators.required,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Examples: kg, litre, bag, packet, bottle',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Allow Partial Quantity'),
                      subtitle: Text(
                        _allowFractionalQuantity
                            ? 'Customers can buy or borrow partial ${_stockUnit.text.trim().isEmpty ? 'units' : _stockUnit.text.trim()} like 1.25'
                            : 'This product is sold only in whole pieces or sealed packs',
                      ),
                      value: _allowFractionalQuantity,
                      onChanged: (value) {
                        setState(() => _allowFractionalQuantity = value);
                        _formKey.currentState?.validate();
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _price,
                      label: 'Price per Unit (PKR)',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      validator: Validators.positiveDouble,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _stock,
                      label: 'Opening Stock',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      validator: (value) =>
                          _validateStockField(value, label: 'Opening stock'),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _min,
                      label: 'Minimum Stock',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      validator: (value) =>
                          _validateStockField(value, label: 'Minimum stock'),
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
                        onChanged: (v) => setState(() => _search = v.toLowerCase()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 180,
                      child: categoriesAsync.when(
                        loading: () => const SizedBox(
                          height: 36,
                          child: LinearProgressIndicator(),
                        ),
                        error: (_, __) => const Text(
                          'Categories unavailable',
                          overflow: TextOverflow.ellipsis,
                        ),
                        data: (categories) => DropdownButtonFormField<String?>(
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
                                child: Text(c, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => _selectedCategory = v),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilterChip(
                      label: const Text('Low stock'),
                      selected: _lowStockOnly,
                      onSelected: (v) => setState(() => _lowStockOnly = v),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Slow moving'),
                      selected: _slowMovingOnly,
                      onSelected: (v) => setState(() => _slowMovingOnly = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: productsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (products) {
                      final reorderPlan = buildReorderPlan(
                        products,
                        demandByProduct: recentDemandAsync.valueOrNull ?? const {},
                        demandWindowDays: ProductsScreen.demandWindowDays,
                      );
                      final slowMovingPlan = buildSlowMovingPlan(
                        products,
                        demandByProduct: recentDemandAsync.valueOrNull ?? const {},
                        demandWindowDays: ProductsScreen.demandWindowDays,
                      );
                      final slowMovingProductIds =
                          slowMovingPlan.suggestions
                              .map((item) => item.product.id)
                              .whereType<int>()
                              .toSet();
                      final reorderById = {
                        for (final item in reorderPlan.suggestions)
                          if (item.product.id != null) item.product.id!: item,
                      };
                      final slowMovingById = {
                        for (final item in slowMovingPlan.suggestions)
                          if (item.product.id != null) item.product.id!: item,
                      };
                      final filtered = products
                          .where(
                            (p) =>
                                _search.isEmpty ||
                                p.name.toLowerCase().contains(_search) ||
                                p.category.toLowerCase().contains(_search) ||
                                p.stockUnit.toLowerCase().contains(_search),
                          )
                          .where(
                            (p) =>
                                _selectedCategory == null ||
                                p.category == _selectedCategory,
                          )
                          .where((p) => !_lowStockOnly || p.isLowStock)
                          .where(
                            (p) =>
                                !_slowMovingOnly ||
                                (p.id != null && slowMovingProductIds.contains(p.id)),
                          )
                          .toList();
                      if (filtered.isEmpty) {
                        return const EmptyState(
                          icon: Icons.inventory_2,
                          message: 'No products found',
                        );
                      }
                      return Column(
                        children: [
                          if (!reorderPlan.isEmpty) ...[
                            _ReorderPlannerCard(
                              plan: reorderPlan,
                              demandLoading: recentDemandAsync.isLoading,
                              onExport: () => _exportReorderPlan(reorderPlan),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (!slowMovingPlan.isEmpty) ...[
                            _SlowMovingInventoryCard(plan: slowMovingPlan),
                            const SizedBox(height: 12),
                          ],
                          Expanded(
                            child: DataTable2(
                              columnSpacing: 16,
                              horizontalMargin: 12,
                              columns: const [
                                DataColumn2(label: Text('Name'), size: ColumnSize.L),
                                DataColumn2(label: Text('Category')),
                                DataColumn2(label: Text('Unit')),
                                DataColumn2(label: Text('Price'), numeric: true),
                                DataColumn2(label: Text('Qty'), numeric: true),
                                DataColumn2(label: Text('Min'), numeric: true),
                                DataColumn2(label: Text('Partial')),
                                DataColumn2(label: Text('Value'), numeric: true),
                                DataColumn2(label: Text('Status'), size: ColumnSize.S),
                                DataColumn2(label: Text(''), size: ColumnSize.S),
                              ],
                              rows: filtered
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
                                        DataCell(Text(p.stockUnit)),
                                        DataCell(
                                          Text(
                                            '${Fmt.currency(p.unitPrice)}/${p.stockUnit}',
                                          ),
                                        ),
                                        DataCell(
                                          Text(Fmt.qtyWithUnit(p.quantity, p.stockUnit)),
                                        ),
                                        DataCell(
                                          Text(
                                            Fmt.qtyWithUnit(
                                              p.minimumStock,
                                              p.stockUnit,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            p.allowFractionalQuantity ? 'Yes' : 'No',
                                          ),
                                        ),
                                        DataCell(Text(Fmt.currency(p.totalValue))),
                                        DataCell(
                                          _ProductStatusChip(
                                            product: p,
                                            isSlowMoving:
                                                p.id != null &&
                                                slowMovingProductIds.contains(
                                                  p.id,
                                                ),
                                          ),
                                        ),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.insights_outlined,
                                                  size: 18,
                                                ),
                                                onPressed: () {
                                                  final insight =
                                                      buildProductInsightSnapshot(
                                                    p,
                                                    demand:
                                                        p.id == null
                                                            ? null
                                                            : recentDemandAsync
                                                                .valueOrNull?[p.id],
                                                    reorderSuggestion:
                                                        p.id == null
                                                            ? null
                                                            : reorderById[p.id],
                                                    slowMovingSuggestion:
                                                        p.id == null
                                                            ? null
                                                            : slowMovingById[p.id],
                                                    demandWindowDays:
                                                        ProductsScreen
                                                            .demandWindowDays,
                                                  );
                                                  _showProductInsights(
                                                    p,
                                                    insight: insight,
                                                  );
                                                },
                                                tooltip: 'Insights',
                                              ),
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
                            ),
                          ),
                        ],
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

class _ReorderPlannerCard extends StatelessWidget {
  const _ReorderPlannerCard({
    required this.plan,
    required this.demandLoading,
    required this.onExport,
  });

  final ReorderPlan plan;
  final bool demandLoading;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SectionHeader(
              title: 'Reorder Planner',
              action: FilledButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export CSV'),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _PlannerMetric(
                    label: 'Critical Items',
                    value: plan.criticalItems.toString(),
                    icon: Icons.warning_amber_rounded,
                    color: cs.error,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PlannerMetric(
                    label: 'Demand Signals',
                    value: plan.demandDrivenItems.toString(),
                    icon: Icons.insights_outlined,
                    color: const Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PlannerMetric(
                    label: 'Avg Cover Days',
                    value:
                        plan.averageCoverDays == null
                            ? '--'
                            : Fmt.qty(plan.averageCoverDays!),
                    icon: Icons.event_available_outlined,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PlannerMetric(
                    label: 'Estimated Spend',
                    value: Fmt.currency(plan.totalCost),
                    icon: Icons.payments_outlined,
                    color: const Color(0xFF7C2D12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                demandLoading
                    ? 'Refreshing demand signals from the last ${plan.demandWindowDays} days...'
                    : 'Smart priorities use the last ${plan.demandWindowDays} days of sales to estimate stock cover and urgency.',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...plan.suggestions.take(5).map(
              (suggestion) => ListTile(
                contentPadding: EdgeInsets.zero,
                isThreeLine: true,
                leading: CircleAvatar(
                  backgroundColor: _priorityColor(context, suggestion).withValues(
                    alpha: 0.14,
                  ),
                  foregroundColor: _priorityColor(context, suggestion),
                  child: Text(
                    suggestion.priorityLabel.substring(0, 1),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                title: Text(
                  '${suggestion.product.name} (${Fmt.qtyWithUnit(suggestion.recommendedQuantity, suggestion.product.stockUnit)})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${suggestion.priorityLabel} - ${suggestion.reason}\n'
                  '${suggestion.product.category} - in stock ${Fmt.qtyWithUnit(suggestion.product.quantity, suggestion.product.stockUnit)} - target ${Fmt.qtyWithUnit(suggestion.targetStock, suggestion.product.stockUnit)}'
                  '${suggestion.daysOfCover == null ? '' : ' - cover ${Fmt.qty(suggestion.daysOfCover!)} days'}'
                  '${suggestion.averageDailyDemand > 0 ? ' - avg ${Fmt.qtyWithUnit(suggestion.averageDailyDemand, suggestion.product.stockUnit)}/day' : ''}',
                ),
                trailing: Text(
                  Fmt.currency(suggestion.estimatedCost),
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (plan.totalItems > 5)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '+${plan.totalItems - 5} more items need restocking',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _priorityColor(BuildContext context, ReorderSuggestion suggestion) {
    final cs = Theme.of(context).colorScheme;
    switch (suggestion.priorityLabel) {
      case 'Critical':
        return cs.error;
      case 'High':
        return const Color(0xFFB45309);
      case 'Medium':
        return const Color(0xFF0F766E);
      default:
        return cs.primary;
    }
  }
}

class _SlowMovingInventoryCard extends StatelessWidget {
  const _SlowMovingInventoryCard({required this.plan});

  final SlowMovingPlan plan;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SectionHeader(title: 'Slow-Moving Stock'),
            Row(
              children: [
                Expanded(
                  child: _PlannerMetric(
                    label: 'Quiet Items',
                    value: plan.totalItems.toString(),
                    icon: Icons.inventory_outlined,
                    color: const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PlannerMetric(
                    label: 'Excess Units',
                    value: Fmt.qty(plan.excessUnits),
                    icon: Icons.layers_outlined,
                    color: const Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PlannerMetric(
                    label: 'Cash Tied Up',
                    value: Fmt.currency(plan.tiedUpValue),
                    icon: Icons.account_balance_wallet_outlined,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'These products have more stock than they need based on the last ${plan.demandWindowDays} days of sales.',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...plan.suggestions.take(3).map(
              (suggestion) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: cs.secondaryContainer,
                  foregroundColor: cs.onSecondaryContainer,
                  child: const Icon(Icons.hourglass_bottom_rounded, size: 18),
                ),
                title: Text(
                  suggestion.product.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${suggestion.reason}\n'
                  'Excess ${Fmt.qtyWithUnit(suggestion.excessUnits, suggestion.product.stockUnit)} - value ${Fmt.currency(suggestion.inventoryValue)}',
                ),
                isThreeLine: true,
                trailing: suggestion.daysOfCover == null
                    ? null
                    : Text(
                        '${Fmt.qty(suggestion.daysOfCover!)} d',
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            if (plan.totalItems > 3)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '+${plan.totalItems - 3} more items look slow moving',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductStatusChip extends StatelessWidget {
  const _ProductStatusChip({
    required this.product,
    required this.isSlowMoving,
  });

  final Product product;
  final bool isSlowMoving;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    late final String label;
    late final Color backgroundColor;
    late final Color foregroundColor;

    if (product.isLowStock) {
      label = 'Low';
      backgroundColor = cs.error;
      foregroundColor = cs.onError;
    } else if (isSlowMoving) {
      label = 'Slow';
      backgroundColor = cs.secondaryContainer;
      foregroundColor = cs.onSecondaryContainer;
    } else {
      label = 'OK';
      backgroundColor = cs.primary;
      foregroundColor = cs.onPrimary;
    }

    return Chip(
      label: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 11,
        ),
      ),
      backgroundColor: backgroundColor,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ProductInsightsSheet extends StatelessWidget {
  const _ProductInsightsSheet({required this.insight});

  final ProductInsightSnapshot insight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final product = insight.product;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                product.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                '${product.category} • ${product.stockUnit}',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 180,
                    child: _PlannerMetric(
                      label: 'Status',
                      value: insight.statusLabel,
                      icon: Icons.health_and_safety_outlined,
                      color: _insightColor(context, insight),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: _PlannerMetric(
                      label: 'Stock On Hand',
                      value: Fmt.qtyWithUnit(product.quantity, product.stockUnit),
                      icon: Icons.inventory_2_outlined,
                      color: cs.primary,
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: _PlannerMetric(
                      label: 'Daily Demand',
                      value: insight.averageDailyDemand > 0
                          ? Fmt.qtyWithUnit(
                              insight.averageDailyDemand,
                              product.stockUnit,
                            )
                          : 'No signal',
                      icon: Icons.show_chart_rounded,
                      color: const Color(0xFF0F766E),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: _PlannerMetric(
                      label: 'Inventory Value',
                      value: Fmt.currency(insight.inventoryValue),
                      icon: Icons.payments_outlined,
                      color: const Color(0xFF7C2D12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _insightColor(context, insight).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  insight.summary,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),
              if (insight.daysOfCover != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.event_available_outlined,
                    color: cs.primary,
                  ),
                  title: const Text('Estimated Stock Cover'),
                  subtitle: Text(
                    '${Fmt.qty(insight.daysOfCover!)} days at the current sales pace',
                  ),
                ),
              if (insight.reorderSuggestion != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.shopping_cart_checkout_rounded,
                    color: cs.error,
                  ),
                  title: const Text('Recommended Restock'),
                  subtitle: Text(
                    'Buy ${Fmt.qtyWithUnit(insight.reorderSuggestion!.recommendedQuantity, product.stockUnit)} to reach ${Fmt.qtyWithUnit(insight.reorderSuggestion!.targetStock, product.stockUnit)}.',
                  ),
                ),
              if (insight.slowMovingSuggestion != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.hourglass_bottom_rounded,
                    color: cs.secondary,
                  ),
                  title: const Text('Slow-Moving Stock'),
                  subtitle: Text(
                    'Excess stock is about ${Fmt.qtyWithUnit(insight.slowMovingSuggestion!.excessUnits, product.stockUnit)} worth ${Fmt.currency(insight.slowMovingSuggestion!.inventoryValue)}.',
                  ),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  product.allowFractionalQuantity
                      ? Icons.straighten
                      : Icons.inventory,
                  color: cs.onSurfaceVariant,
                ),
                title: const Text('Selling Rule'),
                subtitle: Text(
                  product.allowFractionalQuantity
                      ? 'This item can be sold in partial quantities.'
                      : 'This item should be sold only in whole units.',
                ),
              ),
              if (!insight.needsAttention)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.check_circle_outline,
                    color: cs.primary,
                  ),
                  title: const Text('Recommendation'),
                  subtitle: const Text(
                    'No immediate action needed. Keep watching demand and refresh stock only when sales pick up.',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _insightColor(BuildContext context, ProductInsightSnapshot insight) {
    final cs = Theme.of(context).colorScheme;
    switch (insight.statusLabel) {
      case 'Critical':
        return cs.error;
      case 'High':
        return const Color(0xFFB45309);
      case 'Medium':
        return const Color(0xFF0F766E);
      case 'Slow Moving':
        return cs.secondary;
      default:
        return cs.primary;
    }
  }
}

class _PlannerMetric extends StatelessWidget {
  const _PlannerMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

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
