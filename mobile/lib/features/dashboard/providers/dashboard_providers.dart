import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/dashboard_data.dart';

class DashboardState {
  final AsyncValue<DashboardData> data;
  final String? selectedShopId;
  final List<({String id, String name})> shops;

  const DashboardState({
    this.data = const AsyncValue.loading(),
    this.selectedShopId,
    this.shops = const [],
  });

  DashboardState copyWith({
    AsyncValue<DashboardData>? data,
    String? selectedShopId,
    List<({String id, String name})>? shops,
    bool clearShop = false,
  }) {
    return DashboardState(
      data: data ?? this.data,
      selectedShopId: clearShop ? null : (selectedShopId ?? this.selectedShopId),
      shops: shops ?? this.shops,
    );
  }
}

class DashboardController extends Notifier<DashboardState> {
  @override
  DashboardState build() {
    _loadShops();
    _load();
    return const DashboardState();
  }

  Future<void> _loadShops() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    if (!user.isAdmin) {
      final shopName = user.assignedShopName;
      final shopId = user.assignedShopId;
      if (shopId != null) {
        state = state.copyWith(
          selectedShopId: shopId,
          shops: [(id: shopId, name: shopName ?? 'My Shop')],
        );
      }
      return;
    }
    try {
      final shops = await ref.read(shopRepositoryProvider).getShops();
      state = state.copyWith(
        shops: shops.map((s) => (id: s.id, name: s.name)).toList(),
      );
    } catch (_) {
      // shops load best-effort
    }
  }

  Future<void> _load() async {
    state = state.copyWith(data: const AsyncValue.loading());
    try {
      final data = await ref.read(dashboardRepositoryProvider).getDashboard(
            shopId: state.selectedShopId,
          );
      state = state.copyWith(data: AsyncValue.data(data));
    } catch (e, st) {
      state = state.copyWith(data: AsyncValue.error(e, st));
    }
  }

  Future<void> refresh() async {
    await _load();
  }

  void selectShop(String? shopId) {
    state = state.copyWith(selectedShopId: shopId);
    _load();
  }

  // Re-fetches after quick actions (add product, stock changes, sales).
  Future<void> reload() => _load();
}

final dashboardControllerProvider =
    NotifierProvider<DashboardController, DashboardState>(DashboardController.new);
