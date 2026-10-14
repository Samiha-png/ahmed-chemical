import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../models/sales_invoice.dart';
import '../providers/auth_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/product_provider.dart';
import '../providers/sales_invoice_provider.dart';
import '../providers/sales_order_provider.dart';
import '../providers/warehouse_provider.dart';
import '../services/customer_service.dart';
import '../services/inventory_service.dart';
import '../services/product_service.dart';
import '../services/warehouse_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/form_field.dart';
import '../widgets/section_card.dart';

class SalesInvoiceFormScreen extends ConsumerStatefulWidget {
  final String? invoiceId;
  final String? salesOrderId;
  const SalesInvoiceFormScreen({
    super.key,
    this.invoiceId,
    this.salesOrderId,
  });

  @override
  ConsumerState<SalesInvoiceFormScreen> createState() =>
      _SalesInvoiceFormScreenState();
}

class _SalesInvoiceFormScreenState
    extends ConsumerState<SalesInvoiceFormScreen> {
  Customer? _customer;
  String _currency = 'PKR';
  final _rateCtrl = TextEditingController(text: '1');
  final _freightCtrl = TextEditingController();
  final _otherCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _invoiceDate = DateTime.now();
  DateTime? _dueDate;
  final List<_InvLineDraft> _lines = [];

  bool _loading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dueDate = DateTime.now().add(const Duration(days: 30));
    if (widget.invoiceId != null) {
      _load();
    } else if (widget.salesOrderId != null) {
      _loadFromSO();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final inv = await ref
          .read(salesInvoiceServiceProvider)
          .getById(widget.invoiceId!);
      if (inv == null) {
        setState(() => _error = 'Invoice not found');
      } else {
        _currency = inv.currency;
        _rateCtrl.text = inv.exchangeRate.toString();
        _freightCtrl.text = inv.freight.toString();
        _otherCtrl.text = inv.otherCharges.toString();
        _notesCtrl.text = inv.notes;
        _invoiceDate = inv.invoiceDate;
        _dueDate = inv.dueDate;
        final customers =
            ref.read(customersStreamProvider).value ?? const <Customer>[];
        for (final c in customers) {
          if (c.id == inv.customerId) _customer = c;
        }
        _lines.clear();
        for (final l in inv.lines) {
          _lines.add(_InvLineDraft(
            id: l.id,
            productId: l.productId,
            productName: l.productName,
            sku: l.sku,
            baseUnit: l.baseUnit,
            warehouseId: l.warehouseId,
            warehouseName: l.warehouseName,
            unitCost: l.unitCost,
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

  Future<void> _loadFromSO() async {
    setState(() => _loading = true);
    try {
      final so = await ref
          .read(salesOrderServiceProvider)
          .getById(widget.salesOrderId!);
      if (so == null) {
        setState(() => _error = 'Sales order not found');
        return;
      }

      // Pre-fill header
      _currency = so.currency;
      _rateCtrl.text = so.exchangeRate.toString();
      _freightCtrl.text = so.freight.toString();
      _otherCtrl.text = so.otherCharges.toString();
      _notesCtrl.text = so.notes;

      // Pre-fill customer
      final customers =
          ref.read(customersStreamProvider).value ?? const <Customer>[];
      for (final c in customers) {
        if (c.id == so.customerId) _customer = c;
      }

      // Pre-fill lines (only uninvoiced quantity)
      _lines.clear();
      for (final l in so.lines) {
        final remaining = l.quantity - l.invoicedQuantity;
        if (remaining <= 0) continue;

        // Fetch unit cost from current stock balance
        num unitCost = 0;
        try {
          final bal = await ref
              .read(inventoryServiceProvider)
              .getBalance(l.productId, l.warehouseId);
          if (bal != null) unitCost = bal.avgCost;
        } catch (_) {}

        _lines.add(_InvLineDraft(
          id: const Uuid().v4(),
          productId: l.productId,
          productName: l.productName,
          sku: l.sku,
          baseUnit: l.baseUnit,
          warehouseId: l.warehouseId,
          warehouseName: l.warehouseName,
          unitCost: unitCost,
          qtyCtrl: TextEditingController(text: remaining.toString()),
          priceCtrl: TextEditingController(text: l.unitPrice.toString()),
          discCtrl:
              TextEditingController(text: l.discountPercent.toString()),
          taxCtrl: TextEditingController(text: l.taxPercent.toString()),
        ));
      }

      if (_lines.isEmpty) {
        setState(() =>
            _error = 'All lines in this sales order are already invoiced');
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

  void _addLine() => setState(() => _lines.add(_InvLineDraft.empty()));

  void _removeLine(int i) {
    setState(() {
      _lines[i].dispose();
      _lines.removeAt(i);
    });
  }

  Future<void> _save({bool andPost = false}) async {
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
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final uid = ref.read(authServiceProvider).currentUser?.uid ?? '';
      final lines = _lines
          .map((l) => InvLine(
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
                unitCost: l.unitCost,
              ))
          .toList();

      final inv = SalesInvoice(
        id: widget.invoiceId ?? '',
        number: '',
        salesOrderId: widget.salesOrderId,
        customerId: _customer!.id,
        customerName: _customer!.name,
        status: InvoiceStatus.draft.name,
        currency: _currency,
        exchangeRate: _parse(_rateCtrl.text).clamp(0.0001, 999999),
        lines: lines,
        freight: _parse(_freightCtrl.text),
        otherCharges: _parse(_otherCtrl.text),
        notes: _notesCtrl.text.trim(),
        invoiceDate: _invoiceDate,
        dueDate: _dueDate,
        createdBy: uid,
      );

      String id;
      if (widget.invoiceId == null) {
        id = await ref
            .read(salesInvoiceServiceProvider)
            .createDraft(inv);
      } else {
        throw Exception('Editing invoices is not supported');
      }

      if (andPost) {
        await ref.read(salesInvoiceServiceProvider).postInvoice(
              invoiceId: id,
              userId: uid,
            );
      }
      if (mounted) context.go('/invoices');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                onPressed: () => context.go('/invoices'),
                icon: const Icon(LucideIcons.arrowLeft, size: 18),
              ),
              const SizedBox(width: 8),
              Text('New Sales Invoice',
                  style: AppTextStyles.displayMedium),
            ],
          ),
          if (widget.salesOrderId != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.info,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Generated from Sales Order ${widget.salesOrderId}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                          Text('Currency',
                              style: AppTextStyles.label),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.elevated,
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: AppColors.border),
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
                    children: List.generate(_lines.length, (i) {
                      final l = _lines[i];
                      return _InvLineRow(
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
                onPressed: () => context.go('/invoices'),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _save(andPost: false),
                icon: const Icon(LucideIcons.save, size: 16),
                label: const Text('Save as Draft'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _saving ? null : () => _save(andPost: true),
                icon: _saving
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Icon(LucideIcons.check, size: 16),
                label: Text(_saving ? 'Saving...' : 'Save & Post'),
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
class _InvLineDraft {
  final String id;
  String productId;
  String productName;
  String sku;
  String baseUnit;
  String warehouseId;
  String warehouseName;
  num unitCost;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController discCtrl;
  final TextEditingController taxCtrl;

  _InvLineDraft({
    required this.id,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.baseUnit,
    required this.warehouseId,
    required this.warehouseName,
    required this.unitCost,
    required this.qtyCtrl,
    required this.priceCtrl,
    required this.discCtrl,
    required this.taxCtrl,
  });

  factory _InvLineDraft.empty() => _InvLineDraft(
        id: const Uuid().v4(),
        productId: '',
        productName: '',
        sku: '',
        baseUnit: '',
        warehouseId: '',
        warehouseName: '',
        unitCost: 0,
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
}

// ─── Line Row ───
class _InvLineRow extends StatelessWidget {
  final int index;
  final _InvLineDraft draft;
  final AsyncValue<List<Product>> products;
  final AsyncValue<List<Warehouse>> warehouses;
  final String currency;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _InvLineRow({
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
              ),
            ],
          ),
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
                  child: _smallField(
                      'Unit Price', draft.priceCtrl, onChanged)),
              const SizedBox(width: 8),
              Expanded(
                  child: _smallField('Disc %', draft.discCtrl, onChanged)),
              const SizedBox(width: 8),
              Expanded(
                  child: _smallField('Tax %', draft.taxCtrl, onChanged)),
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            fillColor: AppColors.card,
          ),
        ),
      ],
    );
  }
}