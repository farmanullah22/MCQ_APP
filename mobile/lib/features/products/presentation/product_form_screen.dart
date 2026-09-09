import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/status_views.dart';
import '../../categories/providers/category_providers.dart';
import '../../products/models/product.dart';
import '../../suppliers/models/supplier.dart';
import '../providers/product_providers.dart';
import '../../../core/providers/repository_providers.dart';

class _CarpetPiece {
  final double width;
  final double height;
  final String color;
  final Uint8List? imageBytes;

  const _CarpetPiece({
    required this.width,
    required this.height,
    this.color = '',
    this.imageBytes,
  });

  double get area => width * height;
}

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _brand;
  late final TextEditingController _supplier;
  late final TextEditingController _threshold;
  late final TextEditingController _description;

  late final TextEditingController _carpetWidth;
  late final TextEditingController _carpetHeight;
  late final TextEditingController _carpetPieces;
  late final TextEditingController _costPerSqft;

  late final TextEditingController _qaleenQty;
  late final TextEditingController _costPerPiece;

  late final TextEditingController _meterLength;
  late final TextEditingController _costPerMeter;

  late String _productType;
  List<QaleenSize> _qaleenSizes = [];
  final List<_CarpetPiece> _carpetPieceDetails = [];
  String? _categoryId;
  bool _isEdit = false;
  List<Supplier> _suppliers = [];
  String? _supplierName;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _isEdit = p != null;
    _name = TextEditingController(text: p?.name ?? '');
    _barcode = TextEditingController(text: p?.barcode ?? '');
    _brand = TextEditingController(text: p?.brand ?? '');
    _supplier = TextEditingController(text: p?.supplier ?? '');
    _threshold = TextEditingController(text: p != null ? '${p.lowStockThreshold}' : '5');
    _description = TextEditingController(text: p?.description ?? '');
    _categoryId = p?.categoryId;
    _productType = p?.productType ?? 'qaleen';

    _carpetWidth = TextEditingController(text: p != null && p.carpetWidth > 0 ? '${p.carpetWidth}' : '');
    _carpetHeight = TextEditingController(text: p != null && p.carpetHeight > 0 ? '${p.carpetHeight}' : '');
    _carpetPieces = TextEditingController(text: p != null && p.carpetPieces > 0 ? '${p.carpetPieces}' : '');
    _costPerSqft = TextEditingController(text: p != null && p.costPerSqft > 0 ? '${p.costPerSqft}' : '');

    for (final piece in p?.carpetPiecesData ?? const <CarpetPieceData>[]) {
      Uint8List? bytes;
      if (piece.image.startsWith('data:image')) {
        try {
          bytes = base64.decode(piece.image.split(',').last);
        } catch (_) {}
      }
      _carpetPieceDetails.add(_CarpetPiece(
        width: piece.width,
        height: piece.height,
        color: piece.color,
        imageBytes: bytes,
      ));
    }

    _qaleenQty = TextEditingController(text: p != null && p.productType == 'qaleen' && p.qaleenSizes.isEmpty ? '${p.quantity}' : '');
    _costPerPiece = TextEditingController(text: p != null && p.costPerPiece > 0 ? '${p.costPerPiece}' : '');
    _qaleenSizes = p?.qaleenSizes.toList() ?? [];

    _meterLength = TextEditingController(text: p != null && p.meterLength > 0 ? '${p.meterLength}' : '');
    _costPerMeter = TextEditingController(text: p != null && p.costPerMeter > 0 ? '${p.costPerMeter}' : '');

    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    try {
      final page = await ref.read(supplierRepositoryProvider).getSuppliers(limit: 200);
      if (!mounted) return;
      final suppliers = page.suppliers;
      setState(() {
        _suppliers = suppliers;
        final existing = widget.product?.supplier ?? '';
        if (existing.isNotEmpty) {
          final matches = suppliers.where((sp) => sp.name == existing).toList();
          _supplierName = matches.isNotEmpty ? matches.first.name : existing;
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _brand.dispose();
    _supplier.dispose();
    _threshold.dispose();
    _description.dispose();
    _carpetWidth.dispose();
    _carpetHeight.dispose();
    _carpetPieces.dispose();
    _costPerSqft.dispose();
    _qaleenQty.dispose();
    _costPerPiece.dispose();
    _meterLength.dispose();
    _costPerMeter.dispose();
    super.dispose();
  }

  int get _computedQuantity {
    switch (_productType) {
      case 'carpet':
        if (_carpetPieceDetails.isNotEmpty) {
          return _carpetPieceDetails.fold<int>(0, (sum, p) => sum + (p.width * p.height).round());
        }
        final w = double.tryParse(_carpetWidth.text) ?? 0;
        final h = double.tryParse(_carpetHeight.text) ?? 0;
        return (w * h).round();
      case 'qaleen':
        if (_qaleenSizes.isNotEmpty) {
          return _qaleenSizes.fold(0, (sum, s) => sum + s.pieces);
        }
        return int.tryParse(_qaleenQty.text) ?? 0;
      case 'meter':
        return (double.tryParse(_meterLength.text) ?? 0).toInt();
      default:
        return 0;
    }
  }

  double get _computedCostPrice {
    switch (_productType) {
      case 'carpet':
        return double.tryParse(_costPerSqft.text) ?? 0;
      case 'qaleen':
        final cpp = double.tryParse(_costPerPiece.text) ?? 0;
        return cpp;
      case 'meter':
        return double.tryParse(_costPerMeter.text) ?? 0;
      default:
        return 0;
    }
  }

  String _buildPieceImageDataUrl(Uint8List bytes) {
    final ext = bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50 ? 'png' : 'jpeg';
    return 'data:image/$ext;base64,${base64.encode(bytes)}';
  }

  void _addQaleenSize() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final hCtrl = TextEditingController();
        final wCtrl = TextEditingController();
        final pCtrl = TextEditingController();
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add Size', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(controller: hCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Height (m)')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(controller: wCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Width (m)')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(controller: pCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pieces')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  final h = double.tryParse(hCtrl.text) ?? 0;
                  final w = double.tryParse(wCtrl.text) ?? 0;
                  final pcs = int.tryParse(pCtrl.text) ?? 0;
                  if (h > 0 && w > 0 && pcs > 0) {
                    setState(() => _qaleenSizes.add(QaleenSize(height: h, width: w, pieces: pcs)));
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addCarpetPiece() async {
    final wCtrl = TextEditingController();
    final hCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    Uint8List? imageBytes;
    var areaText = 'Total area: 0 sqft';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            void refresh() {
              final w = double.tryParse(wCtrl.text) ?? 0;
              final h = double.tryParse(hCtrl.text) ?? 0;
              areaText = 'Total area: ${(w * h).toStringAsFixed(2)} sqft';
              setSheetState(() {});
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add Piece', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('Piece ${_carpetPieceDetails.length + 1}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: wCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => refresh(),
                          decoration: const InputDecoration(labelText: 'Width (m)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: hCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => refresh(),
                          decoration: const InputDecoration(labelText: 'Height (m)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(areaText, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: colorCtrl,
                    decoration: const InputDecoration(labelText: 'Color', prefixIcon: Icon(Icons.color_lens_outlined)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (imageBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(imageBytes!, height: 60, width: 60, fit: BoxFit.cover),
                        )
                      else
                        const SizedBox.shrink(),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                          if (picked != null) {
                            final bytes = await picked.readAsBytes();
                            setSheetState(() => imageBytes = bytes);
                          }
                        },
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: const Text('Gallery'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 80);
                          if (picked != null) {
                            final bytes = await picked.readAsBytes();
                            setSheetState(() => imageBytes = bytes);
                          }
                        },
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: const Text('Camera'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: () {
                      final w = double.tryParse(wCtrl.text) ?? 0;
                      final h = double.tryParse(hCtrl.text) ?? 0;
                      if (w <= 0 || h <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Please enter valid width and height')),
                        );
                        return;
                      }
                      setState(() {
                        _carpetPieceDetails.add(_CarpetPiece(
                          width: w,
                          height: h,
                          color: colorCtrl.text.trim(),
                          imageBytes: imageBytes,
                        ));
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Add Piece'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(productMutationControllerProvider.notifier);
    final data = <String, dynamic>{
      'name': _name.text.trim(),
      'barcode': _barcode.text.trim(),
      'category': _categoryId,
      'brand': _brand.text.trim(),
      'supplier': _supplierName ?? _supplier.text.trim(),
      'productType': _productType,
      'lowStockThreshold': int.tryParse(_threshold.text.trim()) ?? 5,
      'description': _description.text.trim(),
    };

    switch (_productType) {
      case 'carpet':
        data['carpetWidth'] = double.tryParse(_carpetWidth.text) ?? 0;
        data['carpetHeight'] = double.tryParse(_carpetHeight.text) ?? 0;
        data['carpetPieces'] = int.tryParse(_carpetPieces.text) ?? 0;
        data['costPerSqft'] = double.tryParse(_costPerSqft.text) ?? 0;
        data['quantity'] = _computedQuantity;
        if (_carpetPieceDetails.isNotEmpty) {
          data['carpetPiecesData'] = _carpetPieceDetails.map((p) => {
                'width': p.width,
                'height': p.height,
                'area': p.area,
                'color': p.color,
                if (p.imageBytes != null) 'image': _buildPieceImageDataUrl(p.imageBytes!),
              }).toList();
        }
        break;
      case 'qaleen':
        data['costPerPiece'] = double.tryParse(_costPerPiece.text) ?? 0;
        if (_qaleenSizes.isNotEmpty) {
          data['qaleenSizes'] = _qaleenSizes.map((s) => s.toJson()).toList();
          data['quantity'] = _computedQuantity;
        } else {
          data['quantity'] = int.tryParse(_qaleenQty.text) ?? 0;
        }
        break;
      case 'meter':
        data['meterLength'] = double.tryParse(_meterLength.text) ?? 0;
        data['costPerMeter'] = double.tryParse(_costPerMeter.text) ?? 0;
        break;
    }

    final ok = _isEdit
        ? await notifier.update(widget.product!.id, data)
        : await notifier.create(data);

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

              DropdownButtonFormField<String>(
                initialValue: _productType,
                decoration: const InputDecoration(labelText: 'Product Type', prefixIcon: Icon(Icons.category_outlined)),
                items: const [
                  DropdownMenuItem(value: 'carpet', child: Text('Carpet (sqft)')),
                  DropdownMenuItem(value: 'qaleen', child: Text('Qaleen (piece)')),
                  DropdownMenuItem(value: 'meter', child: Text('Meter')),
                ],
                onChanged: (v) => setState(() => _productType = v ?? 'qaleen'),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _barcode,
                decoration: const InputDecoration(labelText: 'Barcode', prefixIcon: Icon(Icons.qr_code_2)),
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
              TextFormField(
                controller: _brand,
                decoration: const InputDecoration(labelText: 'Brand'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _supplierName,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Supplier', prefixIcon: Icon(Icons.local_shipping_outlined)),
                hint: _suppliers.isEmpty ? const Text('No suppliers added yet') : const Text('Select a supplier'),
                items: _suppliers
                    .map((s) => DropdownMenuItem(value: s.name, child: Text(s.name, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _supplierName = v;
                  _supplier.text = v ?? '';
                }),
              ),
              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stock & Cost', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    _buildTypeFields(),
                    const SizedBox(height: 10),
                    _buildCostSummary(),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _threshold,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Low Stock Alert', prefixIcon: Icon(Icons.warning_amber_outlined)),
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

  Widget _buildTypeFields() {
    switch (_productType) {
      case 'carpet':
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _carpetWidth,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Width (m)', prefixIcon: Icon(Icons.swap_horiz)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _carpetHeight,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Height (m)', prefixIcon: Icon(Icons.swap_vert)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _carpetPieces,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Pieces (rolls)', prefixIcon: Icon(Icons.inventory_2_outlined)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _costPerSqft,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Cost / sqft (Rs.)', prefixIcon: Icon(Icons.payments_outlined)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _addCarpetPiece,
              icon: const Icon(Icons.add_box_outlined, size: 18),
              label: const Text('Add Piece'),
            ),
            const SizedBox(height: 4),
            if (_carpetPieceDetails.isNotEmpty)
              Column(
                children: [
                  const Divider(height: 16),
                  ...List.generate(_carpetPieceDetails.length, (i) {
                    final p = _carpetPieceDetails[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          if (p.imageBytes != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.memory(p.imageBytes!, height: 36, width: 36, fit: BoxFit.cover),
                            )
                          else
                            Container(
                              height: 36,
                              width: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.crop_landscape, size: 18, color: AppColors.primary),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${p.width}m x ${p.height}m | ${p.area.toStringAsFixed(2)} sqft'
                              '${p.color.isNotEmpty ? ' | ${p.color}' : ''}',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _carpetPieceDetails.removeAt(i)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
          ],
        );

      case 'qaleen':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_qaleenSizes.isEmpty)
              TextFormField(
                controller: _qaleenQty,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity (pieces)', prefixIcon: Icon(Icons.inventory_2_outlined)),
              )
            else
              Column(
                children: [
                  ...List.generate(_qaleenSizes.length, (i) {
                    final s = _qaleenSizes[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text('${s.height}m x ${s.width}m', style: const TextStyle(fontSize: 13))),
                          Text('${s.pieces} pcs', style: const TextStyle(fontSize: 13)),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _qaleenSizes.removeAt(i)),
                          ),
                        ],
                      ),
                    );
                  }),
                  Text('Total: $_computedQuantity pieces', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _addQaleenSize,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Size'),
                ),
                const Spacer(),
                Expanded(
                  child: TextFormField(
                    controller: _costPerPiece,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Cost / piece (Rs.)', prefixIcon: Icon(Icons.payments_outlined)),
                  ),
                ),
              ],
            ),
          ],
        );

      case 'meter':
        return Column(
          children: [
            TextFormField(
              controller: _meterLength,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Length (m)', prefixIcon: Icon(Icons.straighten)),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _costPerMeter,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Cost / meter (Rs.)', prefixIcon: Icon(Icons.payments_outlined)),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCostSummary() {
    final qty = _computedQuantity;
    final cost = _computedCostPrice; // per-unit cost (per sqft / per meter / per piece)
    final totalCost = qty * cost;

    String costLabel;
    switch (_productType) {
      case 'carpet':
        if (_carpetPieceDetails.isNotEmpty) {
          final labels = _carpetPieceDetails.map((p) => '${p.width.toInt()}x${p.height.toInt()}').join(' + ');
          costLabel = '$qty sqft total ($labels) x ${Formatters.currency(double.tryParse(_costPerSqft.text) ?? 0)}/sqft';
        } else {
          final w = double.tryParse(_carpetWidth.text) ?? 0;
          final h = double.tryParse(_carpetHeight.text) ?? 0;
          costLabel = '$qty sqft total (${w}m x ${h}m) x ${Formatters.currency(double.tryParse(_costPerSqft.text) ?? 0)}/sqft';
        }
        break;
      case 'qaleen':
        costLabel = '$qty pieces x ${Formatters.currency(double.tryParse(_costPerPiece.text) ?? 0)}/piece';
        break;
      case 'meter':
        costLabel = '${double.tryParse(_meterLength.text) ?? 0}m x ${Formatters.currency(double.tryParse(_costPerMeter.text) ?? 0)}/m';
        break;
      default:
        costLabel = '';
    }

    final qtyLabel = _productType == 'carpet' ? 'Total stock: $qty sqft' : 'Quantity: $qty';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(qtyLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 2),
              Text(costLabel, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ),
        Text(
          'Cost: ${Formatters.currency(totalCost)}',
          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14),
        ),
      ],
    );
  }
}
