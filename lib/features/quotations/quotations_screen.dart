import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/external_launcher.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/product.dart';
import '../../data/models/quotation.dart';
import '../../data/repos/providers.dart';
import '../debts/debt_message.dart';
import '../products/product_provider.dart';
import '../sales/cart_provider.dart';
import 'quotation_provider.dart';
import 'quote_cart_provider.dart';

class QuotationsScreen extends ConsumerStatefulWidget {
  const QuotationsScreen({super.key});

  @override
  ConsumerState<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends ConsumerState<QuotationsScreen> {
  final _quoteFormKey = GlobalKey<FormState>();
  final _itemFormKey = GlobalKey<FormState>();
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();
  final _note = TextEditingController();
  final _quantity = TextEditingController();

  Product? _selectedProduct;
  String _search = '';
  QuotationStatus? _statusFilter;

  @override
  void dispose() {
    _customerName.dispose();
    _customerPhone.dispose();
    _note.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Product? _resolveSelected(List<Product> products) {
    final selectedId = _selectedProduct?.id;
    if (selectedId == null) return null;
    for (final product in products) {
      if (product.id == selectedId) return product;
    }
    return null;
  }

  String? _validateQuantity(String? value) {
    final product = _selectedProduct;
    final baseError = Validators.nonZeroDouble(value);
    if (baseError != null) return baseError;
    if (product == null) return 'Select a product first';
    final ruleError = Validators.wholeNumberWhenRequired(
      value,
      allowFraction: product.allowFractionalQuantity,
      message: 'This product can only be quoted in whole quantities',
    );
    if (ruleError != null) return ruleError;
    final quantity = double.tryParse(value?.trim() ?? '') ?? 0;
    if (quantity > product.quantity) {
      return 'Only ${Fmt.qtyWithUnit(product.quantity, product.stockUnit)} available';
    }
    return null;
  }

  void _addItem() {
    if (!(_itemFormKey.currentState?.validate() ?? false)) return;
    final product = _selectedProduct;
    if (product == null) return;

    ref.read(quoteCartProvider.notifier).add(
          CartItem(
            productId: product.id!,
            productName: product.name,
            quantity: double.parse(_quantity.text.trim()),
            retailUnitPrice: product.unitPrice,
            stockUnit: product.stockUnit,
            allowFractionalQuantity: product.allowFractionalQuantity,
            wholesaleUnitPrice: product.wholesaleUnitPrice,
            wholesaleMinQuantity: product.wholesaleMinQuantity,
          ),
        );
    _quantity.clear();
    setState(() => _selectedProduct = null);
  }

  Future<void> _saveQuotation() async {
    if (!(_quoteFormKey.currentState?.validate() ?? false)) return;
    final items = ref.read(quoteCartProvider);
    try {
      await ref.read(quotationRepoProvider).create(
            customerName: _customerName.text,
            customerPhone: _customerPhone.text,
            note: _note.text,
            items: items,
          );
      ref.read(quoteCartProvider.notifier).clear();
      _customerName.clear();
      _customerPhone.clear();
      _note.clear();
      _quantity.clear();
      setState(() => _selectedProduct = null);
      ref.invalidate(quotationsProvider);
      _showSnack('Quotation saved');
    } on AppException catch (e) {
      _showSnack(e.message, error: true);
    } catch (e) {
      _showSnack('Failed to save quotation: $e', error: true);
    }
  }

  Future<void> _shareQuotation(Quotation quotation) async {
    try {
      final details = await ref.read(quotationRepoProvider).getDetails(quotation.id!);
      final phone = normalizeWhatsAppPhone(quotation.customerPhone);
      if (phone.isEmpty) {
        _showSnack('Add a valid WhatsApp number to share this quotation', error: true);
        return;
      }
      final message = _buildQuotationMessage(details);
      final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
      await launchExternalUrl(url);
      await ref.read(quotationRepoProvider).markSent(quotation.id!);
      ref.invalidate(quotationsProvider);
      _showSnack('Quotation shared on WhatsApp');
    } on AppException catch (e) {
      _showSnack(e.message, error: true);
    } catch (e) {
      _showSnack('Could not share quotation: $e', error: true);
    }
  }

  Future<void> _loadToSales(Quotation quotation) async {
    try {
      final details = await ref.read(quotationRepoProvider).getDetails(quotation.id!);
      final salesCart = ref.read(cartProvider.notifier);
      for (final item in details.items) {
        salesCart.add(item);
      }
      await ref.read(quotationRepoProvider).markConverted(quotation.id!);
      ref.invalidate(quotationsProvider);
      _showSnack('Quotation loaded into Sales bill');
    } on AppException catch (e) {
      _showSnack(e.message, error: true);
    } catch (e) {
      _showSnack('Could not load quotation into Sales: $e', error: true);
    }
  }

  String _buildQuotationMessage(QuotationDetails details) {
    final lines = <String>[
      'Assalam-o-Alaikum ${details.quotation.customerName},',
      'Here is your quotation from the shop.',
      'Total: ${Fmt.currency(details.quotation.totalAmount)}',
      'Items:',
    ];

    for (final item in details.items) {
      lines.add(
        '- ${item.productName}: ${Fmt.qtyWithUnit(item.quantity, item.stockUnit)} x ${Fmt.currency(item.unitPrice)} (${item.pricingTierLabel}) = ${Fmt.currency(item.total)}',
      );
    }

    if (details.quotation.note.trim().isNotEmpty) {
      lines.add('Note: ${details.quotation.note.trim()}');
    }
    lines.add('Thank you.');
    return lines.join('\n');
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
    final quotationsAsync = ref.watch(quotationsProvider);
    final quoteCart = ref.watch(quoteCartProvider);
    final quoteCartNotifier = ref.read(quoteCartProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 360,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _quoteFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Quotation Desk',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _customerName,
                          label: 'Customer Name',
                          validator: Validators.required,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _customerPhone,
                          label: 'WhatsApp Number',
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _note,
                          label: 'Quotation Note',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Draft Total',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                Fmt.currency(quoteCartNotifier.total),
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: cs.primary,
                                    ),
                              ),
                              Text(
                                '${quoteCart.length} item(s) ready to save or share later',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: quoteCart.isEmpty ? null : _saveQuotation,
                          icon: const Icon(Icons.note_add_outlined),
                          label: const Text('Save Quotation'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _itemFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Add Item',
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
                            if (_selectedProduct != null && selected == null) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) setState(() => _selectedProduct = null);
                              });
                            }
                            return DropdownButtonFormField<Product>(
                              value: selected,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Product'),
                              items: products
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
                                setState(() => _selectedProduct = value);
                                _itemFormKey.currentState?.validate();
                              },
                              validator: (value) => value == null ? 'Select a product' : null,
                            );
                          },
                        ),
                        if (_selectedProduct != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Retail ${Fmt.currency(_selectedProduct!.unitPrice)} per ${_selectedProduct!.stockUnit}${_selectedProduct!.hasWholesalePricing ? ' | Wholesale ${Fmt.currency(_selectedProduct!.wholesaleUnitPrice!)} from ${Fmt.qtyWithUnit(_selectedProduct!.wholesaleMinQuantity!, _selectedProduct!.stockUnit)}' : ''}',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                        ],
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _quantity,
                          label: _selectedProduct == null
                              ? 'Quantity'
                              : 'Quantity (${_selectedProduct!.stockUnit})',
                          validator: _validateQuantity,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonalIcon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add_shopping_cart),
                          label: const Text('Add to Quote'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SectionHeader(
                  title: 'Quotation Pipeline',
                  action: SizedBox(
                    width: 320,
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search by customer, phone or note...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        isDense: true,
                      ),
                      onChanged: (value) => setState(() => _search = value.toLowerCase()),
                    ),
                  ),
                ),
                quotationsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('Error: $e'),
                  ),
                  data: (quotes) {
                    final draftValue = quotes
                        .where((quote) => quote.status != QuotationStatus.converted)
                        .fold<double>(0, (sum, quote) => sum + quote.totalAmount);
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _QuoteMetric(
                                label: 'Active Quotes',
                                value: quotes
                                    .where((quote) => quote.status != QuotationStatus.converted)
                                    .length
                                    .toString(),
                                color: cs.primary,
                                icon: Icons.description_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QuoteMetric(
                                label: 'Quoted Value',
                                value: Fmt.currency(draftValue),
                                color: const Color(0xFF0F766E),
                                icon: Icons.payments_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QuoteMetric(
                                label: 'Converted',
                                value: quotes
                                    .where((quote) => quote.status == QuotationStatus.converted)
                                    .length
                                    .toString(),
                                color: const Color(0xFF7C2D12),
                                icon: Icons.trending_up_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 180,
                            child: DropdownButtonFormField<QuotationStatus?>(
                              value: _statusFilter,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<QuotationStatus?>(
                                  value: null,
                                  child: Text('All'),
                                ),
                                ...QuotationStatus.values.map(
                                  (status) => DropdownMenuItem<QuotationStatus?>(
                                    value: status,
                                    child: Text(status.label),
                                  ),
                                ),
                              ],
                              onChanged: (value) => setState(() => _statusFilter = value),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: quotationsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (quotes) {
                      final filtered = quotes.where((quote) {
                        if (_statusFilter != null && quote.status != _statusFilter) {
                          return false;
                        }
                        if (_search.isEmpty) return true;
                        final haystack = [
                          quote.customerName,
                          quote.customerPhone,
                          quote.note,
                        ].join(' ').toLowerCase();
                        return haystack.contains(_search);
                      }).toList();

                      if (filtered.isEmpty) {
                        return quoteCart.isEmpty
                            ? const EmptyState(
                                icon: Icons.request_quote_outlined,
                                message: 'No quotations yet',
                              )
                            : ListView(
                                children: [
                                  Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SectionHeader(title: 'Current Draft Items'),
                                          ...quoteCart.map(
                                            (item) => ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: Text(item.productName),
                                              subtitle: Text(
                                                '${item.pricingTierLabel} | ${Fmt.qtyWithUnit(item.quantity, item.stockUnit)} x ${Fmt.currency(item.unitPrice)}',
                                              ),
                                              trailing: Text(Fmt.currency(item.total)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                      }

                      return ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final quote = filtered[index];
                          final statusColor = _statusColor(context, quote.status);
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: statusColor.withValues(alpha: 0.12),
                                        foregroundColor: statusColor,
                                        child: Icon(_statusIcon(quote.status), size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    quote.customerName,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                                _QuoteStatusBadge(
                                                  label: quote.status.label,
                                                  color: statusColor,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              quote.customerPhone.trim().isEmpty
                                                  ? 'No WhatsApp number saved'
                                                  : quote.customerPhone,
                                              style: TextStyle(color: cs.onSurfaceVariant),
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 10,
                                              runSpacing: 10,
                                              children: [
                                                _QuotePill(label: '${quote.itemCount} item(s)'),
                                                _QuotePill(label: Fmt.currency(quote.totalAmount)),
                                                _QuotePill(label: 'Created ${Fmt.date(quote.createdAt)}'),
                                              ],
                                            ),
                                            if (quote.note.trim().isNotEmpty) ...[
                                              const SizedBox(height: 10),
                                              Text(quote.note),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      FilledButton.tonalIcon(
                                        onPressed: () => _shareQuotation(quote),
                                        icon: const Icon(Icons.chat_outlined),
                                        label: const Text('WhatsApp Quote'),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton.icon(
                                        onPressed: quote.status == QuotationStatus.converted
                                            ? null
                                            : () => _loadToSales(quote),
                                        icon: const Icon(Icons.point_of_sale_outlined),
                                        label: const Text('Load to Sales'),
                                      ),
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

  Color _statusColor(BuildContext context, QuotationStatus status) {
    final cs = Theme.of(context).colorScheme;
    switch (status) {
      case QuotationStatus.draft:
        return cs.primary;
      case QuotationStatus.sent:
        return const Color(0xFF0F766E);
      case QuotationStatus.converted:
        return const Color(0xFF7C2D12);
    }
  }

  IconData _statusIcon(QuotationStatus status) {
    switch (status) {
      case QuotationStatus.draft:
        return Icons.edit_note_outlined;
      case QuotationStatus.sent:
        return Icons.send_outlined;
      case QuotationStatus.converted:
        return Icons.check_circle_outline;
    }
  }
}

class _QuoteMetric extends StatelessWidget {
  const _QuoteMetric({
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

class _QuoteStatusBadge extends StatelessWidget {
  const _QuoteStatusBadge({required this.label, required this.color});

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

class _QuotePill extends StatelessWidget {
  const _QuotePill({required this.label});

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
