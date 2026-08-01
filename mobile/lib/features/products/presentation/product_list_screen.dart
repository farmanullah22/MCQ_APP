import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_views.dart';
import '../../categories/providers/category_providers.dart';
import '../../inventory/presentation/stock_screens.dart';
import '../models/product.dart';
import '../providers/product_providers.dart';
import 'product_form_screen.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productListControllerProvider);
    final categories = ref.watch(categoryListControllerProvider).data.value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            tooltip: 'Low stock only',
            onPressed: () => ref.read(productListControllerProvider.notifier).setLowStockOnly(!state.lowStockOnly),
            icon: Icon(
              state.lowStockOnly ? Icons.warning_amber : Icons.warning_amber_outlined,
              color: state.lowStockOnly ? AppColors.danger : null,
            ),
          ),
          IconButton(
            tooltip: 'Add Product',
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => ref.read(productListControllerProvider.notifier).setSearch(v),
              decoration: InputDecoration(
                hintText: 'Search by name, SKU or barcode...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: state.search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(productListControllerProvider.notifier).setSearch('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: state.categoryId == null,
                    onSelected: (_) => ref.read(productListControllerProvider.notifier).setCategory(null),
                  ),
                ),
                ...categories.map((c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(c.name),
                        selected: state.categoryId == c.id,
                        onSelected: (_) => ref.read(productListControllerProvider.notifier).setCategory(c.id),
                      ),
                    )),
              ],
            ),
          ),
          Expanded(
            child: state.data.when(
              loading: () => const LoadingView(),
              error: (e, st) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.read(productListControllerProvider.notifier).refresh(),
              ),
              data: (page) {
                if (page.products.isEmpty) {
                  return EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: state.lowStockOnly ? 'No low stock products' : 'No products found',
                    subtitle: state.lowStockOnly ? 'All products are well stocked.' : 'Add your first product to get started.',
                    action: state.lowStockOnly ? null : () => _openForm(context),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(productListControllerProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: page.products.length,
                    itemBuilder: (context, index) {
                      final product = page.products[index];
                      return _ProductCard(
                        product: product,
                        onTap: () => _openForm(context, product: product),
                        onEdit: () => _openForm(context, product: product),
                        onStockIn: () => _openStockIn(context, product),
                        onDelete: () => _confirmDelete(context, product),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openForm(BuildContext context, {Product? product}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );
  }

  void _openStockIn(BuildContext context, Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StockInScreen(productId: product.id)),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete "${product.name}"? This will be recorded in the audit log and can be restored by the admin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ref.read(productMutationControllerProvider.notifier).delete(product.id);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(productMutationControllerProvider).error ?? 'Delete failed')),
      );
    }
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onEdit,
    required this.onStockIn,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onStockIn;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lowStock = product.isLowStock;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.carpenter_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ),
                        if (lowStock)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'LOW',
                              style: TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        product.categoryName ?? 'Uncategorized',
                        if (product.brand.isNotEmpty) product.brand,
                        if (product.sku.isNotEmpty) product.sku,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          Formatters.currency(product.sellingPrice),
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 15),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Cost ${Formatters.currency(product.costPrice)}',
                          style: theme.textTheme.bodySmall,
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: lowStock ? AppColors.danger.withValues(alpha: 0.12) : AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${product.quantity} in stock',
                            style: TextStyle(
                              color: lowStock ? AppColors.danger : AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
