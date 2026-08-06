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
  final String? manager;
  final double sales;
  final double expenses;
  final double profit;
  final int saleCount;

  const ShopComparison({
    required this.shopId,
    this.shopName,
    this.manager,
    this.sales = 0,
    this.expenses = 0,
    this.profit = 0,
    this.saleCount = 0,
  });

  factory ShopComparison.fromJson(Map<String, dynamic> json) => ShopComparison(
        shopId: (json['shopId'] ?? json['shop'] ?? '').toString(),
        shopName: json['shopName']?.toString(),
        manager: json['manager']?.toString(),
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

class TopProduct {
  final String name;
  final int quantity;
  final double revenue;

  const TopProduct({required this.name, this.quantity = 0, this.revenue = 0});

  factory TopProduct.fromJson(Map<String, dynamic> json) => TopProduct(
        name: json['name']?.toString() ?? 'Product',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      );
}

class ActivityItem {
  final String type;
  final String title;
  final String subtitle;
  final String? time;

  const ActivityItem({required this.type, this.title = '', this.subtitle = '', this.time});

  factory ActivityItem.fromJson(Map<String, dynamic> json) => ActivityItem(
        type: json['type']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        subtitle: json['subtitle']?.toString() ?? '',
        time: json['time']?.toString(),
      );
}

class LowStockProduct {
  final String id;
  final String name;
  final String sku;
  final double quantity;
  final double lowStockThreshold;
  final double sellingPrice;

  const LowStockProduct({
    required this.id,
    required this.name,
    this.sku = '',
    this.quantity = 0,
    this.lowStockThreshold = 0,
    this.sellingPrice = 0,
  });

  factory LowStockProduct.fromJson(Map<String, dynamic> json) => LowStockProduct(
        id: (json['id'] ?? json['_id']).toString(),
        name: json['name']?.toString() ?? 'Product',
        sku: json['sku']?.toString() ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        lowStockThreshold: (json['lowStockThreshold'] as num?)?.toDouble() ?? 0,
        sellingPrice: (json['sellingPrice'] as num?)?.toDouble() ?? 0,
      );
}

class TopCustomer {
  final String name;
  final String phone;
  final double total;
  final int orders;

  const TopCustomer({
    required this.name,
    this.phone = '',
    this.total = 0,
    this.orders = 0,
  });

  factory TopCustomer.fromJson(Map<String, dynamic> json) => TopCustomer(
        name: json['name']?.toString() ?? 'Customer',
        phone: json['phone']?.toString() ?? '',
        total: (json['total'] as num?)?.toDouble() ?? 0,
        orders: (json['orders'] as num?)?.toInt() ?? 0,
      );
}

class ManagerBranch {
  final String id;
  final String name;
  final String address;

  const ManagerBranch({required this.id, required this.name, this.address = ''});

  factory ManagerBranch.fromJson(Map<String, dynamic> json) => ManagerBranch(
        id: (json['id'] ?? json['_id']).toString(),
        name: json['name']?.toString() ?? '',
        address: json['address']?.toString() ?? '',
      );
}

class DashboardCards {
  final int totalShops;
  final int totalProducts;
  final int lowStockCount;
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

  // Manager (operational) KPI cards — no financial values.
  final int todayOrders;
  final int customerCount;
  final int stockInToday;
  final int stockOutToday;

  const DashboardCards({
    this.totalShops = 0,
    this.totalProducts = 0,
    this.lowStockCount = 0,
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
    this.todayOrders = 0,
    this.customerCount = 0,
    this.stockInToday = 0,
    this.stockOutToday = 0,
  });

  factory DashboardCards.fromJson(Map<String, dynamic> json) => DashboardCards(
        totalShops: (json['totalShops'] as num?)?.toInt() ?? 0,
        totalProducts: (json['totalProducts'] as num?)?.toInt() ?? 0,
        lowStockCount: (json['lowStockCount'] as num?)?.toInt() ?? 0,
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
        todayOrders: (json['todayOrders'] as num?)?.toInt() ?? 0,
        customerCount: (json['customerCount'] as num?)?.toInt() ?? 0,
        stockInToday: (json['stockInToday'] as num?)?.toInt() ?? 0,
        stockOutToday: (json['stockOutToday'] as num?)?.toInt() ?? 0,
      );
}

class DashboardData {
  final String? role;
  final DashboardCards cards;
  final List<ChartPoint> daily;
  final List<ChartPoint> weekly;
  final List<ChartPoint> monthly;
  final List<ChartPoint> yearly;
  final List<ShopComparison> comparison;
  final List<ExpenseCategoryTotal> expenseBreakdown;
  final List<ShopSummary> shops;
  final List<TopProduct> topProducts;
  final List<TopCustomer> topCustomers;
  final List<LowStockProduct> lowStock;
  final List<ActivityItem> recentActivity;
  final ManagerBranch? branch;

  const DashboardData({
    this.role,
    this.cards = const DashboardCards(),
    this.daily = const [],
    this.weekly = const [],
    this.monthly = const [],
    this.yearly = const [],
    this.comparison = const [],
    this.expenseBreakdown = const [],
    this.shops = const [],
    this.topProducts = const [],
    this.topCustomers = const [],
    this.lowStock = const [],
    this.recentActivity = const [],
    this.branch,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final charts = json['charts'] as Map<String, dynamic>? ?? const {};
    final branchJson = json['branch'];
    return DashboardData(
      role: json['role']?.toString(),
      cards: DashboardCards.fromJson(json['cards'] as Map<String, dynamic>? ?? const {}),
      daily: (charts['daily'] as List?)?.map((e) => ChartPoint.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      weekly: (charts['weekly'] as List?)?.map((e) => ChartPoint.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      monthly: (charts['monthly'] as List?)?.map((e) => ChartPoint.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      yearly: (charts['yearly'] as List?)?.map((e) => ChartPoint.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      comparison: (charts['comparison'] as List?)?.map((e) => ShopComparison.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      expenseBreakdown: (charts['expenseBreakdown'] as List?)?.map((e) => ExpenseCategoryTotal.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      shops: (json['shops'] as List?)?.map((e) => ShopSummary.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      topProducts: (json['topProducts'] as List?)?.map((e) => TopProduct.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      topCustomers: (json['topCustomers'] as List?)?.map((e) => TopCustomer.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      lowStock: (json['lowStock'] as List?)?.map((e) => LowStockProduct.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      recentActivity: (json['recentActivity'] as List?)?.map((e) => ActivityItem.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      branch: branchJson is Map<String, dynamic> ? ManagerBranch.fromJson(branchJson) : null,
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
