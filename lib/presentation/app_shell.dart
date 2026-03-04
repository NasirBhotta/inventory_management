import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/dashboard/dashboard_screen.dart';
import '../features/products/products_screen.dart';
import '../features/stock/stock_screen.dart';
import '../features/sales/sales_screen.dart';
import '../features/reports/report_screen.dart';
import '../features/backup/backup_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;

  static const _destinations = [
    NavigationRailDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: Text('Dashboard'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.inventory_2_outlined),
      selectedIcon: Icon(Icons.inventory_2),
      label: Text('Products'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.swap_horiz_outlined),
      selectedIcon: Icon(Icons.swap_horiz),
      label: Text('Stock'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.point_of_sale_outlined),
      selectedIcon: Icon(Icons.point_of_sale),
      label: Text('Sales'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart),
      label: Text('Reports'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.backup_outlined),
      selectedIcon: Icon(Icons.backup),
      label: Text('Backup'),
    ),
  ];

  final _pages = const [
    DashboardScreen(),
    ProductsScreen(),
    StockScreen(),
    SalesScreen(),
    ReportsScreen(),
    BackupScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelType: NavigationRailLabelType.all,
            destinations: _destinations,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: _AppLogo(),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }
}

class _AppLogo extends StatelessWidget {
  const _AppLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.eco, color: Theme.of(context).colorScheme.primary, size: 32),
        const SizedBox(height: 4),
        Text(
          'FertInv',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
