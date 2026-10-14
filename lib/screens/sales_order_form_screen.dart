import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../models/sales_order.dart';
import '../providers/auth_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/product_provider.dart';
import '../providers/sales_order_provider.dart';
import '../providers/warehouse_provider.dart';
import '../services/customer_service.dart';
import '../services/product_service.dart';
import '../services/warehouse_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/form_field.dart';
import '../widgets/section_card.dart';

class SalesOrderFormScreen extends ConsumerStatefulWidget {
  final String? soId;
  const SalesOrderFormScreen({super.key, this.soId});

  @override
  ConsumerState<SalesOrderFormScreen> createState() =>
      _SalesOrderFormScreenState();
}

class _SalesOrderFormScreenState
    extends ConsumerState<SalesOrderFormScreen> {
  Customer? _customer;
  String _currency = 'PKR';
  final _rateCtrl = TextEditingController(text: '1');
  final _freightCtrl = TextEditingController();
  final _otherCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _expected;
  final List<_SOLineDraft> _lines = [];

  bool _loading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.soId != null) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final so =
          await ref.read(salesOrderServiceProvider).getById(widget.soId!);
      if (so == null) {
        setState(() => _error = 'Sales order not found');
      } else {
        _currency = so.currency;
        _rateCtrl.text = so.exchangeRate.toString();
        _freightCtrl.text = so.freight.toString();
        _otherCtrl.text = so.otherCharges.toString();
        _notesCtrl.text = so.notes;
        _expected = so.expectedDelivery;
        final customers =
            ref.read(customersStreamProvider).value ?? const <Customer>[];
        for (final c in customers) {
          if (c.id == so.customerId) _customer = c;
        }
        _lines.clear();
        for (final l in so.lines) {
          _lines.add(_SOLineDraft(
            id: l.id,
            productId: l.productId,
            productName: l.productName,
            sku: l.sku,
            baseUnit: l.baseUnit,
            warehouseId: l.warehouseId,
            warehouseName: l.warehouseName,
            qtyCtrl: TextEditingController(text: l.quantity.toString()),
            priceCtrl: TextEditingController(text: l.unitPrice.toString()),
            discCtrl:
                TextEditingController(text: l.discountPercent.toString()),
            taxCtrl: TextEditingController(text: l.taxPercent.toString()),
          ));
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    _freightCtrl.dispose();
    _otherCtrl.dispose();
    _notesCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  num _parse(String s) => num.tryParse(s.trim()) ?? 0;

  void _addLine() => setState(() => _lines.add(_SOLineDraft.empty()));

  void _removeLine(int i) {
    setState(() {
      _lines[i].dispose();
      _lines.removeAt(i);
    });
  }

  Future<void> _save() async {
    if (_customer == null) {
      setState(() => _error = 'Select a customer');
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _error = 'Add at least one line item');
      return;
    }
    for (final l in _lines) {
      if (l.productId.isEmpty) {
        setState(() => _error = 'Every line needs a product');
        return;
      }
      if (l.warehouseId.isEmpty) {
        setState(() => _error = 'Every line needs a warehouse');
        return;
      }
      if (_parse(l.qtyCtrl.text) <= 0) {
        setState(() => _error = 'Quantity must be greater than zero');
        return;
      }
    }
    setState(() { _saving = true; _error = null; });

    try {
      final uid = ref.read(authServiceProvider).currentUser?.uid ?? '';
      final lines = _lines
          .map((l) => SOLine(
                id: l.id,
                productId: l.productId,
                productName: l.productName,
                sku: l.sku,
                baseUnit: l.baseUnit,
                warehouseId: l.warehouseId,
                warehouseName: l.warehouseName,
                quantity: _parse(l.qtyCtrl.text),
                unitPrice: _parse(l.priceCtrl.text),
                discountPercent: _parse(l.discCtrl.text),
                taxPercent: _parse(l.taxCtrl.text),
              ))
          .toList();

      final so = SalesOrder(
        id: widget.soId ?? '',
        number: '',
        customerId: _customer!.id,
        customerName: _customer!.name,
        status: SOStatus.draft.name,
        currency: _currency,
        exchangeRate: _parse(_rateCtrl.text).clamp(0.0001, 999999),
        lines: lines,
        freight: _parse(_freightCtrl.text),
        otherCharges: _parse(_otherCtrl.text),
        notes: _notesCtrl.text.trim(),
        expectedDelivery: _expected,
        createdBy: uid,
      );

      if (widget.soId == null) {
        await ref.read(salesOrderServiceProvider).create(so);
      } else {
        await ref.read(salesOrderServiceProvider).update(widget.soId!, so);
      }
      if (mounted) context.go('/sales');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.soId != null;
    final customers = ref.watch(customersStreamProvider);
    final products = ref.watch(productsStreamProvider);
    final warehouses = ref.watch(warehousesStreamProvider);

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.go('/sales'),
                icon: const Icon(LucideIcons.arrowLeft, size: 18),
              ),
              const SizedBox(width: 8),
              Text(isEdit ? 'Edit Sales Order' : 'New Sales Order',
                  style: AppTextStyles.displayMedium),
            ],
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Customer & Currency',
            child: Column(
              children: [
                Text('Customer', style: AppTextStyles.label),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: customers.when(
                    loading: () => const SizedBox(
                        height: 42, child: LinearProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                    data: (list) => DropdownButtonHideUnderline(
                      child: DropdownButton<Customer?>(
                        value: _customer,
                        isExpanded: true,
                        dropdownColor: AppColors.elevated,
                        style: AppTextStyles.bodyMedium,
                        hint: Text('Select customer',
                            style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textDim)),
                        items: list
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text('${c.name} (${c.code})'),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _customer = v;
                          if (v != null) _currency = v.currency;
                        }),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Currency', style: AppTextStyles.label),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.elevated,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _currency,
                                isExpanded: true,
                                dropdownColor: AppColors.elevated,
                                style: AppTextStyles.bodyMedium,
                                items: const [
                                  'PKR', 'USD', 'EUR', 'GBP', 'AED', 'CNY'
                                ]
                                    .map((c) => DropdownMenuItem(
                                        value: c, child: Text(c)))
                                    .toList(),
                                onChanged: (v) => setState(
                                    () => _currency = v ?? 'PKR'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppFormField(
                        label: 'Exchange Rate to PKR',
                        controller: _rateCtrl,
                        hint: '1.0',
                        keyboardType: TextInputType.number,
                        icon: LucideIcons.refreshCw,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Line Items',
            trailing: TextButton.icon(
              onPressed: _addLine,
              icon: const Icon(LucideIcons.plus, size: 14),
              label: const Text('Add Line'),
            ),
            child: _lines.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No line items. Click "Add Line" to start.',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  )
                : Column(
                    children:
                        List.generate(_lines.length, (i) {
                      final l = _lines[i];
                      return _SOLineRow(
                        index: i + 1,
                        draft: l,
                        products: products,
                        warehouses: warehouses,
                        currency: _currency,
                        onRemove: () => _removeLine(i),
                        onChanged: () => setState(() {}),
                      );
                    }),
                  ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Charges & Notes',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppFormField(
                        label: 'Freight',
                        controller: _freightCtrl,
                        hint: '0.00',
                        keyboardType: TextInputType.number,
                        icon: LucideIcons.truck,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppFormField(
                        label: 'Other Charges',
                        controller: _otherCtrl,
                        hint: '0.00',
                        keyboardType: TextInputType.number,
                        icon: LucideIcons.receipt,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Expected Delivery',
                              style: AppTextStyles.label),
                          const SizedBox(height: 6),
                          Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.elevated,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: InkWell(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      _expected ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 3650)),
                                );
                                if (d != null) {
                                  setState(() => _expected = d);
                                }
                              },
                              child: Row(
                                children: [
                                  const Icon(LucideIcons.calendar,
                                      size: 15,
                                      color: AppColors.textDim),
                                  const SizedBox(width: 8),
                                  Text(
                                    _expected == null
                                        ? 'Not set'
                                        : '${_expected!.year}-${_expected!.month.toString().padLeft(2, '0')}-${_expected!.day.toString().padLeft(2, '0')}',
                                    style: AppTextStyles.bodyMedium
                                        .copyWith(
                                      color: _expected == null
                                          ? AppColors.textDim
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppFormField(
                  label: 'Notes',
                  controller: _notesCtrl,
                  hint: 'Any notes for the customer',
                  maxLines: 3,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Totals',
            child: _SOTotalsPreview(
              lines: _lines,
              currency: _currency,
              freight: _parse(_freightCtrl.text),
              other: _parse(_otherCtrl.text),
              rate: _parse(_rateCtrl.text),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                const Icon(LucideIcons.alertCircle,
                    size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.error)),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => context.go('/sales'),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Icon(LucideIcons.save, size: 16),
                label: Text(_saving
                    ? 'Saving...'
                    : (isEdit ? 'Update SO' : 'Create SO')),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── Line Draft ───
class _SOLineDraft {
  final String id;
  String productId;
  String productName;
  String sku;
  String baseUnit;
  String warehouseId;
  String warehouseName;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController discCtrl;
  final TextEditingController taxCtrl;

  _SOLineDraft({
    required this.id,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.baseUnit,
    required this.warehouseId,
    required this.warehouseName,
    required this.qtyCtrl,
    required this.priceCtrl,
    required this.discCtrl,
    required this.taxCtrl,
  });

  factory _SOLineDraft.empty() => _SOLineDraft(
        id: const Uuid().v4(),
        productId: '',
        productName: '',
        sku: '',
        baseUnit: '',
        warehouseId: '',
        warehouseName: '',
        qtyCtrl: TextEditingController(text: '1'),
        priceCtrl: TextEditingController(text: '0'),
        discCtrl: TextEditingController(text: '0'),
        taxCtrl: TextEditingController(text: '0'),
      );

  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
    discCtrl.dispose();
    taxCtrl.dispose();
  }

  num get qty => num.tryParse(qtyCtrl.text) ?? 0;
  num get price => num.tryParse(priceCtrl.text) ?? 0;
  num get disc => num.tryParse(discCtrl.text) ?? 0;
  num get tax => num.tryParse(taxCtrl.text) ?? 0;

  num get lineTotal {
    final gross = qty * price;
    final sub = gross - (gross * disc / 100);
    return sub + (sub * tax / 100);
  }
}

// ─── Line Row ───
class _SOLineRow extends StatelessWidget {
  final int index;
  final _SOLineDraft draft;
  final AsyncValue<List<Product>> products;
  final AsyncValue<List<Warehouse>> warehouses;
  final String currency;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _SOLineRow({
    required this.index,
    required this.draft,
    required this.products,
    required this.warehouses,
    required this.currency,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('#$index', style: AppTextStyles.caption),
              const Spacer(),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(LucideIcons.trash2, size: 14),
                color: AppColors.error,
                tooltip: 'Remove line',
              ),
            ],
          ),
          const SizedBox(height: 8),
          products.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
            data: (list) => DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: draft.productId.isEmpty ? null : draft.productId,
                isExpanded: true,
                dropdownColor: AppColors.elevated,
                style: AppTextStyles.bodyMedium,
                hint: Text('Select product',
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textDim)),
                items: list
                    .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text('${p.name} (${p.sku})'),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  final p = list.firstWhere((x) => x.id == v);
                  draft.productId = p.id;
                  draft.productName = p.name;
                  draft.sku = p.sku;
                  draft.baseUnit = p.baseUnit;
                  draft.priceCtrl.text = p.sellingPrice.toString();
                  onChanged();
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          warehouses.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
            data: (list) => DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value:
                    draft.warehouseId.isEmpty ? null : draft.warehouseId,
                isExpanded: true,
                dropdownColor: AppColors.elevated,
                style: AppTextStyles.bodyMedium,
                hint: Text('Select warehouse',
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textDim)),
                items: list
                    .map((w) => DropdownMenuItem(
                          value: w.id,
                          child: Text(w.name),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  final w = list.firstWhere((x) => x.id == v);
                  draft.warehouseId = w.id;
                  draft.warehouseName = w.name;
                  onChanged();
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _smallField('Qty', draft.qtyCtrl, onChanged)),
              const SizedBox(width: 8),
              Expanded(
                  child:
                      _smallField('Unit Price', draft.priceCtrl, onChanged)),
              const SizedBox(width: 8),
              Expanded(
                  child: _smallField('Disc %', draft.discCtrl, onChanged)),
              const SizedBox(width: 8),
              Expanded(
                  child: _smallField('Tax %', draft.taxCtrl, onChanged)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Line Total: $currency ${draft.lineTotal.toStringAsFixed(2)}',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallField(
      String label, TextEditingController ctrl, VoidCallback onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          onChanged: (_) => onChanged(),
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 10),
            fillColor: AppColors.card,
          ),
        ),
      ],
    );
  }
}

// ─── Totals Preview ───
class _SOTotalsPreview extends StatelessWidget {
  final List<_SOLineDraft> lines;
  final String currency;
  final num freight;
  final num other;
  final num rate;

  const _SOTotalsPreview({
    required this.lines,
    required this.currency,
    required this.freight,
    required this.other,
    required this.rate,
  });

  @override
  Widget build(BuildContext context) {
    final sub = lines.fold<num>(0, (a, l) => a + l.lineTotal);
    final grand = sub + freight + other;
    final base = grand * (rate <= 0 ? 1 : rate);

    return Column(
      children: [
        _row('Subtotal', '$currency ${sub.toStringAsFixed(2)}'),
        _row('Freight', '$currency ${freight.toStringAsFixed(2)}'),
        _row('Other Charges', '$currency ${other.toStringAsFixed(2)}'),
        const Divider(color: AppColors.border, height: 20),
        _row('Grand Total', '$currency ${grand.toStringAsFixed(2)}',
            bold: true),
        if (currency != 'PKR')
          _row('Base (PKR)', base.toStringAsFixed(2)),
      ],
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: bold
                  ? AppTextStyles.bodyLarge
                      .copyWith(fontWeight: FontWeight.w700)
                  : AppTextStyles.bodyMedium),
          Text(value,
              style: bold
                  ? AppTextStyles.bodyLarge
                      .copyWith(fontWeight: FontWeight.w700)
                  : AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}