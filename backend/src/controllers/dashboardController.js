const Shop = require('../models/Shop');
const Product = require('../models/Product');
const asyncHandler = require('../utils/asyncHandler');
const ApiResponse = require('../utils/ApiResponse');
const stats = require('../utils/stats');

const getDashboard = asyncHandler(async (req, res) => {
  const isAdmin = req.user.role === 'admin';
  const shopId = isAdmin ? (req.shopId || null) : req.user.assignedShop._id;

  const shopFilter = { isDeleted: false };
  if (shopId) shopFilter._id = shopId;
  const productFilter = { isDeleted: false };
  if (shopId) productFilter.shop = shopId;

  const [shops, productCount, stockValue] = await Promise.all([
    Shop.find(shopFilter).populate('manager', 'name'),
    Product.countDocuments(productFilter),
    Product.aggregate([
      { $match: productFilter },
      { $group: { _id: null, value: { $sum: { $multiply: ['$quantity', '$costPrice'] } } } },
    ]),
  ]);

  const [todaySales, todayExpenses, monthSales, monthExpenses, yearSales, yearExpenses] = await Promise.all([
    stats.getSalesTotal(stats.dateRange('today'), shopId),
    stats.getExpenseTotal(stats.dateRange('today'), shopId),
    stats.getSalesTotal(stats.dateRange('month'), shopId),
    stats.getExpenseTotal(stats.dateRange('month'), shopId),
    stats.getSalesTotal(stats.dateRange('year'), shopId),
    stats.getExpenseTotal(stats.dateRange('year'), shopId),
  ]);

  const [daily, weekly, monthly, yearly] = await Promise.all([
    stats.dailySeries(shopId, 14),
    stats.weeklySeries(shopId, 12),
    stats.monthlySeries(shopId, 12),
    stats.yearlySeries(shopId, 5),
  ]);

  const comparison = isAdmin
    ? await stats.shopComparison(shops.map((s) => s._id))
    : await stats.shopComparison([shopId]);

  const expenseBreakdown = await stats.expenseBreakdown(shopId, 30);

  res.json(
    ApiResponse.ok('Dashboard data fetched', {
      cards: {
        totalShops: shops.length,
        totalProducts: productCount,
        totalStockValue: stockValue[0]?.value || 0,
        salesToday: todaySales.total,
        salesTodayCount: todaySales.count,
        expensesToday: todayExpenses.total,
        monthlyRevenue: monthSales.total,
        monthlyProfit: monthSales.profit - monthExpenses.total,
        monthlyExpenses: monthExpenses.total,
        yearlyRevenue: yearSales.total,
        yearlyProfit: yearSales.profit - yearExpenses.total,
        yearlyExpenses: yearExpenses.total,
      },
      charts: { daily, weekly, monthly, yearly, comparison, expenseBreakdown },
      shops: shops.map((s) => ({ id: s._id, name: s.name, manager: s.manager?.name || '—' })),
    })
  );
});

module.exports = { getDashboard };
