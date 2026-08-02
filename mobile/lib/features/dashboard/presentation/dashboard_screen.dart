import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/activity_timeline.dart';
import '../../../core/widgets/app_bar_brand.dart';
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
import 'shop_detail_screen.dart';

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
                    SectionHeader(
                      title: 'Business Summary',
                      subtitle: user?.assignedShopName ?? 'Your shop',
                    ),
                    const SizedBox(height: 4),
                    _StatsGrid(cards: data.cards),
                  ],
                  if (isAdmin) ...[
                    const SizedBox(height: 20),
                    SectionHeader(
                      title: 'Shops',
                      subtitle: 'Select a shop to view its full details',
                    ),
                    if (data.comparison.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('No shops available yet', style: TextStyle(fontSize: 13)),
                        ),
                      )
                    else
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
                            onTap: () =>
                                _openShop(context, e.$2.shopId, e.$2.shopName, e.$2.manager, e.$2.sales, e.$2.profit, e.$2.saleCount),
                            onOpen: () =>
                                _openShop(context, e.$2.shopId, e.$2.shopName, e.$2.manager, e.$2.sales, e.$2.profit, e.$2.saleCount),
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

  void _openShop(BuildContext context, String shopId, String? shopName, String? manager,
      double revenue, double profit, int saleCount) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShopDetailScreen(
          shopId: shopId,
          shopName: shopName,
          manager: manager,
          revenue: revenue,
          profit: profit,
          saleCount: saleCount,
        ),
      ),
    );
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
  const _StatsGrid({required this.cards});

  final DashboardCards cards;

  @override
  Widget build(BuildContext context) {
    final stats = <Widget>[
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
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: stats.map((w) => SizedBox(width: width, child: w)).toList(),
        );
      },
    );
  }
}
