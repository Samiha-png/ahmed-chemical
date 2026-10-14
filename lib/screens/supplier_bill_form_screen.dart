import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../models/supplier_bill.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../providers/supplier_bill_provider.dart';
import '../providers/supplier_provider.dart';
import '../services/product_service.dart';
import '../services/supplier_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/form_field.dart';
import '../widgets/section_card.dart';

class SupplierBillFormScreen extends ConsumerStatefulWidget {
  const SupplierBillFormScreen({super.key});

  @override
  ConsumerState<SupplierBillFormScreen> createState() =>
      _SupplierBillFormScreenState();
}

class _SupplierBillFormScreenState
    extends ConsumerState<SupplierBillFormScreen> {
  Supplier? _supplier;
  String _currency = 'PKR';
  final _rateCtrl = TextEditingController(text: '1');
  final _billNumberCtrl = TextEditingController();
  final _freightCtrl = TextEditingController();
  final _otherCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _billDate = DateTime.now();
  DateTime? _dueDate;
  final List<_BillLineDraft> _lines = [];

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dueDate = DateTime.now().add(const Duration(days: 30));
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    _billNumberCtrl.dispose();
    _freightCtrl.dispose();
    _otherCtrl.dispose();
    _notesCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  num _parse(String s) => num.tryParse(s.trim()) ?? 0;

  void _addLine() => setState(() => _lines.add(_BillLineDraft.empty()));

  void _removeLine(int i) {
    setState(() {
      _lines[i].dispose();
      _lines.removeAt(i);
    });
  }

  Future<void> _save({bool andPost = false}) async {
    if (_supplier == null) {
      setState(() => _error = 'Select a supplier');
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
          .map((l) => BillLine(
                id: l.id,
                productId: l.productId,
                productName: l.productName,
                sku: l.sku,
                baseUnit: l.baseUnit,
                quantity: _parse(l.qtyCtrl.text),
                unitPrice: _parse(l.priceCtrl.text),
                discountPercent: _parse(l.discCtrl.text),
                taxPercent: _parse(l.taxCtrl.text),
              ))
          .toList();

      final bill = SupplierBill(
        id: '',
        number: '',
        supplierId: _supplier!.id,
        supplierName: _supplier!.name,
        supplierBillNumber: _billNumberCtrl.text.trim(),
        status: BillStatus.draft.name,
        currency: _currency,
        exchangeRate: _parse(_rateCtrl.text).clamp(0.0001, 999999),
        lines: lines,
        freight: _parse(_freightCtrl.text),
        otherCharges: _parse(_otherCtrl.text),
        notes: _notesCtrl.text.trim(),
        billDate: _billDate,
        dueDate: _dueDate,
        createdBy: uid,
      );

      final id = await ref
          .read(supplierBillServiceProvider)
          .createDraft(bill);

      if (andPost) {
        await ref.read(supplierBillServiceProvider).post(
              billId: id,
              userId: uid,
            );
      }
      if (mounted) context.go('/purchasing/bills');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(suppliersStreamProvider);
    final products = ref.watch(productsStreamProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.go('/purchasing/bills'),
                icon: const Icon(LucideIcons.arrowLeft, size: 18),
              ),
              const SizedBox(width: 8),
              Text('New Supplier Bill',
                  style: AppTextStyles.displayMedium),
            ],
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Supplier & Reference',
            child: Column(
              children: [
                Text('Supplier', style: AppTextStyles.label),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: suppliers.when(
                    loading: () => const SizedBox(
                        height: 42, child: LinearProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                    data: (list) {
                      final validIds = list.map((e) => e.id).toSet();
                      final value = validIds.contains(_supplier?.id)
                          ? _supplier!.id
                          : null;
                      return DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: value,
                          isExpanded: true,
                          dropdownColor: AppColors.elevated,
                          style: AppTextStyles.bodyMedium,
                          hint: Text('Select supplier',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textDim)),
                          items: list
                              .map((s) => DropdownMenuItem<String>(
                                    value: s.id,
                                    child: Text('${s.name} (${s.code})'),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            final s =
                                list.firstWhere((x) => x.id == v);
                            setState(() {
                              _supplier = s;
                              _currency = s.currency;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: AppFormField(
                        label: 'Supplier Bill #',
                        controller: _billNumberCtrl,
                        hint: 'Supplier invoice number',
                        icon: LucideIcons.hash,
                      ),
                    ),
                    const SizedBox(width: 12),
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
                    children: List.generate(_lines.length, (i) {
                      return _BillLineRow(
                        index: i + 1,
                        draft: _lines[i],
                        products: products,
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
                  hint: 'Optional notes',
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
                onPressed: () => context.go('/purchasing/bills'),
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

class _BillLineDraft {
  final String id;
  String productId;
  String productName;
  String sku;
  String baseUnit;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController discCtrl;
  final TextEditingController taxCtrl;

  _BillLineDraft({
    required this.id,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.baseUnit,
    required this.qtyCtrl,
    required this.priceCtrl,
    required this.discCtrl,
    required this.taxCtrl,
  });

  factory _BillLineDraft.empty() => _BillLineDraft(
        id: const Uuid().v4(),
        productId: '',
        productName: '',
        sku: '',
        baseUnit: '',
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

class _BillLineRow extends StatelessWidget {
  final int index;
  final _BillLineDraft draft;
  final AsyncValue<List<Product>> products;
  final String currency;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _BillLineRow({
    required this.index,
    required this.draft,
    required this.products,
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
              child: DropdownButton<String?>(
                value: draft.productId.isEmpty ? null : draft.productId,
                isExpanded: true,
                dropdownColor: AppColors.elevated,
                style: AppTextStyles.bodyMedium,
                hint: Text('Select product',
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textDim)),
                items: list
                    .map((p) => DropdownMenuItem<String>(
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
                  draft.priceCtrl.text = p.purchasePrice.toString();
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