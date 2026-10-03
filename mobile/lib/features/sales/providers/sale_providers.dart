import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../../products/providers/product_providers.dart';
import '../data/sale_repository.dart';
import '../models/sale.dart';

class SaleListState {
  final AsyncValue<SalePage> data;
  final DateTime? from;
  final DateTime? to;

  const SaleListState({this.data = const AsyncValue.loading(), this.from, this.to});
}

class SaleListController extends Notifier<SaleListState> {
  @override
  SaleListState build() {
    Future.microtask(() {
      if (ref.mounted) _load(state.from, state.to);
    });
    return const SaleListState();
  }

  Future<void> _load(DateTime? from, DateTime? to) async {
    try {
      final page = await ref.read(saleRepositoryProvider).getSales(from: from, to: to);
      state = SaleListState(data: AsyncValue.data(page), from: from, to: to);
    } catch (e, st) {
      state = SaleListState(data: AsyncValue.error(e, st), from: from, to: to);
    }
  }

  Future<void> refresh() async {
    final from = state.from;
    final to = state.to;
    await _load(from, to);
  }

  Future<void> setDateRange(DateTime? from, DateTime? to) {
    state = SaleListState(from: from, to: to);
    return _load(from, to);
  }
}

final saleListControllerProvider =
    NotifierProvider<SaleListController, SaleListState>(SaleListController.new);

class SaleMutationState {
  final bool loading;
  final String? error;
  final Sale? sale;

  const SaleMutationState({this.loading = false, this.error, this.sale});
}

class SaleMutationController extends Notifier<SaleMutationState> {
  @override
  SaleMutationState build() => const SaleMutationState();

  Future<Sale?> create({
    required List<Map<String, dynamic>> items,
    String customerName = 'Walk-in Customer',
    String customerPhone = '',
    double discount = 0,
    String paymentMethod = 'cash',
    String notes = '',
    String? shopId,
    double paidAmount = 0,
  }) async {
    state = const SaleMutationState(loading: true);
    try {
      final sale = await ref.read(saleRepositoryProvider).create(
            items: items,
            customerName: customerName,
            customerPhone: customerPhone,
            discount: discount,
            paymentMethod: paymentMethod,
            notes: notes,
            shopId: shopId,
            paidAmount: paidAmount,
          );
      state = SaleMutationState(sale: sale);
      ref.invalidate(saleListControllerProvider);
      ref.invalidate(inventoryHistoryControllerProvider);
      ref.invalidate(productListControllerProvider);
      ref.invalidate(dashboardControllerProvider);
      return sale;
    } catch (e) {
      state = SaleMutationState(error: e.toString());
      return null;
    }
  }

  Future<bool> delete(String id, {String reason = '', bool restock = false}) async {
    state = const SaleMutationState(loading: true);
    try {
      await ref.read(saleRepositoryProvider).delete(id, reason: reason, restock: restock);
      ref.invalidate(saleListControllerProvider);
      ref.invalidate(dashboardControllerProvider);
      state = const SaleMutationState();
      return true;
    } catch (e) {
      state = SaleMutationState(error: e.toString());
      return false;
    }
  }

  // Every adjustment moves stock and money, so all of them refresh the same
  // set of caches as a fresh sale does.
  void _afterAdjustment(Sale sale) {
    state = SaleMutationState(sale: sale);
    ref.invalidate(saleListControllerProvider);
    ref.invalidate(inventoryHistoryControllerProvider);
    ref.invalidate(productListControllerProvider);
    ref.invalidate(dashboardControllerProvider);
  }

  Future<Sale?> addItems(
    String id,
    List<Map<String, dynamic>> items, {
    String notes = '',
  }) async {
    state = const SaleMutationState(loading: true);
    try {
      final sale =
          await ref.read(saleRepositoryProvider).addItems(id, items, notes: notes);
      _afterAdjustment(sale);
      return sale;
    } catch (e) {
      state = SaleMutationState(error: e.toString());
      return null;
    }
  }

  Future<Sale?> returnItems(
    String id, {
    required List<Map<String, dynamic>> items,
    String reason = '',
    Map<String, dynamic>? settlement,
  }) async {
    state = const SaleMutationState(loading: true);
    try {
      final sale = await ref.read(saleRepositoryProvider).returnItems(
            id,
            items: items,
            reason: reason,
            settlement: settlement,
          );
      _afterAdjustment(sale);
      return sale;
    } catch (e) {
      state = SaleMutationState(error: e.toString());
      return null;
    }
  }

  Future<Sale?> exchangeItems(
    String id, {
    required List<Map<String, dynamic>> incoming,
    required List<Map<String, dynamic>> outgoing,
    String reason = '',
    String note = '',
    Map<String, dynamic>? settlement,
  }) async {
    state = const SaleMutationState(loading: true);
    try {
      final sale = await ref.read(saleRepositoryProvider).exchangeItems(
            id,
            incoming: incoming,
            outgoing: outgoing,
            note: note,
            reason: reason,
            settlement: settlement,
          );
      _afterAdjustment(sale);
      return sale;
    } catch (e) {
      state = SaleMutationState(error: e.toString());
      return null;
    }
  }

  Future<Sale?> recordPayment(
    String id, {
    required String type,
    required double amount,
    String method = '',
    String note = '',
  }) async {
    state = const SaleMutationState(loading: true);
    try {
      final sale = await ref.read(saleRepositoryProvider).recordPayment(
            id,
            type: type,
            amount: amount,
            method: method,
            note: note,
          );
      _afterAdjustment(sale);
      return sale;
    } catch (e) {
      state = SaleMutationState(error: e.toString());
      return null;
    }
  }

  void reset() => state = const SaleMutationState();
}

final saleMutationControllerProvider =
    NotifierProvider<SaleMutationController, SaleMutationState>(SaleMutationController.new);
