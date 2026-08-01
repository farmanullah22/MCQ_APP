class ChartPoint {
  final String label;
  final double sales;
  final double profit;
  final double expenses;
  final String? date;

  const ChartPoint({
    required this.label,
    this.sales = 0,
    this.profit = 0,
    this.expenses = 0,
    this.date,
  });

  factory ChartPoint.fromJson(Map<String, dynamic> json) => ChartPoint(
        label: json['label']?.toString() ?? '',
        date: json['date']?.toString(),
        sales: (json['sales'] as num?)?.toDouble() ?? 0,
        profit: (json['profit'] as num?)?.toDouble() ?? 0,
        expenses: (json['expenses'] as num?)?.toDouble() ?? 0,
      );
}

class ShopComparison {
  final String shopId;
  final String? shopName;
  final double sales;
  final double expenses;
  final double profit;
  final int saleCount;

  const ShopComparison({
    required this.shopId,
    this.shopName,
    this.sales = 0,
    this.expenses = 0,
    this.profit = 0,
    this.saleCount = 0,
  });

  factory ShopComparison.fromJson(Map<String, dynamic> json) => ShopComparison(
        shopId: (json['shopId'] ?? json['shop'] ?? '').toString(),
        shopName: json['shopName']?.toString(),
        sales: (json['sales'] as num?)?.toDouble() ?? 0,
        expenses: (json['expenses'] as num?)?.toDouble() ?? 0,
        profit: (json['profit'] as num?)?.toDouble() ?? 0,
        saleCount: (json['saleCount'] as num?)?.toInt() ?? 0,
      );
}

class ExpenseCategoryTotal {
  final String category;
  final double total;

  const ExpenseCategoryTotal({required this.category, required this.total});

  factory ExpenseCategoryTotal.fromJson(Map<String, dynamic> json) => ExpenseCategoryTotal(
        category: json['category']?.toString() ?? 'other',
        total: (json['total'] as num?)?.toDouble() ?? 0,
      );
}

class DashboardCards {
  final int totalShops;
  final int totalProducts;
  final double totalStockValue;
  final double salesToday;
  final int salesTodayCount;
  final double expensesToday;
  final double monthlyRevenue;
  final double monthlyProfit;
  final double monthlyExpenses;
  final double yearlyRevenue;
  final double yearlyProfit;
  final double yearlyExpenses;

  const DashboardCards({
    this.totalShops = 0,
    this.totalProducts = 0,
    this.totalStockValue = 0,
    this.salesToday = 0,
    this.salesTodayCount = 0,
    this.expensesToday = 0,
    this.monthlyRevenue = 0,
    this.monthlyProfit = 0,
    this.monthlyExpenses = 0,
    this.yearlyRevenue = 0,
    this.yearlyProfit = 0,
    this.yearlyExpenses = 0,
  });

  factory DashboardCards.fromJson(Map<String, dynamic> json) => DashboardCards(
        totalShops: (json['totalShops'] as num?)?.toInt() ?? 0,
        totalProducts: (json['totalProducts'] as num?)?.toInt() ?? 0,
        totalStockValue: (json['totalStockValue'] as num?)?.toDouble() ?? 0,
        salesToday: (json['salesToday'] as num?)?.toDouble() ?? 0,
        salesTodayCount: (json['salesTodayCount'] as num?)?.toInt() ?? 0,
        expensesToday: (json['expensesToday'] as num?)?.toDouble() ?? 0,
        monthlyRevenue: (json['monthlyRevenue'] as num?)?.toDouble() ?? 0,
        monthlyProfit: (json['monthlyProfit'] as num?)?.toDouble() ?? 0,
        monthlyExpenses: (json['monthlyExpenses'] as num?)?.toDouble() ?? 0,
        yearlyRevenue: (json['yearlyRevenue'] as num?)?.toDouble() ?? 0,
        yearlyProfit: (json['yearlyProfit'] as num?)?.toDouble() ?? 0,
        yearlyExpenses: (json['yearlyExpenses'] as num?)?.toDouble() ?? 0,
      );
}

class DashboardData {
  final DashboardCards cards;
  final List<ChartPoint> daily;
  final List<ChartPoint> weekly;
  final List<ChartPoint> monthly;
  final List<ChartPoint> yearly;
  final List<ShopComparison> comparison;
  final List<ExpenseCategoryTotal> expenseBreakdown;
  final List<ShopSummary> shops;

  const DashboardData({
    this.cards = const DashboardCards(),
    this.daily = const [],
    this.weekly = const [],
    this.monthly = const [],
    this.yearly = const [],
    this.comparison = const [],
    this.expenseBreakdown = const [],
    this.shops = const [],
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final charts = json['charts'] as Map<String, dynamic>? ?? const {};
    return DashboardData(
      cards: DashboardCards.fromJson(json['cards'] as Map<String, dynamic>? ?? const {}),
      daily: (charts['daily'] as List?)?.map((e) => ChartPoint.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      weekly: (charts['weekly'] as List?)?.map((e) => ChartPoint.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      monthly: (charts['monthly'] as List?)?.map((e) => ChartPoint.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      yearly: (charts['yearly'] as List?)?.map((e) => ChartPoint.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      comparison: (charts['comparison'] as List?)?.map((e) => ShopComparison.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      expenseBreakdown: (charts['expenseBreakdown'] as List?)?.map((e) => ExpenseCategoryTotal.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      shops: (json['shops'] as List?)?.map((e) => ShopSummary.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
    );
  }
}

class ShopSummary {
  final String id;
  final String name;
  final String manager;

  const ShopSummary({required this.id, required this.name, this.manager = ''});

  factory ShopSummary.fromJson(Map<String, dynamic> json) => ShopSummary(
        id: (json['id'] ?? json['_id']).toString(),
        name: json['name']?.toString() ?? '',
        manager: json['manager']?.toString() ?? '',
      );
}
