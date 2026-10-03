import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../products/models/product.dart';
import '../../products/providers/product_providers.dart';
import '../models/sale.dart';
import '../providers/sale_providers.dart';

class _AddLine {
  _AddLine({required this.productId, required this.productName, required this.maxQty})
      : quantity = 1,
        unitPrice = 0;

  final String productId;
  final String productName;
  final int maxQty;
  int quantity;
  double unitPrice;

  double get total => quantity * unitPrice;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };
}

/// Appends extra products to an invoice that has already been issued. The
/// original line items are never rewritten - these are added on top.
class SaleAddItemsScreen extends ConsumerStatefulWidget {
  const SaleAddItemsScreen({super.key, required this.sale});

  final Sale sale;

  @override
  ConsumerState<SaleAddItemsScreen> createState() => _SaleAddItemsScreenState();
}

class _SaleAddItemsScreenState extends ConsumerState<SaleAddItemsScreen> {
  final _lines = <_AddLine>[];

  @override
  void dispose() {
    super.dispose();
  }

  double get _subtotal => _lines.fold<double>(0, (a, l) => a + l.total);

  void _add(Product product) {
    if (product.quantity <= 0) return;
    final existing = _lines.where((l) => l.productId == product.id).firstOrNull;
    if (existing != null) {
      if (existing.quantity >= product.quantity) return;
      setState(() => existing.quantity++);
      return;
    }
    setState(() => _lines.add(_AddLine(
          productId: product.id,
          productName: product.name,
          maxQty: product.quantity,
        )..unitPrice = product.sellingPrice));
  }

  Future<void> _submit() async {
    if (_lines.isEmpty) return;
    final updated = await ref.read(saleMutationControllerProvider.notifier).addItems(
          widget.sale.id,
          _lines.map((l) => l.toJson()).toList(),
        );
    if (!mounted) return;
    if (updated == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ref.read(saleMutationControllerProvider).error ?? 'Could not save'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final loading =
        ref.watch(saleMutationControllerProvider.select((s) => s.loading));
    final products = ref.watch(productListControllerProvider).data.value?.products ?? const [];
    final inStock = products.where((p) => p.quantity > 0).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final byId = {for (final p in products) p.id: p};

    return Scaffold(
      appBar: AppBar(title: const Text('Add Products')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _lines.isEmpty || loading ? null : _submit,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(loading
                  ? 'Saving...'
                  : _lines.isEmpty
                      ? 'Add at least one product'
                      : 'Add ${Formatters.currency(_subtotal)} to invoice'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: AppColors.info),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Invoice ${widget.sale.invoiceNo} - new products are appended and stock leaves the shop immediately.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Add product',
                  prefixIcon: Icon(Icons.add_shopping_cart),
                ),
                items: inStock
                    .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text('${p.name} (${p.quantity} in stock)',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (id) {
                  if (id != null) _add(byId[id]!);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_lines.isEmpty)
            const EmptyState(
              icon: Icons.playlist_add,
              title: 'No products added',
              subtitle: 'Pick a product above to append it to this invoice.',
            )
          else
            Card(
              child: Column(
                children: [
                  for (final line in _lines) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(line.productName,
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(Formatters.currency(line.total),
                                    style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                          _QtyStepper(
                            value: line.quantity,
                            max: line.maxQty,
                            onChanged: (qty) => setState(() => line.quantity = qty),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            onPressed: () => setState(
                                () => _lines.removeWhere((l) => l.productId == line.productId)),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: TextFormField(
                        initialValue: line.unitPrice.toStringAsFixed(0),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Selling price',
                          isDense: true,
                        ),
                        onChanged: (v) => line.unitPrice = double.tryParse(v) ?? line.unitPrice,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.value, required this.max, required this.onChanged});

  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove, size: 18),
          ),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}