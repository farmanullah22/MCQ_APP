import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/app_bar_brand.dart';
import '../../../core/widgets/status_views.dart';
import '../models/inventory_log.dart';
import '../providers/inventory_providers.dart';
import 'stock_screens.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inventoryHistoryControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const AppBarBrand(showText: false),
            const SizedBox(width: 10),
            Text('Inventory'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Low stock',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LowStockScreen()),
            ),
            icon: const Icon(Icons.warning_amber_outlined),
          ),
          PopupMenuButton<String?>(
            initialValue: state.actionType,
            onSelected: (v) => ref.read(inventoryHistoryControllerProvider.notifier).setActionType(v),
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: null, child: Text('All Activity')),
              PopupMenuItem(value: 'stock_in', child: Text('Stock In')),
              PopupMenuItem(value: 'stock_out', child: Text('Stock Out')),
            ],
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(inventoryHistoryControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'stockOut',
        tooltip: 'Stock Out',
        backgroundColor: AppColors.danger,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const StockOutScreen()),
        ),
        child: const Icon(Icons.arrow_upward),
      ),
      body: state.data.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.read(inventoryHistoryControllerProvider.notifier).refresh(),
        ),
        data: (result) {
          if (result.logs.isEmpty) {
            return const EmptyState(
              icon: Icons.sync_alt,
              title: 'No stock activity yet',
              subtitle: 'Stock in or stock out to see a history here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(inventoryHistoryControllerProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: result.logs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _InventoryTile(log: result.logs[index]),
            ),
          );
        },
      ),
    );
  }
}

class _InventoryTile extends StatelessWidget {
  const _InventoryTile({required this.log});

  final InventoryLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stockIn = log.isStockIn;
    final color = stockIn ? AppColors.success : AppColors.danger;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                stockIn ? Icons.arrow_downward : Icons.arrow_upward,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          log.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ),
                      Text(
                        '${stockIn ? '+' : '-'}${log.quantity}',
                        style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (log.supplier.isNotEmpty) 'Supplier: ${log.supplier}',
                      if (log.reason.isNotEmpty) log.reason,
                      if (log.performedByName.isNotEmpty) log.performedByName,
                      if (log.shopName.isNotEmpty) log.shopName,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      'Stock: ${log.previousStock} → ${log.newStock}',
                      Formatters.dateTime(log.date),
                    ].join('  ·  '),
                    style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
