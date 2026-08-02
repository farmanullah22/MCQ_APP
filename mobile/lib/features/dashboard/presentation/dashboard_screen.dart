import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/activity_timeline.dart';
import '../../../core/widgets/app_bar_brand.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/dashboard_hero_slider.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/shop_card.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/status_views.dart';
import '../../audit/presentation/audit_logs_screen.dart';
import '../../auth/providers/auth_providers.dart';
import '../../expenses/presentation/expense_form_screen.dart';
import '../../inventory/presentation/inventory_screen.dart';
import '../../inventory/presentation/stock_screens.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../products/presentation/product_form_screen.dart';
import '../../products/presentation/product_list_screen.dart';
import '../../reports/presentation/reports_screen.dart';
import '../../sales/presentation/sales_list_screen.dart';
import '../models/dashboard_data.dart';
import '../providers/dashboard_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final state = ref.watch(dashboardControllerProvider);
    final isAdmin = user?.isAdmin ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgTop = isDark ? AppGradients.bgDark.colors.first : AppGradients.bg.colors.first;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: bgTop,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.only(left: 16, right: 4),
          child: AppBarBrand(showText: false, size: 32),
        ),
        titleSpacing: 8,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_greeting()}, ${user?.name.split(' ').first ?? ''}'),
            Text(
              isAdmin ? 'Admin Dashboard' : (user?.assignedShopName ?? 'Manager Dashboard'),
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
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isDark ? AppGradients.bgDark : AppGradients.bg,
        ),
        child: state.data.when(
          loading: () => const LoadingView(),
          error: (e, st) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.read(dashboardControllerProvider.notifier).refresh(),
          ),
          data: (data) {
            final slides = _buildSlides(context, ref, data, isAdmin);
            return RefreshIndicator(
              onRefresh: () => ref.read(dashboardControllerProvider.notifier).refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  DashboardHeroSlider(slides: slides),
                  const SizedBox(height: 20),
                  if (!isAdmin) ...[
                    _TargetsCard(
                      cards: data.cards,
                      daily: data.daily,
                      onAddExpense: () => _push(context, ref, const ExpenseFormScreen()),
                    ),
                    const SizedBox(height: 16),
                    if (data.cards.lowStockCount > 0)
                      _StockAlertBanner(
                        count: data.cards.lowStockCount,
                        onTap: () => _push(context, ref, const InventoryScreen()),
                      ),
                    const SizedBox(height: 20),
                  ],
                  SectionHeader(
                    title: 'Business Summary',
                    subtitle: isAdmin ? 'Across all shops' : (user?.assignedShopName ?? 'Your shop'),
                  ),
                  const SizedBox(height: 4),
                  _StatsGrid(cards: data.cards, isAdmin: isAdmin),
                  if (isAdmin) ...[
                    const SizedBox(height: 20),
                    SectionHeader(
                      title: 'Analytics',
                      subtitle: 'Sales & profit trends',
                      actionLabel: 'More',
                      action: () => _push(context, ref, const ReportsScreen()),
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
                    if (data.comparison.length > 1) ...[
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
                    const SizedBox(height: 20),
                    SectionHeader(
                      title: 'Shop Performance',
                      subtitle: 'Revenue & profit per shop',
                    ),
                    ...data.comparison.indexed.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: ShopCard(
                          name: e.$2.shopName ?? 'Shop ${e.$1 + 1}',
                          manager: e.$2.manager,
                          revenue: e.$2.sales,
                          profit: e.$2.profit,
                          saleCount: e.$2.saleCount,
                          gradient: _shopGradients[e.$1 % _shopGradients.length],
                          onOpen: () =>
                              ref.read(dashboardControllerProvider.notifier).selectShop(e.$2.shopId),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SectionHeader(
                      title: 'Manager Logs',
                      subtitle: 'What managers edit, add or delete',
                      actionLabel: 'View All',
                      action: () => _push(context, ref, const AuditLogsScreen()),
                    ),
                    _ActivityCard(items: data.recentActivity),
                  ],
                  if (!isAdmin) ...[
                    const SizedBox(height: 24),
                    SectionHeader(title: 'Quick Actions', subtitle: 'Add products, stock & expenses'),
                    const SizedBox(height: 4),
                    _QuickActions(ref: ref),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static const _shopGradients = [
    AppColors.emeraldGradient,
    AppColors.royalGradient,
    AppColors.goldGradient,
    AppColors.violetGradient,
    AppColors.warningGradient,
    AppColors.pinkGradient,
  ];

  List<HeroSlide> _buildSlides(BuildContext context, WidgetRef ref, DashboardData data, bool isAdmin) {
    final cards = data.cards;
    final top = data.topProducts.isNotEmpty ? data.topProducts.first : null;

    if (!isAdmin) {
      return [
        HeroSlide(
          title: 'Stock Value',
          value: Formatters.currency(cards.totalStockValue),
          caption: '${cards.totalProducts} products in inventory',
          buttonLabel: 'Manage Stock',
          icon: Icons.inventory_2_outlined,
          gradient: AppColors.emeraldGradient,
          onPressed: () => _push(context, ref, const InventoryScreen()),
        ),
        HeroSlide(
          title: 'Low Stock Alert',
          value: '${cards.lowStockCount}',
          caption: cards.lowStockCount > 0 ? 'items below threshold' : 'all items well stocked',
          buttonLabel: 'View Inventory',
          icon: Icons.error_outline_rounded,
          gradient: AppColors.warningGradient,
          onPressed: () => _push(context, ref, const InventoryScreen()),
        ),
        HeroSlide(
          title: 'Expenses Today',
          value: Formatters.currency(cards.expensesToday),
          caption: 'record today\'s spending',
          buttonLabel: 'Add Expense',
          icon: Icons.add_card_outlined,
          gradient: AppColors.pinkGradient,
          onPressed: () => _push(context, ref, const ExpenseFormScreen()),
        ),
        HeroSlide(
          title: 'Product Catalog',
          value: '${cards.totalProducts}',
          caption: 'products ready to manage',
          buttonLabel: 'Add Product',
          icon: Icons.add_box_outlined,
          gradient: AppColors.royalGradient,
          onPressed: () => _push(context, ref, const ProductFormScreen()),
        ),
      ];
    }

    return [
      HeroSlide(
        title: 'Today\'s Sales',
        value: Formatters.currency(cards.salesToday),
        caption: '${cards.salesTodayCount} transactions',
        buttonLabel: 'View Sales',
        icon: Icons.point_of_sale_rounded,
        gradient: AppColors.emeraldGradient,
        onPressed: () => _push(context, ref, const SalesListScreen()),
      ),
      HeroSlide(
        title: 'Monthly Revenue',
        value: Formatters.currency(cards.monthlyRevenue),
        caption: 'Profit ${Formatters.compact(cards.monthlyProfit)}',
        buttonLabel: 'View Reports',
        icon: Icons.payments_outlined,
        gradient: AppColors.royalGradient,
        onPressed: () => _push(context, ref, const ReportsScreen()),
      ),
      HeroSlide(
        title: 'Low Stock Alert',
        value: '${cards.lowStockCount}',
        caption: cards.lowStockCount > 0 ? 'items below threshold' : 'all items well stocked',
        buttonLabel: 'View Stock',
        icon: Icons.inventory_2_outlined,
        gradient: AppColors.warningGradient,
        onPressed: () => _push(context, ref, const InventoryScreen()),
      ),
      if (top != null)
        HeroSlide(
          title: 'Top Selling Product',
          value: top.name,
          caption: '${Formatters.compact(top.revenue)} revenue',
          buttonLabel: 'View Products',
          icon: Icons.trending_up_rounded,
          gradient: AppColors.goldGradient,
          onPressed: () => _push(context, ref, const ProductListScreen()),
        ),
    ];
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _push(BuildContext context, WidgetRef ref, Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) => ref.read(dashboardControllerProvider.notifier).refresh());
  }
}

class _TargetsCard extends StatelessWidget {
  const _TargetsCard({required this.cards, required this.daily, required this.onAddExpense});

  final DashboardCards cards;
  final List<ChartPoint> daily;
  final VoidCallback onAddExpense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final len = daily.length;
    final avgExpense = len == 0 ? 0.0 : daily.fold<double>(0, (a, c) => a + c.expenses) / len;
    final expenseBudget = avgExpense > 0 ? avgExpense * 1.25 : 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.secondary.withValues(alpha: isDark ? 0.22 : 0.12),
            theme.colorScheme.surface,
          ],
        ),
        border: Border.all(color: AppColors.secondary.withValues(alpha: isDark ? 0.30 : 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text('Expense Budget', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
              const Spacer(),
              TextButton.icon(
                onPressed: onAddExpense,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Expense'),
                style: TextButton.styleFrom(foregroundColor: AppColors.secondary, padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _TargetRow(
            label: 'Today\'s Spending vs Daily Budget',
            value: Formatters.currency(cards.expensesToday),
            target: expenseBudget,
            progress: expenseBudget == 0 ? 0 : (cards.expensesToday / expenseBudget).clamp(0.0, 1.0),
            color: AppColors.danger,
          ),
        ],
      ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({
    required this.label,
    required this.value,
    required this.target,
    required this.progress,
    required this.color,
  });

  final String label;
  final String value;
  final double target;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textTheme.bodySmall?.color),
              ),
            ),
            Text(
              '$value  /  ${Formatters.compact(target)}',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: isDark ? 0.18 : 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _StockAlertBanner extends StatelessWidget {
  const _StockAlertBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: AppColors.warningGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.warning.withValues(alpha: 0.30),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count product${count == 1 ? '' : 's'} running low on stock',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Reorder before they run out',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.items});

  final List<ActivityItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.brightness == Brightness.dark ? const Color(0xFF1B2926) : const Color(0xFFE2EDEA),
        ),
      ),
      child: ActivityTimeline(items: items),
    );
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
    final theme = Theme.of(context);
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF121C1A)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? const Color(0xFF1B2926)
              : const Color(0xFFE2EDEA),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selected,
          hint: const Text('All Shops', style: TextStyle(fontSize: 13)),
          style: TextStyle(
            fontSize: 13,
            color: theme.brightness == Brightness.dark
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
  const _QuickActions({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = <({IconData icon, String label, LinearGradient gradient, Widget screen})>[
      (
        icon: Icons.add_box_outlined,
        label: 'Add Product',
        gradient: AppColors.royalGradient,
        screen: const ProductFormScreen(),
      ),
      (
        icon: Icons.arrow_downward_rounded,
        label: 'Stock In',
        gradient: AppColors.infoGradient,
        screen: const StockInScreen(),
      ),
      (
        icon: Icons.arrow_upward_rounded,
        label: 'Stock Out',
        gradient: AppColors.warningGradient,
        screen: const StockOutScreen(),
      ),
      (
        icon: Icons.add_card_outlined,
        label: 'Add Expense',
        gradient: AppColors.pinkGradient,
        screen: const ExpenseFormScreen(),
      ),
      (
        icon: Icons.inventory_2_outlined,
        label: 'Inventory',
        gradient: AppColors.emeraldGradient,
        screen: const InventoryScreen(),
      ),
      (
        icon: Icons.category_outlined,
        label: 'Products',
        gradient: AppColors.violetGradient,
        screen: const ProductListScreen(),
      ),
    ];

    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final a = actions[index];
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => a.screen))
                  .then((_) => ref.read(dashboardControllerProvider.notifier).refresh()),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: a.gradient.colors,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: a.gradient.colors.first.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(a.icon, color: Colors.white, size: 19),
                      const SizedBox(width: 9),
                      Text(
                        a.label,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.cards, required this.isAdmin});

  final DashboardCards cards;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final grid = <Widget>[
      if (isAdmin)
        StatCard(
          title: 'Sales Today',
          value: cards.salesToday,
          icon: Icons.point_of_sale_rounded,
          color: AppColors.primary,
          subtitle: '${cards.salesTodayCount} transactions',
        ),
      if (isAdmin)
        StatCard(
          title: 'Monthly Revenue',
          value: cards.monthlyRevenue,
          icon: Icons.payments_outlined,
          color: AppColors.success,
          subtitle: 'Profit ${Formatters.compact(cards.monthlyProfit)}',
        ),
      StatCard(
        title: 'Monthly Expenses',
        value: cards.monthlyExpenses,
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.danger,
      ),
      StatCard(
        title: 'Total Products',
        value: cards.totalProducts,
        icon: Icons.inventory_2_outlined,
        color: AppColors.info,
        valueType: StatValueType.number,
        subtitle: cards.lowStockCount > 0 ? '${cards.lowStockCount} low on stock' : 'fully stocked',
      ),
      StatCard(
        title: 'Stock Value',
        value: cards.totalStockValue,
        icon: Icons.savings_outlined,
        color: AppColors.secondary,
      ),
      if (isAdmin)
        StatCard(
          title: 'Shops',
          value: cards.totalShops,
          icon: Icons.storefront_outlined,
          color: AppColors.warning,
          valueType: StatValueType.number,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: grid.map((w) => SizedBox(width: width, child: w)).toList(),
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
