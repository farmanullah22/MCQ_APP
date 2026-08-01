import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../../products/providers/product_providers.dart';
import '../data/sale_repository.dart';
import '../models/sale.dart';

class SaleListState {
  final AsyncValue<SalePage> data;

  const SaleListState({this.data = const AsyncValue.loading()});
}

class SaleListController extends Notifier<SaleListState> {
  @override
  SaleListState build() {
    _load();
    return const SaleListState();
  }

  Future<void> _load() async {
    try {
      final page = await ref.read(saleRepositoryProvider).getSales();
      state = SaleListState(data: AsyncValue.data(page));
    } catch (e, st) {
      state = SaleListState(data: AsyncValue.error(e, st));
    }
  }

  Future<void> refresh() => _load();
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

  void reset() => state = const SaleMutationState();
}

final saleMutationControllerProvider =
    NotifierProvider<SaleMutationController, SaleMutationState>(SaleMutationController.new);
