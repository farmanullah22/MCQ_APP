import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/validators.dart';
import '../../../core/widgets/status_views.dart';
import '../../categories/providers/category_providers.dart';
import '../../products/models/product.dart';
import '../providers/product_providers.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _barcode;
  late final TextEditingController _brand;
  late final TextEditingController _supplier;
  late final TextEditingController _costPrice;
  late final TextEditingController _sellingPrice;
  late final TextEditingController _quantity;
  late final TextEditingController _threshold;
  late final TextEditingController _description;

  String? _categoryId;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _isEdit = p != null;
    _name = TextEditingController(text: p?.name ?? '');
    _sku = TextEditingController(text: p?.sku ?? '');
    _barcode = TextEditingController(text: p?.barcode ?? '');
    _brand = TextEditingController(text: p?.brand ?? '');
    _supplier = TextEditingController(text: p?.supplier ?? '');
    _costPrice = TextEditingController(text: p != null ? '${p.costPrice}' : '');
    _sellingPrice = TextEditingController(text: p != null ? '${p.sellingPrice}' : '');
    _quantity = TextEditingController(text: p != null ? '${p.quantity}' : '0');
    _threshold = TextEditingController(text: p != null ? '${p.lowStockThreshold}' : '5');
    _description = TextEditingController(text: p?.description ?? '');
    _categoryId = p?.categoryId;
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _barcode.dispose();
    _brand.dispose();
    _supplier.dispose();
    _costPrice.dispose();
    _sellingPrice.dispose();
    _quantity.dispose();
    _threshold.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(productMutationControllerProvider.notifier);
    final data = {
      'name': _name.text.trim(),
      'sku': _sku.text.trim(),
      'barcode': _barcode.text.trim(),
      'category': _categoryId,
      'brand': _brand.text.trim(),
      'supplier': _supplier.text.trim(),
      'costPrice': double.parse(_costPrice.text.trim()),
      'sellingPrice': double.parse(_sellingPrice.text.trim()),
      'lowStockThreshold': int.tryParse(_threshold.text.trim()) ?? 5,
      'description': _description.text.trim(),
    };

    final ok = _isEdit
        ? await notifier.update(widget.product!.id, data)
        : await notifier.create({...data, 'quantity': int.tryParse(_quantity.text.trim()) ?? 0});

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(productMutationControllerProvider).error ?? 'Failed to save product')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(productMutationControllerProvider.select((s) => s.loading));
    final categories = ref.watch(categoryListControllerProvider).data.value ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Product' : 'Add Product')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _name,
                validator: (v) => Validators.required(v),
                decoration: const InputDecoration(labelText: 'Product Name', prefixIcon: Icon(Icons.carpenter_outlined)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sku,
                      decoration: const InputDecoration(labelText: 'SKU', prefixIcon: Icon(Icons.tag)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _barcode,
                      decoration: const InputDecoration(labelText: 'Barcode', prefixIcon: Icon(Icons.qr_code_2)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined)),
                items: [
                  const DropdownMenuItem(value: null, child: Text('No category')),
                  ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _brand,
                      decoration: const InputDecoration(labelText: 'Brand'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _supplier,
                      decoration: const InputDecoration(labelText: 'Supplier'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costPrice,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: Validators.positiveNumber,
                      decoration: const InputDecoration(labelText: 'Cost Price (Rs.)', prefixIcon: Icon(Icons.payments_outlined)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _sellingPrice,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: Validators.positiveNumber,
                      decoration: const InputDecoration(labelText: 'Selling Price (Rs.)', prefixIcon: Icon(Icons.sell_outlined)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantity,
                      enabled: !_isEdit,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Initial Quantity'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _threshold,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Low Stock Alert'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
              ),
              const SizedBox(height: 24),
              LoadingButton(
                loading: loading,
                label: _isEdit ? 'Update Product' : 'Add Product',
                icon: _isEdit ? Icons.save_outlined : Icons.add,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
