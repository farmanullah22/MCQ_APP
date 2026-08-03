import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';

import '../core/theme/app_colors.dart';
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

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  final Map<String, Widget> _cache = {};

  List<String> _routes(bool isAdmin) => isAdmin
      ? const ['dashboard', 'inventory', 'sales', 'reports', 'profile']
      : const ['dashboard', 'inventory', 'profile'];

  Widget _screenFor(String route) => _cache.putIfAbsent(route, () {
        switch (route) {
          case 'dashboard':
            return const DashboardScreen();
          case 'inventory':
            return const InventoryScreen();
          case 'sales':
            return const SalesListScreen();
          case 'reports':
            return const ReportsScreen();
          case 'profile':
            return const ProfileScreen();
        }
        return const SizedBox.shrink();
      });

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.isAdmin ?? false;
    final routes = _routes(isAdmin);
    final index = _index < routes.length ? _index : routes.length - 1;

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [for (final route in routes) _screenFor(route)],
      ),
      drawer: _buildDrawer(context, isAdmin),
      bottomNavigationBar: _PremiumBottomNav(
        currentIndex: index,
        routes: routes,
        onTap: (i) => setState(() => _index = i),
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
            decoration: const BoxDecoration(
              gradient: AppColors.emeraldGradient,
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
          _DrawerItem(icon: Icons.dashboard_outlined, label: 'Dashboard', onTap: () => _go('dashboard', isAdmin)),
          _DrawerItem(icon: Icons.inventory_2_outlined, label: 'Inventory', onTap: () => _go('inventory', isAdmin)),
          if (isAdmin) ...[
            _DrawerItem(icon: Icons.point_of_sale_outlined, label: 'Sales', onTap: () => _go('sales', isAdmin)),
            _DrawerItem(icon: Icons.bar_chart_outlined, label: 'Reports', onTap: () => _go('reports', isAdmin)),
          ],
          _DrawerItem(icon: Icons.shopping_cart_outlined, label: 'Products', onTap: () => _open(const ProductListScreen())),
          _DrawerItem(icon: Icons.receipt_long_outlined, label: 'Expenses', onTap: () => _open(const ExpenseListScreen())),
          if (isAdmin) ...[
            const Divider(),
            _DrawerItem(icon: Icons.assessment_outlined, label: 'Analytics', onTap: () => _open(const AnalyticsScreen())),
            _DrawerItem(icon: Icons.category_outlined, label: 'Categories', onTap: () => _open(const CategoryScreen())),
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
            },
          ),
        ],
      ),
    );
  }

  void _go(String route, bool isAdmin) {
    Navigator.of(context).pop();
    setState(() => _index = _routes(isAdmin).indexOf(route));
  }

  void _open(Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _PremiumBottomNav extends StatelessWidget {
  const _PremiumBottomNav({required this.currentIndex, required this.routes, required this.onTap});

  final int currentIndex;
  final List<String> routes;
  final ValueChanged<int> onTap;

  static (IconData, IconData, String) _meta(String route) => switch (route) {
        'dashboard' => (Icons.dashboard_outlined, Icons.dashboard_rounded, 'Dashboard'),
        'inventory' => (Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Inventory'),
        'sales' => (Icons.point_of_sale_outlined, Icons.point_of_sale_rounded, 'Sales'),
        'reports' => (Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Reports'),
        'profile' => (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
        _ => (Icons.circle_outlined, Icons.circle, ''),
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 68,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withValues(alpha: 0.58)
              : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: isDark ? 0.42 : 0.30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.7 : 0.18),
              blurRadius: 34,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: AppColors.gold.withValues(alpha: isDark ? 0.14 : 0.0),
              blurRadius: 22,
              spreadRadius: -6,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Row(
              children: List.generate(routes.length, (i) {
                final (icon, selectedIcon, label) = _meta(routes[i]);
                return Expanded(
                  child: _NavItem(
                    icon: icon,
                    selectedIcon: selectedIcon,
                    label: label,
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idleColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: selected ? 1.06 : 1.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: selected ? 48 : 42,
              height: selected ? 34 : 30,
              decoration: BoxDecoration(
                gradient: selected ? AppColors.goldGradient : null,
                borderRadius: BorderRadius.circular(18),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.45),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  selected ? selectedIcon : icon,
                  key: ValueKey(selected),
                  size: 21,
                  color: selected ? AppColors.deepBlack : idleColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? AppColors.gold : idleColor,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
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
