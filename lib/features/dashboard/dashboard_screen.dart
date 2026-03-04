import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/section_header.dart';
import '../../data/repos/sale_repo.dart';
import '../../data/repos/providers.dart';
import 'dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _exportReport(
    BuildContext context,
    WidgetRef ref,
    DashboardStats stats,
  ) async {
    try {
      final repo = ref.read(saleRepoProvider);
      final trend = await repo.getDailySales(days: 14);

      final appDir = await getApplicationSupportDirectory();
      final exportDir = Directory(p.join(appDir.path, 'exports'))
        ..createSync(recursive: true);

      final now = DateTime.now();
      final stamp = now.toIso8601String().replaceAll(':', '-');
      final file = File(p.join(exportDir.path, 'dashboard_report_$stamp.csv'));

      final sb = StringBuffer();
      sb.writeln('Inventory Dashboard Report');
      sb.writeln('Generated At,${now.toIso8601String()}');
      sb.writeln();
      sb.writeln('Metric,Value');
      sb.writeln('Total Products,${stats.totalProducts}');
      sb.writeln('Units in Stock,${stats.totalUnits}');
      sb.writeln('Stock Value,${stats.totalValue}');
      sb.writeln('Today Sales,${stats.todaySales}');
      sb.writeln('Month Sales,${stats.monthSales}');
      sb.writeln('Low Stock Count,${stats.lowStockCount}');
      sb.writeln();
      sb.writeln('Low Stock Items');
      sb.writeln('Name,Category,Quantity,Minimum');
      for (final item in stats.lowStockItems) {
        sb.writeln(
          '"${item.name.replaceAll('"', '""')}","${item.category.replaceAll('"', '""')}",${item.quantity},${item.minimumStock}',
        );
      }
      sb.writeln();
      sb.writeln('14-Day Sales Trend');
      sb.writeln('Day,Total');
      for (final row in trend) {
        sb.writeln('${row['day']},${row['total'] ?? 0}');
      }

      await file.writeAsString(sb.toString());
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report exported to: ${file.path}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardProvider);
    final cs = Theme.of(context).colorScheme;

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, stack) => Center(child: Text('Error: $e')),
      data: (stats) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overview',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Welcome back! Here is your business at a glance.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: () => _exportReport(context, ref, stats),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Export Report'),
                )
              ],
            ),
            const SizedBox(height: 24),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 2.8,
              children: [
                StatCard(
                  label: 'Total Products',
                  value: stats.totalProducts.toString(),
                  icon: Icons.inventory_2_rounded,
                  color: cs.primary,
                ),
                StatCard(
                  label: 'Units in Stock',
                  value: Fmt.qty(stats.totalUnits),
                  icon: Icons.warehouse_rounded,
                  color: const Color(0xFF0EA5E9), // Sky blue
                ),
                StatCard(
                  label: 'Stock Value',
                  value: Fmt.currency(stats.totalValue),
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFF6366F1), // Indigo
                ),
                StatCard(
                  label: 'Today\'s Sales',
                  value: Fmt.currency(stats.todaySales),
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFF10B981), // Emerald
                ),
                StatCard(
                  label: 'Monthly Sales',
                  value: Fmt.currency(stats.monthSales),
                  icon: Icons.calendar_month_rounded,
                  color: const Color(0xFF8B5CF6), // Violet
                ),
                StatCard(
                  label: 'Low Stock Alerts',
                  value: stats.lowStockCount.toString(),
                  icon: Icons.warning_rounded,
                  color: stats.lowStockCount > 0 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _SalesChart(repo: ref.watch(saleRepoProvider)),
                ),
                const SizedBox(width: 24),
                if (stats.lowStockItems.isNotEmpty)
                  Expanded(
                    flex: 1,
                    child: _LowStockList(items: stats.lowStockItems),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesChart extends StatelessWidget {
  const _SalesChart({required this.repo});
  final SalesRepository repo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionHeader(title: 'Sales Overview'),
                Chip(
                  label: const Text('Last 14 Days'),
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 300,
              child: FutureBuilder<List<Map<String, Object?>>>(
                future: repo.getDailySales(days: 14),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snap.data!;
                  if (data.isEmpty) {
                    return const Center(child: Text('No sales yet'));
                  }
                  final spots = data.asMap().entries.map(
                    (e) => FlSpot(
                      e.key.toDouble(),
                      (e.value['total'] as num).toDouble(),
                    ),
                  ).toList();
                  return LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: cs.outlineVariant.withValues(alpha: 0.3),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 60,
                            getTitlesWidget: (v, _) => Text(
                              Fmt.qty(v),
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) {
                              final idx = v.toInt();
                              if (idx < 0 || idx >= data.length) return const SizedBox();
                              final d = data[idx]['day'] as String;
                              return Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  d.substring(5),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (spot) => cs.surfaceContainerLowest,
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              return LineTooltipItem(
                                Fmt.currency(spot.y),
                                GoogleFonts.outfit(
                                  color: cs.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: cs.primary,
                          barWidth: 4,
                          isStrokeCapRound: true,
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                cs.primary.withValues(alpha: 0.3),
                                cs.primary.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: cs.surfaceContainerLowest,
                                strokeWidth: 2,
                                strokeColor: cs.primary,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LowStockList extends StatelessWidget {
  const _LowStockList({required this.items});
  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Low Stock Alerts',
              action: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    color: cs.onErrorContainer,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...items.take(8).map(
              (p) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                   color: cs.surfaceContainerLowest,
                   border: Border.all(
                     color: cs.outlineVariant.withValues(alpha: 0.4),
                   ),
                   borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.errorContainer.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.warning_rounded, color: cs.error, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            p.category,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${p.quantity} left',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Min: ${p.minimumStock}',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (items.length > 8)
               Center(
                 child: TextButton(
                   onPressed: () {},
                   child: const Text('View All'),
                 ),
               ),
          ],
        ),
      ),
    );
  }
}
