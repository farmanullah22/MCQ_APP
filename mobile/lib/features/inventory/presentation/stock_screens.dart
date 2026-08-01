import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/status_views.dart';
import '../../products/models/product.dart';
import '../../products/providers/product_providers.dart';
import '../providers/inventory_providers.dart';

class StockInScreen extends ConsumerStatefulWidget {
  const StockInScreen({super.key, this.productId, this.products});

  final String? productId;
  final List<Product>? products;

  @override
  ConsumerState<StockInScreen> createState() => _StockInScreenState();
}

class _StockInScreenState extends ConsumerState<StockInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _supplierController = TextEditingController();
  final _notesController = TextEditingController();
  String? _productId;

  @override
  void initState() {
    super.initState();
    _productId = widget.productId;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _supplierController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(stockMutationControllerProvider.select((s) => s.loading));
    final products = widget.products ?? ref.watch(productListControllerProvider).data.value?.products ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Stock In')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _productId,
                decoration: const InputDecoration(labelText: 'Product', prefixIcon: Icon(Icons.carpenter_outlined)),
                items: products
                    .map((p) => DropdownMenuItem(value: (p as dynamic).id.toString(), child: Text('${p.name} (${p.quantity} in stock)')))
                    .toList(),
                onChanged: (v) => setState(() => _productId = v),
                validator: (v) => v == null ? 'Select a product' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                validator: (v) {
                  final e = Validators.positiveNumber(v);
                  if (e != null) return e;
                  if (int.tryParse(v!.trim()) == 0) return 'Quantity must be greater than 0';
                  return null;
                },
                decoration: const InputDecoration(labelText: 'Quantity', prefixIcon: Icon(Icons.add_box_outlined)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _supplierController,
                decoration: const InputDecoration(labelText: 'Supplier', prefixIcon: Icon(Icons.local_shipping_outlined)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes', alignLabelWithHint: true),
              ),
              const SizedBox(height: 24),
              LoadingButton(
                loading: loading,
                label: 'Add Stock',
                icon: Icons.arrow_downward,
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  final ok = await ref.read(stockMutationControllerProvider.notifier).stockIn(
                        productId: _productId!,
                        quantity: int.parse(_quantityController.text.trim()),
                        supplier: _supplierController.text.trim(),
                        notes: _notesController.text.trim(),
                      );
                  if (!context.mounted) return;
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock added successfully')));
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ref.read(stockMutationControllerProvider).error ?? 'Stock in failed')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StockOutScreen extends ConsumerStatefulWidget {
  const StockOutScreen({super.key, this.products});

  final List<dynamic>? products;

  @override
  ConsumerState<StockOutScreen> createState() => _StockOutScreenState();
}

class _StockOutScreenState extends ConsumerState<StockOutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  String? _productId;

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(stockMutationControllerProvider.select((s) => s.loading));
    final products = widget.products ?? ref.watch(productListControllerProvider).data.value?.products ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Stock Out')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Product', prefixIcon: Icon(Icons.carpenter_outlined)),
                items: products
                    .map((p) => DropdownMenuItem(value: (p as dynamic).id.toString(), child: Text('${p.name} (${p.quantity} in stock)')))
                    .toList(),
                onChanged: (v) => setState(() => _productId = v),
                validator: (v) => v == null ? 'Select a product' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                validator: (v) {
                  final e = Validators.positiveNumber(v);
                  if (e != null) return e;
                  if (int.tryParse(v!.trim()) == 0) return 'Quantity must be greater than 0';
                  return null;
                },
                decoration: const InputDecoration(labelText: 'Quantity', prefixIcon: Icon(Icons.indeterminate_check_box_outlined)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(labelText: 'Reason (e.g. damaged, sample)', prefixIcon: Icon(Icons.info_outline)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes', alignLabelWithHint: true),
              ),
              const SizedBox(height: 24),
              LoadingButton(
                loading: loading,
                label: 'Remove Stock',
                icon: Icons.arrow_upward,
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  final ok = await ref.read(stockMutationControllerProvider.notifier).stockOut(
                        productId: _productId!,
                        quantity: int.parse(_quantityController.text.trim()),
                        reason: _reasonController.text.trim(),
                        notes: _notesController.text.trim(),
                      );
                  if (!context.mounted) return;
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock removed successfully')));
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ref.read(stockMutationControllerProvider).error ?? 'Stock out failed')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LowStockScreen extends ConsumerWidget {
  const LowStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productListControllerProvider.select((s) => s));
    return Scaffold(
      appBar: AppBar(title: const Text('Low Stock Alerts')),
      body: state.data.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: e.toString()),
        data: (page) {
          final low = page.products.where((p) => p.isLowStock).toList();
          if (low.isEmpty) {
            return const Center(child: Text('All products are well stocked'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: low.length,
            itemBuilder: (context, i) {
              final p = low[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.warning_amber, color: AppColors.danger),
                  title: Text(p.name),
                  subtitle: Text('Only ${p.quantity} left (threshold ${p.lowStockThreshold})'),
                  trailing: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => StockInScreen(productId: p.id)),
                    ),
                    child: const Text('Restock'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
