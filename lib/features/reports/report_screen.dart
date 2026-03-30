import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/stat_card.dart';
import '../../data/repos/providers.dart';
import '../../data/repos/sale_repo.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late DateTimeRange _range;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 13)),
      end: now,
    );
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() => _range = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saleRepo = ref.watch(saleRepoProvider);
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Reports & Analytics',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            OutlinedButton.icon(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range_outlined),
              label: Text(
                '${Fmt.date(_range.start)} - ${Fmt.date(_range.end)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<ProfitSummary>(
          future: saleRepo.getProfitSummaryByDateRange(_range.start, _range.end),
          builder: (context, snap) {
            if (!snap.hasData) return const LinearProgressIndicator();
            final summary = snap.data!;
            return GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.8,
              children: [
                StatCard(
                  label: 'Revenue',
                  value: Fmt.currency(summary.revenue),
                  icon: Icons.receipt_long_outlined,
                  color: cs.primary,
                ),
                StatCard(
                  label: 'Cost',
                  value: Fmt.currency(summary.cost),
                  icon: Icons.inventory_2_outlined,
                  color: const Color(0xFF7C2D12),
                ),
                StatCard(
                  label: 'Profit',
                  value: Fmt.currency(summary.profit),
                  icon: Icons.trending_up_outlined,
                  color: const Color(0xFF0F766E),
                ),
                StatCard(
                  label: 'Margin %',
                  value: '${Fmt.qty(summary.marginPercent)}%',
                  icon: Icons.percent_outlined,
                  color: const Color(0xFF6366F1),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Top Profit Products'),
                      FutureBuilder<List<ProductProfitSummary>>(
                        future: saleRepo.getTopProfitProducts(
                          limit: 10,
                          start: _range.start,
                          end: _range.end,
                        ),
                        builder: (context, snap) {
                          if (!snap.hasData) return const LinearProgressIndicator();
                          final data = snap.data!;
                          if (data.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(32),
                              child: Text('No profit data in this range'),
                            );
                          }
                          return Column(
                            children: data.map((item) {
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(item.productName),
                                subtitle: Text(
                                  'Revenue ${Fmt.currency(item.revenue)} | Cost ${Fmt.currency(item.cost)} | Margin ${Fmt.qty(item.marginPercent)}%',
                                ),
                                trailing: Text(
                                  Fmt.currency(item.profit),
                                  style: TextStyle(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Profit SQL Shape'),
                      Text(
                        'Revenue = SUM(quantity * selling_price_at_sale)',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cost = SUM(quantity * cost_price_at_sale)',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Profit = SUM(profit)',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      const SectionHeader(title: 'Range Notes'),
                      Text(
                        'This report uses stored historical prices from sale items, so later product price changes do not distort old margins.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
