import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/stat_card.dart';
import '../../data/repos/providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saleRepo = ref.watch(saleRepoProvider);
    final productRepo = ref.watch(productRepoProvider);
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Reports & Analytics',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        // Sales Summary
        FutureBuilder<Map<String, double>>(
          future: saleRepo.getSummary(),
          builder: (ctx, snap) {
            if (!snap.hasData) return const LinearProgressIndicator();
            final d = snap.data!;
            return GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.8,
              children: [
                StatCard(
                  label: 'Today',
                  value: Fmt.currency(d['today']!),
                  icon: Icons.today,
                  color: cs.primary,
                ),
                StatCard(
                  label: 'This Month',
                  value: Fmt.currency(d['month']!),
                  icon: Icons.calendar_month,
                  color: cs.tertiary,
                ),
                StatCard(
                  label: 'This Year',
                  value: Fmt.currency(d['year']!),
                  icon: Icons.calendar_today,
                  color: const Color(0xFF6A1B9A),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Products
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Top Products by Revenue'),
                      FutureBuilder<List<Map<String, Object?>>>(
                        future: saleRepo.getTopProducts(),
                        builder: (ctx, snap) {
                          if (!snap.hasData)
                            return const LinearProgressIndicator();
                          final data = snap.data!;
                          if (data.isEmpty)
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text('No sales yet'),
                              ),
                            );
                          return Column(
                            children:
                                data.asMap().entries.map((entry) {
                                  final rank = entry.key + 1;
                                  final item = entry.value;
                                  final revenue =
                                      (item['total_revenue'] as num).toDouble();
                                  final maxRevenue =
                                      (data.first['total_revenue'] as num)
                                          .toDouble();
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          child: Text(
                                            '#$rank',
                                            style: TextStyle(
                                              color: cs.onSurfaceVariant,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['name'] as String,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: revenue / maxRevenue,
                                                  backgroundColor: cs
                                                      .primaryContainer
                                                      .withOpacity(0.3),
                                                  color: cs.primary,
                                                  minHeight: 6,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              Fmt.currency(revenue),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              '${Fmt.qty(item['total_qty'] as num)} units',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: cs.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
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
            // Stock Levels
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Current Stock Levels'),
                      FutureBuilder<List<dynamic>>(
                        future: productRepo.getAll(),
                        builder: (ctx, snap) {
                          if (!snap.hasData)
                            return const LinearProgressIndicator();
                          final products = snap.data!;
                          if (products.isEmpty)
                            return const Padding(
                              padding: EdgeInsets.all(32),
                              child: Text('No products'),
                            );
                          final maxQty = products
                              .map((p) => p.quantity)
                              .reduce((a, b) => a > b ? a : b);
                          return Column(
                            children:
                                products
                                    .take(10)
                                    .map(
                                      (p) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 5,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                p.name,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: 3,
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value:
                                                      maxQty == 0
                                                          ? 0
                                                          : p.quantity / maxQty,
                                                  backgroundColor:
                                                      cs.surfaceContainerHighest,
                                                  color:
                                                      p.isLowStock
                                                          ? cs.error
                                                          : cs.primary,
                                                  minHeight: 8,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              Fmt.qty(p.quantity),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                          );
                        },
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
