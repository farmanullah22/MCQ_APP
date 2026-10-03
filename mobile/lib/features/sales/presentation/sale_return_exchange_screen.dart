import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../products/models/product.dart';
import '../../products/providers/product_providers.dart';
import '../models/sale.dart';
import '../providers/sale_providers.dart';

enum AdjustmentMode { returnOnly, exchange }

/// One line of the "going back" side of the adjustment.
class _ReturnLine {
  _ReturnLine({required this.productId, required this.productName, required this.maxQty})
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

/// One line of the "going out" side of an exchange.
class _ExchangeLine {
  _ExchangeLine({required this.productId, required this.productName, required this.maxQty})
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

/// Handles both customer-after-service flows on an existing invoice:
///  - Return  : products come back, stock goes back on the shelf, refund optional.
///  - Exchange: products come back AND replacements go out, difference settled.
class SaleReturnExchangeScreen extends ConsumerStatefulWidget {
  const SaleReturnExchangeScreen({
    super.key,
    required this.sale,
    required this.mode,
  });

  final Sale sale;
  final AdjustmentMode mode;

  @override
  ConsumerState<SaleReturnExchangeScreen> createState() => _SaleReturnExchangeScreenState();
}

class _SaleReturnExchangeScreenState extends ConsumerState<SaleReturnExchangeScreen> {
  final _reasonController = TextEditingController();
  final _noteController = TextEditingController();
  final _settlementController = TextEditingController();

  final _returns = <_ReturnLine>[];
  final _outgoing = <_ExchangeLine>[];

  String _settlementDirection = 'refund';
  String _settlementMethod = 'cash';

  bool get _isExchange => widget.mode == AdjustmentMode.exchange;

  @override
  void dispose() {
    _reasonController.dispose();
    _noteController.dispose();
    _settlementController.dispose();
    super.dispose();
  }

  // --- Money preview ---------------------------------------------------------

  /// Value of everything coming back, plus whatever was already refunded or
  /// replaced on this invoice, so the manager sees the true entitlement.
  double get _totalReturnValue =>
      _returns.fold<double>(0, (a, r) => a + r.total) +
      widget.sale.returnTotal -
      widget.sale.exchangeTotal +
      widget.sale.refundTotal;

  double get _totalOutgoingValue =>
      _outgoing.fold<double>(0, (a, e) => a + e.total) + widget.sale.exchangeTotal;

  /// What the customer owes after the goods go back and replacements go out.
  double get _projectedNetTotal {
    final current = widget.sale.hasAdjustments
        ? widget.sale.netTotal
        : widget.sale.totalAmount;
    final value = current - _returns.fold<double>(0, (a, r) => a + r.total) +
        _outgoing.fold<double>(0, (a, e) => a + e.total);
    return value < 0 ? 0 : value;
  }

  /// Positive = customer hands over money, negative = shop hands money back.
  double get _difference => _totalOutgoingValue - _totalReturnValue;

  /// Max refund the backend will accept for this adjustment.
  double get _maxRefund {
    final remaining = _totalReturnValue - widget.sale.refundTotal;
    return remaining > 0 ? remaining : 0;
  }

  double get _maxCollectable {
    final projectedDue = _projectedNetTotal - (widget.sale.paidAmount - widget.sale.refundTotal);
    return projectedDue > 0 ? projectedDue : 0;
  }

  double _settlementAmount() =>
      double.tryParse(_settlementController.text.trim()) ?? 0;

  bool get _settlementTooLarge {
    final amount = _settlementAmount();
    if (amount <= 0) return false;
    return _settlementDirection == 'refund' ? amount > _maxRefund : amount > _maxCollectable;
  }

  bool get _canSubmit {
    if (_returns.isEmpty) return false;
    if (_isExchange && _outgoing.isEmpty) return false;
    if (_settlementTooLarge) return false;
    if (_settlementAmount() > 0 && !_isExchange) {
      // A plain return's settlement is always money going back to the customer.
      return _settlementDirection == 'refund';
    }
    return true;
  }

  // --- Line management -------------------------------------------------------

  void _addReturn(SaleItem item) {
    final remaining = widget.sale.returnableQuantity(item.productId);
    if (remaining <= 0) return;
    final existing = _returns.where((r) => r.productId == item.productId).firstOrNull;
    if (existing != null) {
      if (existing.quantity >= remaining) return;
      setState(() => existing.quantity++);
      return;
    }
    setState(() => _returns.add(_ReturnLine(
          productId: item.productId,
          productName: item.productName,
          maxQty: remaining,
        )..unitPrice = widget.sale.billedUnitPrice(item.productId)));
  }

  void _addOutgoing(Product product) {
    if (product.quantity <= 0) return;
    final existing = _outgoing.where((e) => e.productId == product.id).firstOrNull;
    if (existing != null) {
      if (existing.quantity >= product.quantity) return;
      setState(() => existing.quantity++);
      return;
    }
    setState(() => _outgoing.add(_ExchangeLine(
          productId: product.id,
          productName: product.name,
          maxQty: product.quantity,
        )..unitPrice = product.sellingPrice));
  }

  // --- Submit ----------------------------------------------------------------

  Map<String, dynamic>? _buildSettlement() {
    final amount = _settlementAmount();
    if (amount <= 0) return null;
    return {
      'direction': _settlementDirection,
      'amount': amount,
      'method': _settlementMethod,
    };
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final notifier = ref.read(saleMutationControllerProvider.notifier);
    final incoming = _returns.map((r) => r.toJson()).toList();
    final settlement = _buildSettlement();

    final Sale? updated;
    if (_isExchange) {
      updated = await notifier.exchangeItems(
        widget.sale.id,
        incoming: incoming,
        outgoing: _outgoing.map((e) => e.toJson()).toList(),
        reason: _reasonController.text.trim(),
        note: _noteController.text.trim(),
        settlement: settlement,
      );
    } else {
      updated = await notifier.returnItems(
        widget.sale.id,
        items: incoming,
        reason: _reasonController.text.trim(),
        settlement: settlement,
      );
    }

    if (!mounted) return;
    if (updated == null) {
      final error = ref.read(saleMutationControllerProvider).error ?? 'Something went wrong.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendly(error)), backgroundColor: AppColors.danger));
      return;
    }
    Navigator.of(context).pop(updated);
  }

  /// Strips the raw exception wrapper so the manager sees the business message.
  String _friendly(String raw) => raw
      .replaceFirst(RegExp(r'^(Exception|BadRequestException|ApiException):\s*'), '')
      .replaceAll('ApiException: ', '');

  // --- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loading =
        ref.watch(saleMutationControllerProvider.select((s) => s.loading));
    final products = ref.watch(productListControllerProvider).data.value?.products ?? const [];
    final stockById = {for (final p in products) p.id: p};

    final returnable = widget.sale.items
        .map((i) => (item: i, left: widget.sale.returnableQuantity(i.productId)))
        .where((e) => e.left > 0)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isExchange ? 'Exchange Items' : 'Return Items'),
      ),
      bottomNavigationBar: _SubmitBar(
        loading: loading,
        enabled: _canSubmit,
        label: _isExchange ? 'Confirm Exchange' : 'Confirm Return',
        onPressed: _submit,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _HeaderCard(
            invoiceNo: widget.sale.invoiceNo,
            customerName: widget.sale.customerName,
            netTotal: widget.sale.hasAdjustments ? widget.sale.netTotal : widget.sale.totalAmount,
          ),
          const SizedBox(height: 16),

          // --- Products coming back ---
          _SectionHeader(
            icon: Icons.assignment_return_outlined,
            title: 'Product to return',
            subtitle: 'Returned stock is added back to inventory automatically.',
          ),
          const SizedBox(height: 8),
          if (returnable.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Nothing left to return',
                  subtitle: 'Every product on this invoice has already been returned.',
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final entry in returnable)
                    _ReturnRow(
                      name: entry.item.productName,
                      unitPrice: entry.item.unitPrice,
                      maxQty: entry.left,
                      selectedQty: _returns
                              .where((r) => r.productId == entry.item.productId)
                              .map((r) => r.quantity)
                          .firstOrNull ??
                          0,
                      onAdd: () => _addReturn(entry.item),
                      onChanged: (qty) => setState(() {
                        final line =
                            _returns.firstWhere((r) => r.productId == entry.item.productId);
                        line.quantity = qty;
                      }),
                    ),
                ],
              ),
            ),

          // --- Replacements ---
          if (_isExchange) ...[
            const SizedBox(height: 20),
            _SectionHeader(
              icon: Icons.swap_horiz_rounded,
              title: 'New product to give',
              subtitle: 'Replacement stock is deducted from inventory immediately.',
              color: AppColors.success,
            ),
            const SizedBox(height: 8),
            _OutgoingPicker(
              stockById: stockById,
              lines: _outgoing,
              onAdd: _addOutgoing,
              onChanged: (productId, qty, unitPrice) => setState(() {
                final line = _outgoing.firstWhere((e) => e.productId == productId);
                line.quantity = qty;
                line.unitPrice = unitPrice;
              }),
              onRemove: (productId) =>
                  setState(() => _outgoing.removeWhere((e) => e.productId == productId)),
            ),
          ],

          const SizedBox(height: 20),
          _SectionHeader(
            icon: Icons.notes_rounded,
            title: 'Reason',
            subtitle: 'Shown to the admin in the audit trail.',
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              labelText: 'Why is this being returned?',
              hintText: 'e.g. Damaged in transit, wrong size delivered',
              prefixIcon: Icon(Icons.edit_note_outlined),
            ),
          ),
          if (_isExchange) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Exchange note (optional)',
                prefixIcon: Icon(Icons.sync_alt_rounded),
              ),
            ),
          ],

          // --- Money settlement ---
          const SizedBox(height: 20),
          _SectionHeader(
            icon: Icons.payments_outlined,
            title: 'Payment adjustment',
            subtitle: _difference == 0
                ? 'Nothing to settle - both sides match.'
                : _difference > 0
                    ? 'Customer owes ${Formatters.currency(_difference)} extra.'
                    : 'Refund ${Formatters.currency(_difference.abs())} to the customer.',
            color: _difference > 0 ? AppColors.danger : AppColors.success,
          ),
          const SizedBox(height: 8),
          _SettlementCard(
            direction: _settlementDirection,
            method: _settlementMethod,
            controller: _settlementController,
            maxRefund: _maxRefund,
            maxCollectable: _maxCollectable,
            onDirectionChanged: (v) => setState(() {
              _settlementDirection = v;
              _settlementController.clear();
            }),
            onMethodChanged: (v) => setState(() => _settlementMethod = v),
          ),

          const SizedBox(height: 16),
          _SummaryCard(
            returnValue: _returns.fold<double>(0, (a, r) => a + r.total),
            outgoingValue: _outgoing.fold<double>(0, (a, e) => a + e.total),
            projectedNet: _projectedNetTotal,
            difference: _difference,
          ),

          const SizedBox(height: 12),
          Text(
            'Every return, exchange and payment is recorded in the audit log with your name.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// --- Pieces ------------------------------------------------------------------

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.invoiceNo,
    required this.customerName,
    required this.netTotal,
  });

  final String invoiceNo;
  final String customerName;
  final double netTotal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoiceNo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  customerName,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            Formatters.currency(netTotal),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReturnRow extends StatelessWidget {
  const _ReturnRow({
    required this.name,
    required this.unitPrice,
    required this.maxQty,
    required this.selectedQty,
    required this.onAdd,
    required this.onChanged,
  });

  final String name;
  final double unitPrice;
  final int maxQty;
  final int selectedQty;
  final VoidCallback onAdd;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final active = selectedQty > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${Formatters.currency(unitPrice)} each - $maxQty returnable',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (active)
            _Stepper(
              value: selectedQty,
              max: maxQty,
              onChanged: onChanged,
            )
          else
            IconButton.filledTonal(
              tooltip: 'Return this product',
              onPressed: onAdd,
              icon: const Icon(Icons.add),
            ),
        ],
      ),
    );
  }
}

class _OutgoingPicker extends StatelessWidget {
  const _OutgoingPicker({
    required this.stockById,
    required this.lines,
    required this.onAdd,
    required this.onChanged,
    required this.onRemove,
  });

  final Map<String, Product> stockById;
  final List<_ExchangeLine> lines;
  final void Function(Product) onAdd;
  final void Function(String, int, double) onChanged;
  final void Function(String) onRemove;

  @override
  Widget build(BuildContext context) {
    final inStock = stockById.values.where((p) => p.quantity > 0).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Add replacement product',
                prefixIcon: Icon(Icons.add_box_outlined),
              ),
              items: inStock
                  .map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.name} (${p.quantity} in stock)',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (id) {
                if (id != null) onAdd(stockById[id]!);
              },
            ),
          ),
        ),
        if (lines.isNotEmpty) ...[
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final line in lines) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(line.productName,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('${Formatters.currency(line.total)} total',
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        _Stepper(
                          value: line.quantity,
                          max: line.maxQty,
                          onChanged: (qty) => onChanged(line.productId, qty, line.unitPrice),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          onPressed: () => onRemove(line.productId),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextFormField(
                      initialValue: line.unitPrice.toStringAsFixed(0),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      decoration: const InputDecoration(
                        labelText: 'Selling price',
                        isDense: true,
                      ),
                      onChanged: (v) => onChanged(
                          line.productId, line.quantity, double.tryParse(v) ?? line.unitPrice),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.max, required this.onChanged});

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

class _SettlementCard extends StatelessWidget {
  const _SettlementCard({
    required this.direction,
    required this.method,
    required this.controller,
    required this.maxRefund,
    required this.maxCollectable,
    required this.onDirectionChanged,
    required this.onMethodChanged,
  });

  final String direction;
  final String method;
  final TextEditingController controller;
  final double maxRefund;
  final double maxCollectable;
  final ValueChanged<String> onDirectionChanged;
  final ValueChanged<String> onMethodChanged;

  @override
  Widget build(BuildContext context) {
    final cap = direction == 'refund' ? maxRefund : maxCollectable;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'refund',
                  label: Text('Refund'),
                  icon: Icon(Icons.call_received),
                ),
                ButtonSegment(
                  value: 'payment',
                  label: Text('Collect'),
                  icon: Icon(Icons.call_made),
                ),
              ],
              selected: {direction},
              onSelectionChanged: (s) => onDirectionChanged(s.first),
            ),
            const SizedBox(height: 14),
            // Rebuilds the helper/error line as the amount is typed.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final typed = double.tryParse(value.text.trim()) ?? 0;
                final over = direction == 'refund' ? typed > maxRefund : typed > maxCollectable;
                return TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: InputDecoration(
                    labelText: direction == 'refund' ? 'Refund amount' : 'Amount collected',
                    prefixText: 'Rs. ',
                    helperText: cap > 0
                        ? 'Maximum ${Formatters.currency(cap)}'
                        : 'Nothing to settle right now',
                    errorText:
                        over ? 'Exceeds the ${Formatters.currency(cap)} allowed' : null,
                    border: const OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: method,
              decoration: const InputDecoration(labelText: 'Paid / refunded via'),
              items: AppConstants.paymentMethods
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(
                            AppConstants.paymentMethodLabels[m] ?? Formatters.title(m)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) onMethodChanged(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.returnValue,
    required this.outgoingValue,
    required this.projectedNet,
    required this.difference,
  });

  final double returnValue;
  final double outgoingValue;
  final double projectedNet;
  final double difference;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _SummaryRow(label: 'Value returning', value: Formatters.currency(returnValue), color: AppColors.danger),
            if (outgoingValue > 0)
              _SummaryRow(label: 'Value going out', value: Formatters.currency(outgoingValue), color: AppColors.success),
            const Divider(height: 20),
            _SummaryRow(label: 'New invoice total', value: Formatters.currency(projectedNet), bold: true),
            if (difference != 0)
              _SummaryRow(
                label: difference > 0 ? 'Customer pays' : 'Shop refunds',
                value: Formatters.currency(difference.abs()),
                bold: true,
                color: difference > 0 ? AppColors.danger : AppColors.success,
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.bold = false, this.color});

  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: bold ? 15 : 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 16 : 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.loading,
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  final bool loading;
  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: enabled && !loading ? onPressed : null,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(loading ? 'Saving...' : label),
            style: FilledButton.styleFrom(
              backgroundColor: enabled ? AppColors.primary : AppColors.primaryLight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    );
  }
}