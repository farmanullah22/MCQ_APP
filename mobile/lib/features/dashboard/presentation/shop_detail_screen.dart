import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/activity_timeline.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/dashboard_hero_slider.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/status_views.dart';
import '../models/dashboard_data.dart';
import '../providers/dashboard_providers.dart';

class ShopDetailScreen extends ConsumerWidget {
  const ShopDetailScreen({
    super.key,
    required this.shopId,
    this.shopName,
    this.manager,
    this.revenue,
    this.profit,
    this.saleCount,
  });

  final String shopId;
  final String? shopName;
  final String? manager;
  final double? revenue;
  final double? profit;
  final int? saleCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(shopDetailProvider(shopId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? AppGradients.bgDark.colors.first : AppGradients.bg.colors.first,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(shopName ?? 'Shop Details'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.refresh(shopDetailProvider(shopId)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isDark ? AppGradients.bgDark : AppGradients.bg,
        ),
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, st) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.refresh(shopDetailProvider(shopId)),
          ),
          data: (data) {
            final name = shopName ?? 'Shop';
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(shopDetailProvider(shopId));
                await ref.read(shopDetailProvider(shopId).future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  _ShopHeader(
                    name: name,
                    manager: manager,
                    revenue: revenue ?? data.cards.monthlyRevenue,
                    profit: profit ?? data.cards.monthlyProfit,
                    saleCount: saleCount ?? data.cards.salesTodayCount,
                  ),
                  const SizedBox(height: 16),
                  SectionHeader(
                    title: 'Overview',
                    subtitle: 'Key metrics for $name',
                  ),
                  _ShopStatsGrid(cards: data.cards),
                  if (data.daily.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ChartCard(
                      title: 'Daily Sales',
                      subtitle: 'Last 14 days',
                      height: 200,
                      child: LineSalesChart(points: data.daily),
                    ),
                  ],
                  if (data.monthly.isNotEmpty) ...[
                    ChartCard(
                      title: 'Monthly Revenue & Profit',
                      subtitle: 'Last 12 months',
                      height: 200,
                      child: LineSalesChart(points: data.monthly, showExpenses: false),
                    ),
                  ],
                  if (data.expenseBreakdown.isNotEmpty) ...[
                    ChartCard(
                      title: 'Expense Breakdown',
                      subtitle: 'Last 30 days',
                      height: 220,
                      child: PieChartWidget(
                        sections: data.expenseBreakdown
                            .map((e) => (label: e.category, value: e.total))
                            .toList(),
                      ),
                    ),
                  ],
                  if (data.topProducts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SectionHeader(title: 'Top Products', subtitle: 'Best sellers in this shop'),
                    _TopProductsCard(products: data.topProducts),
                  ],
                  if (data.recentActivity.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SectionHeader(title: 'Recent Activity', subtitle: 'Latest changes in this shop'),
                    _ActivityCard(items: data.recentActivity),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({
    required this.name,
    this.manager,
    required this.revenue,
    required this.profit,
    required this.saleCount,
  });

  final String name;
  final String? manager;
  final double revenue;
  final double profit;
  final int saleCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.emeraldGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (manager != null)
                      Text(
                        'Manager: $manager',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeaderMetric(
                  label: 'Total Revenue',
                  value: Formatters.compact(revenue),
                ),
              ),
              Expanded(
                child: _HeaderMetric(
                  label: 'Total Profit',
                  value: Formatters.compact(profit),
                ),
              ),
              Expanded(
                child: _HeaderMetric(
                  label: 'Total Sales',
                  value: '$saleCount',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ShopStatsGrid extends StatelessWidget {
  const _ShopStatsGrid({required this.cards});

  final DashboardCards cards;

  @override
  Widget build(BuildContext context) {
    final stats = <Widget>[
      StatCard(
        title: 'Sales Today',
        value: cards.salesToday,
        icon: Icons.point_of_sale_rounded,
        color: AppColors.primary,
        subtitle: '${cards.salesTodayCount} transactions',
      ),
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

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({required this.products});

  final List<TopProduct> products;

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
      child: Column(
        children: products.indexed.map((e) {
          final product = e.$2;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${e.$1 + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${product.quantity} sold',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  Formatters.compact(product.revenue),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ],
            ),
          );
        }).toList(),
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
