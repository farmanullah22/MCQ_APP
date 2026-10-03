import '../../../core/api/api_client.dart';
import '../models/sale.dart';

class SalePage {
  final List<Sale> sales;
  final int total;
  final int page;
  final int totalPages;

  const SalePage({required this.sales, required this.total, required this.page, required this.totalPages});
}

class SaleRepository {
  SaleRepository(this._api);
  final ApiClient _api;

  /// Unwraps the invoice from an API response body. Return/exchange wrap it as
  /// `data: { sale, settlement }`, everything else returns it bare, so accept
  /// either shape rather than silently parsing defaults when it is wrapped.
  Sale _saleFrom(Map<String, dynamic> res) {
    final data = res['data'] as Map<String, dynamic>;
    final payload = data['sale'];
    return Sale.fromJson(payload is Map<String, dynamic> ? payload : data);
  }

  Future<SalePage> getSales({String? shopId, DateTime? from, DateTime? to, int page = 1, int limit = 30}) async {
    final res = await _api.request('GET', '/sales', query: {
      'shopId': ?shopId,
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
      'page': '$page',
      'limit': '$limit',
    });
    final data = res['data'] as Map<String, dynamic>;
    return SalePage(
      sales: (data['sales'] as List).map((e) => Sale.fromJson(e as Map<String, dynamic>)).toList(),
      total: (data['total'] as num?)?.toInt() ?? 0,
      page: (data['page'] as num?)?.toInt() ?? 1,
      totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<Sale> getSale(String id) async {
    final res = await _api.request('GET', '/sales/$id');
    return Sale.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Sale> create({
    required List<Map<String, dynamic>> items,
    String customerName = 'Walk-in Customer',
    String customerPhone = '',
    double discount = 0,
    String paymentMethod = 'cash',
    String notes = '',
    String? shopId,
    double paidAmount = 0,
  }) async {
    final res = await _api.request('POST', '/sales', data: {
      'customerName': customerName,
      'customerPhone': customerPhone,
      'items': items,
      'discount': discount,
      'paymentMethod': paymentMethod,
      'notes': notes,
      'paidAmount': paidAmount,
      'shopId': ?shopId,
    });
    return Sale.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Sale> update(String id, Map<String, dynamic> data) async {
    final res = await _api.request('PUT', '/sales/$id', data: data);
    return Sale.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id, {String reason = '', bool restock = false}) async {
    await _api.request('DELETE', '/sales/$id', data: {'deleteReason': reason, 'restock': restock});
  }

  Future<Sale> restore(String id) async {
    final res = await _api.request('POST', '/sales/$id/restore');
    return Sale.fromJson(res['data'] as Map<String, dynamic>);
  }

  /// Appends extra product lines to an existing invoice (stock leaves the shop).
  Future<Sale> addItems(String id, List<Map<String, dynamic>> items, {String notes = ''}) async {
    final res = await _api.request('POST', '/sales/$id/items', data: {
      'items': items,
      if (notes.isNotEmpty) 'notes': notes,
    });
    return Sale.fromJson(res['data'] as Map<String, dynamic>);
  }

  /// Hands products back with no replacement. Stock is always restocked.
  Future<Sale> returnItems(
    String id, {
    required List<Map<String, dynamic>> items,
    String reason = '',
    Map<String, dynamic>? settlement,
  }) async {
    final res = await _api.request('POST', '/sales/$id/return', data: {
      'incoming': items,
      if (reason.isNotEmpty) 'reason': reason,
      'settlement': ?settlement,
    });
    return _saleFrom(res);
  }

  /// Hands products back and issues replacements in one atomic operation.
  Future<Sale> exchangeItems(
    String id, {
    required List<Map<String, dynamic>> incoming,
    required List<Map<String, dynamic>> outgoing,
    String reason = '',
    String note = '',
    Map<String, dynamic>? settlement,
  }) async {
    final res = await _api.request('POST', '/sales/$id/exchange', data: {
      'incoming': incoming,
      'outgoing': outgoing,
      if (reason.isNotEmpty) 'reason': reason,
      if (note.isNotEmpty) 'note': note,
      'settlement': ?settlement,
    });
    return _saleFrom(res);
  }

  /// Records a standalone top-up or refund against an invoice.
  Future<Sale> recordPayment(
    String id, {
    required String type,
    required double amount,
    String method = '',
    String note = '',
  }) async {
    final res = await _api.request('POST', '/sales/$id/payment', data: {
      'type': type,
      'amount': amount,
      'method': method,
      'note': note,
    });
    return Sale.fromJson(res['data'] as Map<String, dynamic>);
  }
}
