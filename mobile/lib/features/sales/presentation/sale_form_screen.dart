import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_views.dart';
import '../../auth/providers/auth_providers.dart';
import '../../customers/models/customer.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../products/models/product.dart';
import '../../products/providers/product_providers.dart';
import '../providers/sale_providers.dart';

class SaleFormScreen extends ConsumerStatefulWidget {
  const SaleFormScreen({super.key});

  @override
  ConsumerState<SaleFormScreen> createState() => _SaleFormScreenState();
}

class _CartItem {
  _CartItem(this.product, this.quantity);

  final Product product;
  int quantity;

  double get lineTotal => product.sellingPrice * quantity;
}

class _SaleFormScreenState extends ConsumerState<SaleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _discountController = TextEditingController();
  final _notesController = TextEditingController();
  final _cart = <_CartItem>[];
  String? _paymentMethod = 'cash';
  String? _shopId;

  Product? _selectedProduct;

  List<Customer> _customers = [];
  String? _selectedCustomerId;
  String _customerSearch = '';
  bool _showCustomerSearch = false;

  List<Customer> get _filteredCustomers {
    final query = _customerSearch.trim().toLowerCase();
    if (query.isEmpty) return _customers;
    return _customers
        .where((c) => c.name.toLowerCase().contains(query) || c.phone.toLowerCase().contains(query))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _shopId = ref.read(dashboardControllerProvider).selectedShopId;
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      final page = await ref.read(customerRepositoryProvider).getCustomers(limit: 200);
      if (!mounted) return;
      setState(() => _customers = page.customers);
    } catch (_) {
      _customers = [];
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(saleMutationControllerProvider.select((s) => s.loading));
    final products = ref.watch(productListControllerProvider).data.value?.products ?? const [];
    final available = products.where((p) => p.quantity > 0).toList();
    final dashboard = ref.watch(dashboardControllerProvider);
    final canSelectShop = (ref.watch(currentUserProvider)?.isAdmin ?? false) && dashboard.shops.length > 1;

    final subtotal = _cart.fold<double>(0, (a, c) => a + c.lineTotal);
    final discount = double.tryParse(_discountController.text.trim()) ?? 0;
    final total = (subtotal - discount).clamp(0, double.infinity);

    return Scaffold(
      appBar: AppBar(title: const Text('New Sale')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Customer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _selectedCustomerId,
                decoration: const InputDecoration(
                  labelText: 'Select Customer',
                  prefixIcon: Icon(Icons.person_search_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Walk-in Customer')),
                  ..._customers.map((c) => DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text('${c.name}${c.phone.isNotEmpty ? ' - ${c.phone}' : ''}',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (v) {
                  setState(() {
                    _selectedCustomerId = v;
                    _showCustomerSearch = false;
                    _customerSearch = '';
                    if (v == null) {
                      _customerNameController.clear();
                      _customerPhoneController.clear();
                    } else {
                      final customer = _customers.where((c) => c.id == v).firstOrNull;
                      if (customer != null) {
                        _customerNameController.text = customer.name;
                        _customerPhoneController.text = customer.phone;
                      }
                    }
                  });
                },
              ),
              if (_showCustomerSearch) ...[
                const SizedBox(height: 12),
                TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _customerSearch = v),
                  decoration: InputDecoration(
                    hintText: 'Search customers...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _customerSearch.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _customerSearch = ''),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                ..._filteredCustomers.map((c) => Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.primary.withValues(alpha: 0.05),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.person_outline),
                        title: Text(c.name),
                        subtitle: c.phone.isNotEmpty ? Text(c.phone) : null,
                        onTap: () {
                          setState(() {
                            _selectedCustomerId = c.id;
                            _customerNameController.text = c.name;
                            _customerPhoneController.text = c.phone;
                            _showCustomerSearch = false;
                            _customerSearch = '';
                          });
                        },
                      ),
                    )),
              ] else if (_customers.isNotEmpty) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showCustomerSearch = true),
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Search customers'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (_selectedCustomerId == null) ...[
                TextFormField(
                  controller: _customerNameController,
                  decoration: const InputDecoration(labelText: 'Customer Name', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _customerPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Customer Phone', prefixIcon: Icon(Icons.phone_outlined)),
                ),
                const SizedBox(height: 14),
              ],
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                decoration: const InputDecoration(labelText: 'Payment Method', prefixIcon: Icon(Icons.payments_outlined)),
                items: AppConstants.paymentMethods
                    .map((m) => DropdownMenuItem(value: m, child: Text(AppConstants.paymentMethodLabels[m] ?? Formatters.title(m))))
                    .toList(),
                onChanged: (v) => setState(() => _paymentMethod = v),
              ),
              if (canSelectShop) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _shopId,
                  decoration: const InputDecoration(labelText: 'Shop', prefixIcon: Icon(Icons.storefront_outlined)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All shops / main')),
                    ...dashboard.shops.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                  ],
                  onChanged: (v) => setState(() => _shopId = v),
                ),
              ],
              const SizedBox(height: 24),
              const Text('Add Items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Product', prefixIcon: Icon(Icons.carpenter_outlined)),
                      items: available
                          .map((p) => DropdownMenuItem(
                                value: p.id,
                                child: Text('${p.name} (${p.quantity} in stock)',
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedProduct = available.where((p) => p.id == v).firstOrNull;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    tooltip: 'Add to cart',
                    onPressed: _selectedProduct == null
                        ? null
                        : () => _addToCart(_selectedProduct!),
                    icon: const Icon(Icons.add_shopping_cart),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_cart.isEmpty)
                const EmptyState(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Cart is empty',
                  subtitle: 'Select a product above to start the sale.',
                )
              else
                Card(
                  child: Column(
                    children: [
                      ..._cart.indexed.map((e) => _CartRow(
                            item: e.$2,
                            onIncrease: () => setState(() {
                              if (e.$2.quantity < e.$2.product.quantity) e.$2.quantity++;
                            }),
                            onDecrease: () => setState(() {
                              if (e.$2.quantity > 1) {
                                e.$2.quantity--;
                              } else {
                                _cart.removeAt(e.$1);
                              }
                            }),
                            onRemove: () => setState(() => _cart.removeAt(e.$1)),
                          )),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _discountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Discount (Rs.)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _SummaryRow(label: 'Subtotal', value: Formatters.currency(subtotal)),
                    _SummaryRow(label: 'Discount', value: '- ${Formatters.currency(discount)}'),
                    const Divider(),
                    _SummaryRow(
                      label: 'Total',
                      value: Formatters.currency(total),
                      bold: true,
                      valueColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              LoadingButton(
                loading: loading,
                label: 'Complete Sale',
                icon: Icons.point_of_sale,
                onPressed: _cart.isEmpty ? null : _submit,
              ),            ],
          ),
        ),
      ),
    );
  }

  void _addToCart(Product product) {
    setState(() {
      final existing = _cart.where((c) => c.product.id == product.id).firstOrNull;
      if (existing != null) {
        if (existing.quantity < product.quantity) existing.quantity++;
      } else {
        _cart.add(_CartItem(product, 1));
      }
      _selectedProduct = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final sale = await ref.read(saleMutationControllerProvider.notifier).create(
          items: _cart
              .map((c) => {
                    'productId': c.product.id,
                    'quantity': c.quantity,
                    'unitPrice': c.product.sellingPrice,
                  })
              .toList(),
          customerName: _customerNameController.text.trim().isEmpty
              ? 'Walk-in Customer'
              : _customerNameController.text.trim(),
          customerPhone: _customerPhoneController.text.trim(),
          discount: double.tryParse(_discountController.text.trim()) ?? 0,
          paymentMethod: _paymentMethod ?? 'cash',
          notes: _notesController.text.trim(),
          shopId: _shopId,
        );
    if (!mounted) return;
    if (sale != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sale ${sale.invoiceNo} completed')),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(saleMutationControllerProvider).error ?? 'Failed to create sale')),
      );
    }
  }
}

class _CartRow extends StatelessWidget {
  const _CartRow({
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  final _CartItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(Formatters.currency(item.product.sellingPrice), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            onPressed: onDecrease,
          ),
          Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 20),
            onPressed: onIncrease,
          ),
          SizedBox(
            width: 90,
            child: Text(
              Formatters.currency(item.lineTotal),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: bold ? 15 : 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 16 : 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
