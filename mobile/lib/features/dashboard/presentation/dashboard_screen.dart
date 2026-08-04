import 'dart:math' as math;
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/activity_timeline.dart';
import '../../../core/widgets/carpet_pattern.dart';
import '../../audit/presentation/audit_logs_screen.dart';
import '../../auth/models/user.dart';
import '../../auth/providers/auth_providers.dart';
import '../../expenses/presentation/expense_form_screen.dart';
import '../../inventory/presentation/stock_screens.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../products/presentation/product_form_screen.dart';
import '../../sales/presentation/sale_form_screen.dart';
import '../../settings/presentation/profile_screen.dart';
import '../models/dashboard_data.dart';
import '../providers/dashboard_providers.dart';
import 'shop_detail_screen.dart';

const _gold = Color(0xFFD4AF37);
const _goldLight = Color(0xFFF7D488);
const _goldDark = Color(0xFFB8860B);
const _bg = Color(0xFF0B0B0F);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final state = ref.watch(dashboardControllerProvider);
    final isAdmin = user?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _DashboardBackground(),
          SafeArea(
            child: state.data.when(
              loading: () => const _LoadingView(),
              error: (e, st) => _ErrorView(
                message: e.toString(),
                onRetry: () =>
                    ref.read(dashboardControllerProvider.notifier).refresh(),
              ),
              data: (data) => RefreshIndicator(
                color: _gold,
                backgroundColor: const Color(0xFF16141B),
                onRefresh: () =>
                    ref.read(dashboardControllerProvider.notifier).refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 150),
                  children: [
                    _LuxHeader(user: user, isAdmin: isAdmin),
                    const SizedBox(height: 24),
                    _RevenueCard(data: data),
                    const SizedBox(height: 22),
                    _StatGrid(cards: data.cards),
                    const SizedBox(height: 28),
                    _SectionTitle(
                      title: isAdmin ? 'Branch Overview' : 'Your Branch',
                      subtitle: isAdmin
                          ? 'Revenue, profit and sales across showrooms'
                          : 'Overview of your showroom',
                    ),
                    const SizedBox(height: 12),
                    if (isAdmin)
                      if (data.comparison.isEmpty)
                        const _EmptyNote('No branches available yet')
                      else
                        ...data.comparison.indexed.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _BranchCard(
                              name: e.$2.shopName ?? 'Branch ${e.$1 + 1}',
                              manager: e.$2.manager,
                              revenue: e.$2.sales,
                              profit: e.$2.profit,
                              saleCount: e.$2.saleCount,
                              onOpen: () => _openShop(context, e.$2),
                            ),
                          ),
                        )
                    else
                      _BranchCard(
                        name: user?.assignedShopName ?? 'My Branch',
                        manager: user?.name,
                        revenue: data.cards.monthlyRevenue,
                        profit: data.cards.monthlyProfit,
                        saleCount: data.cards.salesTodayCount,
                        onOpen: () {
                          if (user?.assignedShopId == null) return;
                          _openShop(
                            context,
                            ShopComparison(
                              shopId: user!.assignedShopId!,
                              shopName: user.assignedShopName,
                              manager: user.name,
                              sales: data.cards.monthlyRevenue,
                              profit: data.cards.monthlyProfit,
                              saleCount: data.cards.salesTodayCount,
                            ),
                          );
                        },
                      ),
                    if (!isAdmin) ...[
                      const SizedBox(height: 28),
                      const _SectionTitle(
                        title: 'Quick Actions',
                        subtitle: 'Frequent tasks at your fingertips',
                      ),
                      const SizedBox(height: 12),
                      _QuickActions(),
                    ],
                    if (!isAdmin) ...[
                      const SizedBox(height: 28),
                      const _SectionTitle(
                        title: 'Analytics',
                        subtitle: 'Track performance over time',
                      ),
                      const SizedBox(height: 12),
                      _WeeklySalesCard(data: data.weekly),
                      const SizedBox(height: 14),
                      _MonthlyProfitCard(data: data.monthly),
                      const SizedBox(height: 14),
                      _TopProductsCard(items: data.topProducts),
                    ],
                    if (isAdmin) ...[
                      const SizedBox(height: 28),
                      _SectionTitle(
                        title: 'Manager Logs',
                        subtitle: 'Recent activity across branches',
                        actionLabel: 'View All',
                        action: () =>
                            _push(context, ref, const AuditLogsScreen()),
                      ),
                      const SizedBox(height: 12),
                      _ActivityCard(items: data.recentActivity),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, WidgetRef ref, Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) => ref.read(dashboardControllerProvider.notifier).refresh());
  }

  void _openShop(BuildContext context, ShopComparison shop) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShopDetailScreen(
          shopId: shop.shopId,
          shopName: shop.shopName,
          manager: shop.manager,
          revenue: shop.sales,
          profit: shop.profit,
          saleCount: shop.saleCount,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- backdrop --

class _DashboardBackground extends StatelessWidget {
  const _DashboardBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bg, Color(0xFF100E14), Color(0xFF0B0B0F)],
            ),
          ),
        ),
        Opacity(
          opacity: 0.16,
          child: Image.asset(
            'lib/images/admin_dashboard.jfif',
            fit: BoxFit.cover,
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.70),
          ),
        ),
        Positioned(
          top: -90,
          right: -90,
          child: _Glow(size: 280, color: _gold.withValues(alpha: 0.10)),
        ),
        Positioned(
          top: 430,
          left: -120,
          child: _Glow(size: 320, color: _goldDark.withValues(alpha: 0.09)),
        ),
        Positioned(
          bottom: 60,
          right: -120,
          child: _Glow(size: 300, color: const Color(0xFF3A2E10).withValues(alpha: 0.28)),
        ),
        const CarpetPattern(opacity: 0.05),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ header --

class _LuxHeader extends ConsumerWidget {
  const _LuxHeader({required this.user, required this.isAdmin});

  final User? user;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstName = (user?.name ?? '').split(' ').first;
    final scope = isAdmin ? 'Muallim HQ' : (user?.assignedShopName ?? 'Manager');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'lib/images/muallimlogo.png',
                width: 42,
                height: 42,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MUALLIM CARPETS',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.2,
                      color: _gold,
                    ),
                  ),
                  Text(
                    'PREMIUM CARPET & QALEEN',
                    style: GoogleFonts.poppins(
                      fontSize: 8,
                      letterSpacing: 1.6,
                      color: Colors.white.withValues(alpha: 0.38),
                    ),
                  ),
                ],
              ),
            ),
            const _LuxBell(),
            const SizedBox(width: 6),
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              child: _Avatar(initial: (user?.name ?? 'M').characters.first),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          _greeting().toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 12,
            letterSpacing: 2.4,
            fontWeight: FontWeight.w600,
            color: _goldLight.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 2),
        _GoldGradientText(
          child: Text(
            firstName.isEmpty ? 'Welcome' : firstName,
            style: GoogleFonts.playfairDisplay(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(
              '${user?.name ?? 'User'}  ·  $scope',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _GoldDivider(),
      ],
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.6),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_goldLight, _gold, _goldDark],
        ),
        boxShadow: [
          BoxShadow(color: Color(0x66D4AF37), blurRadius: 14, spreadRadius: -2),
        ],
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF17151C),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          initial.toUpperCase(),
          style: GoogleFonts.playfairDisplay(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: _goldLight,
          ),
        ),
      ),
    );
  }
}

class _LuxBell extends ConsumerWidget {
  const _LuxBell();

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
          icon: Icon(
            Icons.notifications_none_rounded,
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
        if (unread > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_goldLight, _gold, _goldDark],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: _gold.withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
              constraints: const BoxConstraints(minWidth: 16),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF17151C),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GoldDivider extends StatelessWidget {
  const _GoldDivider();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(double.infinity, 14),
      painter: _GoldDividerPainter(),
    );
  }
}

class _GoldDividerPainter extends CustomPainter {
  const _GoldDividerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final line = Paint()
      ..strokeWidth = 1.1
      ..shader = LinearGradient(
        colors: [
          _gold.withValues(alpha: 0),
          _gold.withValues(alpha: 0.75),
          _gold.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawLine(Offset(0, midY), Offset(size.width * 0.42, midY), line);
    canvas.drawLine(
        Offset(size.width * 0.58, midY), Offset(size.width, midY), line);

    final diamond = Paint()..color = _goldLight;
    final center = Offset(size.width / 2, midY);
    final s = 5.0;
    final path = Path()
      ..moveTo(center.dx, center.dy - s)
      ..lineTo(center.dx + s * 0.7, center.dy)
      ..lineTo(center.dx, center.dy + s)
      ..lineTo(center.dx - s * 0.7, center.dy)
      ..close();
    canvas.drawPath(path, diamond);
  }

  @override
  bool shouldRepaint(_GoldDividerPainter oldDelegate) => false;
}

// --------------------------------------------------------------- revenue --

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final growth = _growthPercent(data);
    final spark = _sparkValues(data);

    return _GlassCard(
      padding: const EdgeInsets.all(20),
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'REVENUE OVERVIEW',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w700,
                  color: _goldLight.withValues(alpha: 0.9),
                ),
              ),
              const Spacer(),
              _GrowthBadge(growth: growth),
            ],
          ),
          const SizedBox(height: 12),
          _GoldGradientText(
            child: _AnimatedNumber(
              value: data.cards.monthlyRevenue,
              style: GoogleFonts.playfairDisplay(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                height: 1.05,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Monthly revenue  ·  ${Formatters.compact(data.cards.monthlyProfit)} profit',
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _Sparkline(values: spark, height: 62),
          ),
        ],
      ),
    );
  }
}

class _GrowthBadge extends StatelessWidget {
  const _GrowthBadge({required this.growth});

  final double? growth;

  @override
  Widget build(BuildContext context) {
    if (growth == null) return const SizedBox.shrink();
    final up = growth! >= 0;
    final color = up ? _goldLight : AppColors.premiumRedLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            '${up ? '+' : ''}${growth!.toStringAsFixed(1)}%',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values, required this.height});

  final List<double> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _SparklinePainter(values: values, progress: t),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.progress});

  final List<double> values;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) return;
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);

    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - 4 -
          (values[i] - minV) / range * (size.height - 8);
      pts.add(Offset(x, y));
    }

    final drawW = size.width * progress.clamp(0.0, 1.0);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, drawW, size.height));

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: const [_goldLight, _gold, _goldDark],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final mid = Offset(
        (pts[i - 1].dx + pts[i].dx) / 2,
        (pts[i - 1].dy + pts[i].dy) / 2,
      );
      path.quadraticBezierTo(pts[i - 1].dx, pts[i - 1].dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);

    final area = Path.from(path)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _gold.withValues(alpha: 0.30),
            _gold.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(path, linePaint);

    canvas.drawCircle(
      pts.last,
      3.6,
      Paint()
        ..color = _goldLight
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.values != values;
}

// --------------------------------------------------------------- stat grid --

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.cards});

  final DashboardCards cards;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _StatTile(
        title: 'Revenue',
        value: cards.monthlyRevenue,
        icon: Icons.payments_outlined,
        subtitle: '${Formatters.compact(cards.yearlyRevenue)} this year',
      ),
      _StatTile(
        title: 'Profit',
        value: cards.monthlyProfit,
        icon: Icons.trending_up_rounded,
        subtitle: '${Formatters.compact(cards.yearlyProfit)} this year',
      ),
      _StatTile(
        title: 'Sales',
        value: cards.salesToday,
        icon: Icons.point_of_sale_rounded,
        subtitle: '${cards.salesTodayCount} transactions today',
      ),
      _StatTile(
        title: 'Expenses',
        value: cards.monthlyExpenses,
        icon: Icons.account_balance_wallet_outlined,
        subtitle: '${Formatters.compact(cards.expensesToday)} spent today',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: tiles
              .map((w) => SizedBox(width: width, child: w))
              .toList(),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
  });

  final String title;
  final num value;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_goldLight, _gold, _goldDark],
                  ),
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(icon, size: 17, color: const Color(0xFF17151C)),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 10,
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AnimatedNumber(
            value: value,
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: _goldLight.withValues(alpha: 0.85),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- branches --

class _BranchCard extends StatelessWidget {
  const _BranchCard({
    required this.name,
    required this.revenue,
    required this.profit,
    required this.saleCount,
    this.manager,
    this.onOpen,
  });

  final String name;
  final String? manager;
  final double revenue;
  final double profit;
  final int saleCount;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_goldLight, _gold, _goldDark],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 18,
                  color: Color(0xFF17151C),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (manager != null && manager!.isNotEmpty)
                      Text(
                        manager!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              ),
              const _StatusBadge(),
            ],
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withValues(alpha: 0.07),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _BranchMetric(label: 'Revenue', value: Formatters.compact(revenue)),
              _BranchMetric(label: 'Profit', value: Formatters.compact(profit)),
              _BranchMetric(label: 'Sales', value: '$saleCount'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(13),
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: onOpen,
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_goldLight, _gold, _goldDark],
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: _gold.withValues(alpha: 0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Open Branch',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: const Color(0xFF17151C),
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: Color(0xFF17151C),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF3E8E5A).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF3E8E5A).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: const Color(0xFF6FBE8C),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6FBE8C).withValues(alpha: 0.7),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Open',
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6FBE8C),
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchMetric extends StatelessWidget {
  const _BranchMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 9,
              letterSpacing: 0.9,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------- quick actions --

class _QuickActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = <({IconData icon, String label, Widget screen})>[
      (
        icon: Icons.add_box_outlined,
        label: 'Add Product',
        screen: const ProductFormScreen(),
      ),
      (
        icon: Icons.point_of_sale_rounded,
        label: 'New Sale',
        screen: const SaleFormScreen(),
      ),
      (
        icon: Icons.swap_horiz_rounded,
        label: 'Stock Transfer',
        screen: const StockOutScreen(),
      ),
      (
        icon: Icons.add_card_outlined,
        label: 'Expense Entry',
        screen: const ExpenseFormScreen(),
      ),
    ];

    return Row(
      children: actions
          .map(
            (a) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => a.screen))
                        .then((_) =>
                            ref.read(dashboardControllerProvider.notifier).refresh()),
                    child: Ink(
                      decoration: BoxDecoration(
                        color: const Color(0x55000000),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _gold.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [_goldLight, _gold, _goldDark],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _gold.withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Icon(
                                a.icon,
                                size: 19,
                                color: const Color(0xFF17151C),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              a.label,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// -------------------------------------------------------------- analytics --

class _WeeklySalesCard extends StatelessWidget {
  const _WeeklySalesCard({required this.data});

  final List<ChartPoint> data;

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'Weekly Sales',
      subtitle: 'Sales by day this week',
      child: _WeeklyBarChart(data: data),
    );
  }
}

class _MonthlyProfitCard extends StatelessWidget {
  const _MonthlyProfitCard({required this.data});

  final List<ChartPoint> data;

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'Monthly Profit',
      subtitle: 'Profit trend over the year',
      child: _ProfitLineChart(data: data),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 26,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_goldLight, _goldDark],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(height: 190, child: child),
        ],
      ),
    );
  }
}

const _chartAxisStyle = TextStyle(
  fontSize: 9.5,
  color: Color(0x99FFFFFF),
);

const _chartGridLine = FlLine(
  color: Color(0x14FFFFFF),
  strokeWidth: 1,
);

class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart({required this.data});

  final List<ChartPoint> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const _EmptyNote('No weekly data yet');
    }
    final maxY = data.fold<double>(0, (a, p) => p.sales > a ? p.sales : a);

    return BarChart(
      BarChartData(
        maxY: maxY == 0 ? 100 : maxY * 1.18,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY / 4).clamp(1, double.infinity),
          getDrawingHorizontalLine: (_) => _chartGridLine,
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: (v, meta) => SideTitleWidget(
                meta: meta,
                space: 6,
                child: Text(_axisLabel(v), style: _chartAxisStyle),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: (data.length / 6).ceilToDouble().clamp(1, double.infinity),
              getTitlesWidget: (v, meta) {
                final idx = v.round();
                if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(data[idx].label, style: _chartAxisStyle),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF232028),
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem(
              '${data[group.x.round()].label}\n${Formatters.compact(rod.toY)}',
              const TextStyle(
                color: _goldLight,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        barGroups: data.indexed
            .map(
              (e) => BarChartGroupData(
                x: e.$1,
                barRods: [
                  BarChartRodData(
                    toY: e.$2.sales,
                    width: 12,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [_goldDark, _goldLight],
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
    );
  }
}

class _ProfitLineChart extends StatelessWidget {
  const _ProfitLineChart({required this.data});

  final List<ChartPoint> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const _EmptyNote('No monthly data yet');
    }
    final spots = data.indexed
        .map((e) => FlSpot(e.$1.toDouble(), e.$2.profit))
        .toList();
    final maxY = data.fold<double>(0, (a, p) => p.profit > a ? p.profit : a);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY == 0 ? 100 : maxY * 1.18,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY / 4).clamp(1, double.infinity),
          getDrawingHorizontalLine: (_) => _chartGridLine,
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: (v, meta) => SideTitleWidget(
                meta: meta,
                space: 6,
                child: Text(_axisLabel(v), style: _chartAxisStyle),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: (data.length / 6).ceilToDouble().clamp(1, double.infinity),
              getTitlesWidget: (v, meta) {
                final idx = v.round();
                if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(data[idx].label, style: _chartAxisStyle),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF232028),
            getTooltipItems: (touched) => touched
                .map(
                  (s) => LineTooltipItem(
                    '${data[s.x.round()].label}\n${Formatters.compact(s.y)}',
                    const TextStyle(
                      color: _goldLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            gradient: const LinearGradient(
              colors: [_goldLight, _gold, _goldDark],
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _gold.withValues(alpha: 0.32),
                  _gold.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
    );
  }
}

String _axisLabel(double value) =>
    value >= 1000 ? '${(value / 1000).round()}k' : '${value.round()}';

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({required this.items});

  final List<TopProduct> items;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 26,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_goldLight, _goldDark],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Top Products',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Best sellers by revenue',
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const _EmptyNote('No top products yet')
          else
            ...items.take(5).indexed.map(
                  (e) => _ProductRow(index: e.$1, product: e.$2),
                ),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.index, required this.product});

  final int index;
  final TopProduct product;

  @override
  Widget build(BuildContext context) {
    final isPodium = index < 3;
    final rankColor = index == 0
        ? const [_goldLight, _gold, _goldDark]
        : index == 1
            ? [const Color(0xFFD8D8D8), const Color(0xFF9A9A9A)]
            : [const Color(0xFFE0B884), const Color(0xFFA87B48)];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              gradient: isPodium
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: rankColor,
                    )
                  : null,
              color: isPodium ? null : Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isPodium
                    ? const Color(0xFF17151C)
                    : Colors.white.withValues(alpha: 0.5),
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
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${product.quantity} sold',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          Text(
            Formatters.compact(product.revenue),
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: _goldLight,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- activity --

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.items});

  final List<ActivityItem> items;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: items.isEmpty
          ? const _EmptyNote('No recent activity')
          : ActivityTimeline(items: items),
    );
  }
}

// ------------------------------------------------------------------ common --

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.glow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: _gold.withValues(alpha: glow ? 0.22 : 0.10),
            blurRadius: glow ? 34 : 24,
            spreadRadius: glow ? -4 : -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0x1FFFFFFF),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _gold.withValues(alpha: glow ? 0.5 : 0.34),
                width: glow ? 1.2 : 1,
              ),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.action,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null && actionLabel != null)
          TextButton(
            onPressed: action,
            style: TextButton.styleFrom(
              foregroundColor: _goldLight,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(
              actionLabel!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _AnimatedNumber extends StatelessWidget {
  const _AnimatedNumber({required this.value, required this.style});

  final num value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        Formatters.currency(v),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

class _GoldGradientText extends StatelessWidget {
  const _GoldGradientText({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_goldLight, _gold, _goldDark],
      ).createShader(rect),
      blendMode: BlendMode.srcIn,
      child: child,
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontStyle: FontStyle.italic,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              color: _gold,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading your showroom...',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: _gold, size: 42),
            const SizedBox(height: 14),
            Text(
              'Something went wrong',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: _goldLight,
                side: const BorderSide(color: _gold),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              ),
              icon: const Icon(Icons.refresh, size: 17),
              label: Text(
                'Retry',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double? _growthPercent(DashboardData d) {
  final daily = d.daily.where((p) => p.sales > 0).toList();
  if (daily.length >= 4) {
    final half = daily.length ~/ 2;
    var prev = 0.0;
    var cur = 0.0;
    for (var i = 0; i < daily.length; i++) {
      if (i < half) {
        prev += daily[i].sales;
      } else {
        cur += daily[i].sales;
      }
    }
    if (prev <= 0) return cur > 0 ? null : 0;
    return (cur - prev) / prev * 100;
  }
  if (d.monthly.length >= 2) {
    final prev = d.monthly[d.monthly.length - 2].sales;
    final cur = d.monthly[d.monthly.length - 1].sales;
    if (prev <= 0) return cur > 0 ? null : 0;
    return (cur - prev) / prev * 100;
  }
  return null;
}

List<double> _sparkValues(DashboardData d) {
  final src = d.daily.isNotEmpty ? d.daily : d.monthly;
  final vals = src.map((p) => p.sales).toList();
  if (vals.length < 2) return [0, 0];
  return vals;
}
