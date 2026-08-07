import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/activity_timeline.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/lux_widgets.dart';
import '../models/dashboard_data.dart';
import '../providers/dashboard_providers.dart';

const _gold = Color(0xFFD4AF37);
const _goldLight = Color(0xFFF7D488);
const _goldDark = Color(0xFFB8860B);
const _bg = Color(0xFF0B0B0F);

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
    final async = ref.watch(shopDetailProvider(shopId));

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ShowroomBackground(),
          SafeArea(
            child: async.when(
              loading: () => const LuxLoadingView(message: 'Loading branch...'),
              error: (e, st) => LuxErrorView(
                message: e.toString(),
                onRetry: () => ref.refresh(shopDetailProvider(shopId)),
              ),
              data: (data) {
                final name = shopName ?? 'Shop';
                return RefreshIndicator(
                  color: _gold,
                  backgroundColor: const Color(0xFF16141B),
                  onRefresh: () async {
                    ref.invalidate(shopDetailProvider(shopId));
                    await ref.read(shopDetailProvider(shopId).future);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
                    children: [
                      _ShopTopBar(
                        onRefresh: () => ref.refresh(shopDetailProvider(shopId)),
                      ),
                      const SizedBox(height: 16),
                      _ShopTitle(name: name, manager: manager),
                      const SizedBox(height: 18),
                      _ShopMetricsRow(
                        revenue: revenue ?? data.cards.monthlyRevenue,
                        profit: profit ?? data.cards.monthlyProfit,
                        saleCount: saleCount ?? data.cards.salesTodayCount,
                      ),
                      const SizedBox(height: 26),
                      const LuxSectionTitle(
                        title: 'Overview',
                        subtitle: 'Key metrics for this branch',
                      ),
                      const SizedBox(height: 12),
                      _ShopStatsGrid(cards: data.cards),
                      if (data.daily.isNotEmpty) ...[
                        const SizedBox(height: 26),
                        const LuxSectionTitle(
                          title: 'Daily Sales',
                          subtitle: 'Last 14 days',
                        ),
                        const SizedBox(height: 12),
                        LuxGlassCard(
                          child: SizedBox(
                            height: 200,
                            child: LineSalesChart(
                              points: data.daily,
                              lineColor: _gold,
                              expenseColor: AppColors.premiumRedLight,
                            ),
                          ),
                        ),
                      ],
                      if (data.monthly.isNotEmpty) ...[
                        const SizedBox(height: 26),
                        const LuxSectionTitle(
                          title: 'Monthly Revenue & Profit',
                          subtitle: 'Last 12 months',
                        ),
                        const SizedBox(height: 12),
                        LuxGlassCard(
                          child: SizedBox(
                            height: 200,
                            child: LineSalesChart(
                              points: data.monthly,
                              showExpenses: false,
                              lineColor: _gold,
                            ),
                          ),
                        ),
                      ],
                      if (data.expenseBreakdown.isNotEmpty) ...[
                        const SizedBox(height: 26),
                        const LuxSectionTitle(
                          title: 'Expense Breakdown',
                          subtitle: 'Last 30 days',
                        ),
                        const SizedBox(height: 12),
                        LuxGlassCard(
                          child: SizedBox(
                            height: 220,
                            child: PieChartWidget(
                              sections: data.expenseBreakdown
                                  .map((e) => (label: e.category, value: e.total))
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
                      if (data.topProducts.isNotEmpty) ...[
                        const SizedBox(height: 26),
                        const LuxSectionTitle(
                          title: 'Top Products',
                          subtitle: 'Best sellers in this branch',
                        ),
                        const SizedBox(height: 12),
                        _TopProductsCard(products: data.topProducts),
                      ],
                      if (data.recentActivity.isNotEmpty) ...[
                        const SizedBox(height: 26),
                        const LuxSectionTitle(
                          title: 'Recent Activity',
                          subtitle: 'Latest changes in this branch',
                        ),
                        const SizedBox(height: 12),
                        LuxGlassCard(
                          child: ActivityTimeline(items: data.recentActivity),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopTopBar extends StatelessWidget {
  const _ShopTopBar({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0x1FFFFFFF),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: _gold.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: _goldLight,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MUALLIM CARPETS',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                  color: _gold,
                ),
              ),
              Text(
                'BRANCH OVERVIEW',
                style: GoogleFonts.poppins(
                  fontSize: 8,
                  letterSpacing: 1.6,
                  color: Colors.white.withValues(alpha: 0.38),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: onRefresh,
          icon: Icon(
            Icons.refresh_rounded,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _ShopTitle extends StatelessWidget {
  const _ShopTitle({required this.name, this.manager});

  final String name;
  final String? manager;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LuxGoldGradientText(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (manager != null && manager!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Manager  ·  $manager',
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
        const SizedBox(height: 14),
        const LuxGoldDivider(),
      ],
    );
  }
}

class _ShopMetricsRow extends StatelessWidget {
  const _ShopMetricsRow({
    required this.revenue,
    required this.profit,
    required this.saleCount,
  });

  final double revenue;
  final double profit;
  final int saleCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: 'REVENUE',
            value: Formatters.compact(revenue),
            glow: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricTile(
            label: 'PROFIT',
            value: Formatters.compact(profit),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricTile(label: 'SALES', value: '$saleCount'),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    this.glow = false,
  });

  final String label;
  final String value;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return LuxGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      glow: glow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 8.5,
              letterSpacing: 0.9,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _goldLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopStatsGrid extends StatelessWidget {
  const _ShopStatsGrid({required this.cards});

  final DashboardCards cards;

  @override
  Widget build(BuildContext context) {
    final stats = <Widget>[
      _ShopStatTile(
        icon: Icons.point_of_sale_rounded,
        title: 'Sales Today',
        value: cards.salesToday,
        subtitle: '${cards.salesTodayCount} transactions',
      ),
      _ShopStatTile(
        icon: Icons.payments_outlined,
        title: 'Monthly Revenue',
        value: cards.monthlyRevenue,
        subtitle: 'Profit ${Formatters.compact(cards.monthlyProfit)}',
      ),
      _ShopStatTile(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Monthly Expenses',
        value: cards.monthlyExpenses,
      ),
      _ShopStatTile(
        icon: Icons.inventory_2_outlined,
        title: 'Total Products',
        value: cards.totalProducts,
        number: true,
        subtitle: cards.lowStockCount > 0 ? '${cards.lowStockCount} low on stock' : 'fully stocked',
      ),
      _ShopStatTile(
        icon: Icons.savings_outlined,
        title: 'Stock Value',
        value: cards.totalStockValue,
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

class _ShopStatTile extends StatelessWidget {
  const _ShopStatTile({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
    this.number = false,
  });

  final IconData icon;
  final String title;
  final num value;
  final String? subtitle;
  final bool number;

  @override
  Widget build(BuildContext context) {
    return LuxGlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_goldLight, _gold, _goldDark],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _gold.withValues(alpha: 0.32),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon, size: 19, color: const Color(0xFF17151C)),
          ),
          const SizedBox(height: 12),
          LuxGoldGradientText(
            child: LuxAnimatedNumber(
              value: value,
              currency: !number,
              style: GoogleFonts.playfairDisplay(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: _goldLight.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({required this.products});

  final List<TopProduct> products;

  @override
  Widget build(BuildContext context) {
    return LuxGlassCard(
      padding: const EdgeInsets.all(16),
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
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_goldLight, _gold, _goldDark],
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${e.$1 + 1}',
                    style: const TextStyle(
                      color: Color(0xFF17151C),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
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
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${product.quantity} sold',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  Formatters.compact(product.revenue),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _goldLight,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
