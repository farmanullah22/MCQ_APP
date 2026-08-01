class InventoryLog {
  final String id;
  final String productId;
  final String productName;
  final String actionType; // stock_in | stock_out
  final int quantity;
  final int previousStock;
  final int newStock;
  final String supplier;
  final String reason;
  final String performedByName;
  final String shopName;
  final DateTime? date;

  const InventoryLog({
    required this.id,
    required this.productId,
    required this.productName,
    required this.actionType,
    required this.quantity,
    required this.previousStock,
    required this.newStock,
    this.supplier = '',
    this.reason = '',
    this.performedByName = '',
    this.shopName = '',
    this.date,
  });

  bool get isStockIn => actionType == 'stock_in';

  factory InventoryLog.fromJson(Map<String, dynamic> json) {
    final performedBy = json['performedBy'];
    String pName = '';
    if (performedBy is Map<String, dynamic>) {
      pName = performedBy['name']?.toString() ?? '';
    }
    final shop = json['shop'];
    String sName = '';
    if (shop is Map<String, dynamic>) {
      sName = shop['name']?.toString() ?? '';
    }
    return InventoryLog(
      id: (json['id'] ?? json['_id']).toString(),
      productId: (json['product'] is Map<String, dynamic>
              ? (json['product']['id'] ?? json['product']['_id'])
              : json['product'])
          ?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      actionType: json['actionType']?.toString() ?? 'stock_in',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      previousStock: (json['previousStock'] as num?)?.toInt() ?? 0,
      newStock: (json['newStock'] as num?)?.toInt() ?? 0,
      supplier: json['supplier']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      performedByName: pName,
      shopName: sName,
      date: DateTime.tryParse(json['date']?.toString() ?? ''),
    );
  }
}
