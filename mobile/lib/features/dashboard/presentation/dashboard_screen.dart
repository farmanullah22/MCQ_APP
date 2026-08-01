import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/status_views.dart';
import '../../audit/presentation/audit_logs_screen.dart';
import '../../auth/providers/auth_providers.dart';
import '../../expenses/presentation/expense_form_screen.dart';
import '../../inventory/presentation/stock_screens.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../products/presentation/product_form_screen.dart';
import '../../products/presentation/product_list_screen.dart';
import '../../reports/presentation/reports_screen.dart';
import '../models/dashboard_data.dart';
import '../providers/dashboard_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final state = ref.watch(dashboardControllerProvider);
    final isAdmin = user?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_greeting()}, ${user?.name.split(' ').first ?? ''}'),
            Text(
              user?.isAdmin == true ? 'Admin Dashboard' : (user?.assignedShopName ?? 'Manager Dashboard'),
              style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
            ),
          ],
        ),
        actions: [
          if (isAdmin && state.shops.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _ShopFilterDropdown(
                shops: state.shops,
                selected: state.selectedShopId,
                onChanged: (id) => ref.read(dashboardControllerProvider.notifier).selectShop(id),
              ),
            ),
          const _NotificationBell(),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(dashboardControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: state.data.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: e.toString(), onRetry: () => ref.read(dashboardControllerProvider.notifier).refresh()),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.read(dashboardControllerProvider.notifier).refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _QuickActions(ref: ref, isAdmin: isAdmin),
              const SizedBox(height: 16),
              _StatsGrid(cards: data.cards),
              SectionHeader(
                title: 'Analytics',
                subtitle: 'Sales & profit trends',
                actionLabel: 'More',
                action: () => _navigate(context, const ReportsScreen()),
              ),
              ChartCard(
                title: 'Daily Sales',
                subtitle: 'Last 14 days',
                height: 220,
                child: LineSalesChart(points: data.daily),
              ),
              ChartCard(
                title: 'Weekly Sales',
                subtitle: 'Last 12 weeks',
                height: 200,
                child: BarChartWidget(data: data.weekly, color: AppColors.primary),
              ),
              ChartCard(
                title: 'Monthly Revenue & Profit',
                subtitle: 'Last 12 months',
                height: 220,
                child: LineSalesChart(points: data.monthly, showExpenses: false),
              ),
              if (isAdmin && data.comparison.length > 1) ...[
                ChartCard(
                  title: 'Shop Comparison',
                  subtitle: 'Revenue per shop',
                  height: 200,
                  child: _ShopComparisonBars(comparison: data.comparison),
                ),
              ],
              ChartCard(
                title: 'Expense Breakdown',
                subtitle: 'Last 30 days',
                height: 240,
                child: PieChartWidget(
                  sections: data.expenseBreakdown.map((e) => (label: e.category, value: e.total)).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _navigate(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _ShopFilterDropdown extends StatelessWidget {
  const _ShopFilterDropdown({
    required this.shops,
    required this.selected,
    required this.onChanged,
  });

  final List<({String id, String name})> shops;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2A2A)
            : const Color(0xFFF0EAE2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selected,
          hint: const Text('All Shops', style: TextStyle(fontSize: 13)),
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextPrimary
                : AppColors.textPrimary,
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Shops')),
            ...shops.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
          ],
          onChanged: (v) {
            if (v != selected) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
          icon: const Icon(Icons.notifications_outlined),
        ),
        if (unread > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: const BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              constraints: const BoxConstraints(minWidth: 16),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.ref, required this.isAdmin});

  final WidgetRef ref;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = <({IconData icon, String label, Widget screen})>[
      (
        icon: Icons.add_box_outlined,
        label: 'Add Product',
        screen: const ProductFormScreen(),
      ),
      (
        icon: Icons.arrow_downward,
        label: 'Add Stock',
        screen: const StockInScreen(),
      ),
      (
        icon: Icons.description_outlined,
        label: 'Reports',
        screen: const ReportsScreen(),
      ),
      (
        icon: Icons.category_outlined,
        label: 'Products',
        screen: const ProductListScreen(),
      ),
      if (isAdmin)
        (
          icon: Icons.receipt_long_outlined,
          label: 'Audit Logs',
          screen: const AuditLogsScreen(),
        ),
      (
        icon: Icons.add_card_outlined,
        label: 'Add Expense',
        screen: const ExpenseFormScreen(),
      ),
    ];

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final a = actions[index];
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => a.screen),
            ),
            child: Container(
              width: 92,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkSurface
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2E2E2E)
                      : const Color(0xFFEDE7E0),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(a.icon, color: AppColors.primary),
                  const SizedBox(height: 8),
                  Text(
                    a.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.cards});

  final DashboardCards cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width,
              child: StatCard(
                title: 'Sales Today',
                value: cards.salesToday,
                icon: Icons.today_outlined,
                iconColor: AppColors.primary,
                subtitle: '${cards.salesTodayCount} transactions',
              ),
            ),
            SizedBox(
              width: width,
              child: StatCard(
                title: 'Monthly Revenue',
                value: cards.monthlyRevenue,
                icon: Icons.payments_outlined,
                iconColor: AppColors.success,
              ),
            ),
            SizedBox(
              width: width,
              child: StatCard(
                title: 'Monthly Profit',
                value: cards.monthlyProfit,
                icon: Icons.trending_up,
                iconColor: AppColors.accent,
              ),
            ),
            SizedBox(
              width: width,
              child: StatCard(
                title: 'Expenses Today',
                value: cards.expensesToday,
                icon: Icons.account_balance_wallet_outlined,
                iconColor: AppColors.danger,
              ),
            ),
            SizedBox(
              width: width,
              child: StatCard(
                title: 'Total Products',
                value: cards.totalProducts,
                icon: Icons.inventory_2_outlined,
                iconColor: AppColors.info,
                valueType: StatValueType.number,
              ),
            ),
            SizedBox(
              width: width,
              child: StatCard(
                title: 'Stock Value',
                value: cards.totalStockValue,
                icon: Icons.savings_outlined,
                iconColor: AppColors.secondary,
              ),
            ),
            if (cards.totalShops > 0)
              SizedBox(
                width: width,
                child: StatCard(
                  title: 'Shops',
                  value: cards.totalShops,
                  icon: Icons.storefront_outlined,
                  iconColor: AppColors.warning,
                  valueType: StatValueType.number,
                  onTap: cards.totalShops > 1 ? null : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ShopComparisonBars extends StatelessWidget {
  const _ShopComparisonBars({required this.comparison});

  final List<ShopComparison> comparison;

  @override
  Widget build(BuildContext context) {
    final maxSales = comparison.fold<double>(0, (a, c) => c.sales > a ? c.sales : a);
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: comparison.indexed.map((e) {
              final height = maxSales == 0 ? 0.0 : (e.$2.sales / maxSales) * 100;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        height == 0 ? '0' : '${(e.$2.sales / 1000).round()}k',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: height,
                        decoration: BoxDecoration(
                          color: e.$1.isEven ? AppColors.primary : AppColors.accent,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: comparison.indexed
              .map((e) => Expanded(
                    child: Text(
                      e.$2.shopName ?? 'Shop ${e.$1 + 1}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
