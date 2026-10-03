class SaleItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalAmount;

  const SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'];
    return SaleItem(
      productId: product is Map<String, dynamic>
          ? (product['id'] ?? product['_id']).toString()
          : product?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SaleReturn {
  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalAmount;
  final String reason;
  final String kind;
  final int restockedQuantity;
  final DateTime? date;

  const SaleReturn({
    required this.id,
    required this.productId,
    this.productName = '',
    this.quantity = 0,
    this.unitPrice = 0,
    this.totalAmount = 0,
    this.reason = '',
    this.kind = 'return',
    this.restockedQuantity = 0,
    this.date,
  });

  bool get isExchange => kind == 'exchange';

  factory SaleReturn.fromJson(Map<String, dynamic> json) {
    final product = json['product'];
    return SaleReturn(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      productId: product is Map<String, dynamic>
          ? (product['id'] ?? product['_id']).toString()
          : product?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      reason: json['reason']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'return',
      restockedQuantity: (json['restockedQuantity'] as num?)?.toInt() ?? 0,
      date: DateTime.tryParse(json['date']?.toString() ?? ''),
    );
  }
}

class SaleExchange {
  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalAmount;
  final String note;
  final int pairedReturnQuantity;
  final DateTime? date;

  const SaleExchange({
    required this.id,
    required this.productId,
    this.productName = '',
    this.quantity = 0,
    this.unitPrice = 0,
    this.totalAmount = 0,
    this.note = '',
    this.pairedReturnQuantity = 0,
    this.date,
  });

  factory SaleExchange.fromJson(Map<String, dynamic> json) {
    final product = json['product'];
    return SaleExchange(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      productId: product is Map<String, dynamic>
          ? (product['id'] ?? product['_id']).toString()
          : product?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      note: json['note']?.toString() ?? '',
      pairedReturnQuantity: (json['pairedReturnQuantity'] as num?)?.toInt() ?? 0,
      date: DateTime.tryParse(json['date']?.toString() ?? ''),
    );
  }
}

class SalePayment {
  final String type;
  final double amount;
  final String method;
  final String note;
  final DateTime? date;

  const SalePayment({
    required this.type,
    required this.amount,
    this.method = 'cash',
    this.note = '',
    this.date,
  });

  bool get isRefund => type == 'refund';

  factory SalePayment.fromJson(Map<String, dynamic> json) => SalePayment(
        type: json['type']?.toString() ?? 'payment',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        method: json['method']?.toString() ?? 'cash',
        note: json['note']?.toString() ?? '',
        date: DateTime.tryParse(json['date']?.toString() ?? ''),
      );
}

class WhatsAppReceipt {
  final bool attempted;
  final bool sent;
  final String reason;
  final String? error;

  const WhatsAppReceipt({
    required this.attempted,
    required this.sent,
    this.reason = '',
    this.error,
  });

  factory WhatsAppReceipt.fromJson(Map<String, dynamic> json) => WhatsAppReceipt(
        attempted: json['attempted'] == true,
        sent: json['sent'] == true,
        reason: json['reason']?.toString() ?? '',
        error: json['error']?.toString(),
      );
}

class Sale {
  final String id;
  final String invoiceNo;
  final String shopId;
  final String shopName;
  final String customerName;
  final String customerPhone;
  final List<SaleItem> items;
  final double subtotal;
  final double discount;
  final double totalAmount;
  final double paidAmount;
  final double dueAmount;
  final double profit;
  final String paymentMethod;
  final String notes;
  final String createdById;
  final String createdByName;
  final DateTime? createdAt;
  final WhatsAppReceipt? whatsappReceipt;

  // Invoice adjustments
  final List<SaleReturn> returns;
  final List<SaleExchange> exchanges;
  final List<SalePayment> payments;
  final double returnTotal;
  final double exchangeTotal;
  final double netTotal;
  final double refundTotal;
  final bool hasAdjustments;

  const Sale({
    required this.id,
    required this.invoiceNo,
    required this.shopId,
    this.shopName = '',
    this.customerName = 'Walk-in Customer',
    this.customerPhone = '',
    this.items = const [],
    this.subtotal = 0,
    this.discount = 0,
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.dueAmount = 0,
    this.profit = 0,
    this.paymentMethod = 'cash',
    this.notes = '',
    this.createdById = '',
    this.createdByName = '',
    this.createdAt,
    this.whatsappReceipt,
    this.returns = const [],
    this.exchanges = const [],
    this.payments = const [],
    this.returnTotal = 0,
    this.exchangeTotal = 0,
    this.netTotal = 0,
    this.refundTotal = 0,
    this.hasAdjustments = false,
  });

  int get totalItems => items.fold(0, (a, i) => a + i.quantity);

  int get returnedItems => returns.fold(0, (a, r) => a + r.quantity);

  int get exchangedItems => exchanges.fold(0, (a, e) => a + e.quantity);

  /// What the invoice is worth right now, falling back to the original total
  /// for invoices created before returns/exchanges existed.
  double get effectiveTotal => hasAdjustments ? netTotal : totalAmount;

  bool get customerIsOwed => hasAdjustments && dueAmount < 0;

  /// Money that may still be handed back: returned value less replacements
  /// already given, minus whatever has already been refunded.
  double get refundableAmount {
    final entitled = returnTotal - exchangeTotal;
    final remaining = entitled - refundTotal;
    return remaining > 0 ? remaining : 0;
  }

  /// How much can still be collected from the customer on this invoice.
  double get collectableAmount => dueAmount > 0 ? dueAmount : 0;

  /// Units of `productId` still on the invoice and therefore still returnable.
  int returnableQuantity(String productId) {
    var qty = 0;
    for (final i in items) {
      if (i.productId == productId) qty += i.quantity;
    }
    for (final r in returns) {
      if (r.productId == productId) qty -= r.quantity;
    }
    return qty > 0 ? qty : 0;
  }

  /// The price the product was originally billed at, used as the default
  /// refund value.
  double billedUnitPrice(String productId) {
    for (final i in items) {
      if (i.productId == productId) return i.unitPrice;
    }
    return 0;
  }

  factory Sale.fromJson(Map<String, dynamic> json) {
    final shop = json['shop'];
    String sId = (json['shopId'] ?? json['shop'])?.toString() ?? '';
    String sName = '';
    if (shop is Map<String, dynamic>) {
      sId = (shop['id'] ?? shop['_id']).toString();
      sName = shop['name']?.toString() ?? '';
    }
    final createdBy = json['createdBy'];
    String cbId = '';
    String cbName = '';
    if (createdBy is Map<String, dynamic>) {
      cbId = (createdBy['id'] ?? createdBy['_id']).toString();
      cbName = createdBy['name']?.toString() ?? '';
    } else if (createdBy != null) {
      cbId = createdBy.toString();
    }

    return Sale(
      id: (json['id'] ?? json['_id']).toString(),
      invoiceNo: json['invoiceNo']?.toString() ?? '',
      shopId: sId,
      shopName: sName,
      customerName: json['customerName']?.toString() ?? 'Walk-in Customer',
      customerPhone: json['customerPhone']?.toString() ?? '',
      items: (json['items'] as List?)
              ?.map((e) => SaleItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
      dueAmount: (json['dueAmount'] as num?)?.toDouble() ?? 0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['paymentMethod']?.toString() ?? 'cash',
      notes: json['notes']?.toString() ?? '',
      createdById: cbId,
      createdByName: cbName,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      whatsappReceipt: json['whatsappReceipt'] is Map<String, dynamic>
          ? WhatsAppReceipt.fromJson(json['whatsappReceipt'] as Map<String, dynamic>)
          : null,
      returns: (json['returns'] as List?)
              ?.map((e) => SaleReturn.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      exchanges: (json['exchanges'] as List?)
              ?.map((e) => SaleExchange.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      payments: (json['payments'] as List?)
              ?.map((e) => SalePayment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      returnTotal: (json['returnTotal'] as num?)?.toDouble() ?? 0,
      exchangeTotal: (json['exchangeTotal'] as num?)?.toDouble() ?? 0,
      netTotal: (json['netTotal'] as num?)?.toDouble() ?? 0,
      refundTotal: (json['refundTotal'] as num?)?.toDouble() ?? 0,
      hasAdjustments: json['hasAdjustments'] == true,
    );
  }
}
