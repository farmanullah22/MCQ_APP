import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/analytics/presentation/analytics_screen.dart';
import '../features/audit/presentation/audit_logs_screen.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/categories/presentation/category_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/expenses/presentation/expense_list_screen.dart';
import '../features/inventory/presentation/inventory_screen.dart';
import '../features/managers/presentation/managers_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/products/presentation/product_list_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/sales/presentation/sales_list_screen.dart';
import '../features/settings/presentation/profile_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/shops/presentation/shops_screen.dart';
import '../features/auth/presentation/login_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  final List<Widget?> _screens = List<Widget?>.filled(5, null);

  static const _tabs = [
    DashboardScreen(),
    InventoryScreen(),
    SalesListScreen(),
    ReportsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.isAdmin ?? false;

    _screens[_index] ??= _tabs[_index];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: List.generate(_tabs.length, (i) => _screens[i] ?? const SizedBox.shrink()),
      ),
      drawer: _buildDrawer(context, isAdmin),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Inventory'),
          NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: 'Sales'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context, bool isAdmin) {
    final theme = Theme.of(context);
    final user = ref.read(currentUserProvider);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.8),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    (user?.name ?? 'M').characters.first.toUpperCase(),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  user?.name ?? 'User',
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                Text(
                  user?.email ?? '',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                ),
              ],
            ),
          ),
          _DrawerItem(icon: Icons.dashboard_outlined, label: 'Dashboard', onTap: () => _go(0)),
          _DrawerItem(icon: Icons.inventory_2_outlined, label: 'Inventory', onTap: () => _go(1)),
          _DrawerItem(icon: Icons.point_of_sale_outlined, label: 'Sales', onTap: () => _go(2)),
          _DrawerItem(icon: Icons.bar_chart_outlined, label: 'Reports', onTap: () => _go(3)),
          _DrawerItem(icon: Icons.assessment_outlined, label: 'Analytics', onTap: () => _open(const AnalyticsScreen())),
          _DrawerItem(icon: Icons.category_outlined, label: 'Categories', onTap: () => _open(const CategoryScreen())),
          _DrawerItem(icon: Icons.shopping_cart_outlined, label: 'Products', onTap: () => _open(const ProductListScreen())),
          _DrawerItem(icon: Icons.receipt_long_outlined, label: 'Expenses', onTap: () => _open(const ExpenseListScreen())),
          if (isAdmin) ...[
            const Divider(),
            _DrawerItem(icon: Icons.storefront_outlined, label: 'Shops', onTap: () => _open(const ShopsScreen())),
            _DrawerItem(icon: Icons.manage_accounts_outlined, label: 'Managers', onTap: () => _open(const ManagersScreen())),
            _DrawerItem(icon: Icons.history_outlined, label: 'Audit Logs', onTap: () => _open(const AuditLogsScreen())),
          ],
          const Divider(),
          _DrawerItem(icon: Icons.notifications_outlined, label: 'Notifications', onTap: () => _open(const NotificationsScreen())),
          _DrawerItem(icon: Icons.settings_outlined, label: 'Settings', onTap: () => _open(const SettingsScreen())),
          _DrawerItem(
            icon: Icons.logout,
            label: 'Logout',
            color: theme.colorScheme.error,
            onTap: () async {
              final navigator = Navigator.of(context);
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  icon: const Icon(Icons.logout, color: Colors.redAccent, size: 32),
                  title: const Text('Sign out?'),
                  content: const Text('You will need to sign in again to access your account.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error, foregroundColor: Colors.white),
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              navigator.pop();
              await ref.read(authControllerProvider.notifier).logout();
              if (navigator.mounted) {
                navigator.pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
          ),
        ],
      ),
    );
  }

  void _go(int index) {
    Navigator.of(context).pop();
    setState(() => _index = index);
  }

  void _open(Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}
