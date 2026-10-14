import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/supplier_bill.dart';
import '../models/supplier_payment.dart';
import '../providers/auth_provider.dart';
import '../providers/supplier_bill_provider.dart';
import '../providers/supplier_payment_provider.dart';
import '../providers/supplier_provider.dart';
import '../services/supplier_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/form_field.dart';
import '../widgets/section_card.dart';

class SupplierPaymentFormScreen extends ConsumerStatefulWidget {
  final String? billId;
  const SupplierPaymentFormScreen({super.key, this.billId});

  @override
  ConsumerState<SupplierPaymentFormScreen> createState() =>
      _SupplierPaymentFormScreenState();
}

class _SupplierPaymentFormScreenState
    extends ConsumerState<SupplierPaymentFormScreen> {
  Supplier? _supplier;
  String _currency = 'PKR';
  final _rateCtrl = TextEditingController(text: '1');
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _method = 'cash';
  DateTime _paymentDate = DateTime.now();

  // Selected bills + their allocation amounts
  final Map<String, _AllocationDraft> _allocations = {};

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Note: if billId was passed, we can pre-select after suppliers load
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    for (final a in _allocations.values) {
      a.dispose();
    }
    super.dispose();
  }

  num _parse(String s) => num.tryParse(s.trim()) ?? 0;

  num get _totalAllocated =>
      _allocations.values.fold<num>(0, (a, d) => a + _parse(d.amountCtrl.text));

  Future<void> _save() async {
    if (_supplier == null) {
      setState(() => _error = 'Select a supplier');
      return;
    }
    final amount = _parse(_amountCtrl.text);
    if (amount <= 0) {
      setState(() => _error = 'Amount must be greater than zero');
      return;
    }
    final alloc = _totalAllocated;
    if (alloc > amount + 0.01) {
      setState(() => _error =
          'Total allocated (${alloc.toStringAsFixed(2)}) exceeds payment amount ($amount)');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final uid = ref.read(authServiceProvider).currentUser?.uid ?? '';
      final allocations = _allocations.entries
          .where((e) => _parse(e.value.amountCtrl.text) > 0)
          .map((e) => PaymentAllocation(
                billId: e.key,
                billNumber: e.value.billNumber,
                amount: _parse(e.value.amountCtrl.text),
              ))
          .toList();

      final payment = SupplierPayment(
        id: '',
        number: '',
        supplierId: _supplier!.id,
        supplierName: _supplier!.name,
        status: PaymentStatus.posted.name,
        currency: _currency,
        exchangeRate: _parse(_rateCtrl.text).clamp(0.0001, 999999),
        amount: amount,
        method: _method,
        reference: _refCtrl.text.trim(),
        allocations: allocations,
        notes: _notesCtrl.text.trim(),
        paymentDate: _paymentDate,
        createdBy: uid,
      );

      await ref
          .read(supplierPaymentServiceProvider)
          .create(payment: payment);

      if (mounted) context.go('/purchasing/payments');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleBill(SupplierBill bill) {
    setState(() {
      if (_allocations.containsKey(bill.id)) {
        _allocations[bill.id]!.dispose();
        _allocations.remove(bill.id);
      } else {
        _allocations[bill.id] = _AllocationDraft(
          billId: bill.id,
          billNumber: bill.number,
          outstanding: bill.outstanding,
          amountCtrl: TextEditingController(
              text: bill.outstanding.toStringAsFixed(2)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(suppliersStreamProvider);
    final bills = ref.watch(supplierBillsStreamProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.go('/purchasing/payments'),
                icon: const Icon(LucideIcons.arrowLeft, size: 18),
              ),
              const SizedBox(width: 8),
              Text('New Supplier Payment',
                  style: AppTextStyles.displayMedium),
            ],
          ),
          const SizedBox(height: 20),

          // Supplier + amount
          SectionCard(
            title: 'Payment Details',
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
                            final s = list.firstWhere((x) => x.id == v);
                            setState(() {
                              _supplier = s;
                              _currency = s.currency;
                              _allocations.clear();
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
                        label: 'Amount',
                        controller: _amountCtrl,
                        hint: '0.00',
                        keyboardType: TextInputType.number,
                        icon: LucideIcons.dollarSign,
                        required: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Method', style: AppTextStyles.label),
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
                                value: _method,
                                isExpanded: true,
                                dropdownColor: AppColors.elevated,
                                style: AppTextStyles.bodyMedium,
                                items: paymentMethods
                                    .map((m) => DropdownMenuItem(
                                        value: m,
                                        child: Text(_methodLabel(m))))
                                    .toList(),
                                onChanged: (v) => setState(
                                    () => _method = v ?? 'cash'),
                              ),
                            ),
                          ),
                        ],
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
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: AppFormField(
                        label: 'Exchange Rate to PKR',
                        controller: _rateCtrl,
                        hint: '1.0',
                        keyboardType: TextInputType.number,
                        icon: LucideIcons.refreshCw,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppFormField(
                        label: 'Reference (cheque no, txn id)',
                        controller: _refCtrl,
                        hint: 'Optional',
                        icon: LucideIcons.hash,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppFormField(
                  label: 'Notes',
                  controller: _notesCtrl,
                  hint: 'Optional notes',
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Bill allocations
          SectionCard(
            title: 'Allocate to Bills',
            subtitle:
                'Select bills to apply this payment. Leave blank to keep the payment unallocated.',
            trailing: Text(
              'Allocated: $_currency ${_totalAllocated.toStringAsFixed(2)}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: _supplier == null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Select a supplier to see their unpaid bills.',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  )
                : bills.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      ),
                    ),
                    error: (e, _) => Text('Error: $e'),
                    data: (list) {
                      final supplierBills = list
                          .where((b) =>
                              b.supplierId == _supplier!.id &&
                              b.outstanding > 0.01 &&
                              b.statusEnum != BillStatus.cancelled &&
                              b.statusEnum != BillStatus.draft)
                          .toList();
                      if (supplierBills.isEmpty) {
                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No outstanding bills for this supplier.',
                              style: AppTextStyles.bodySmall,
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: supplierBills.map((b) {
                          final selected =
                              _allocations.containsKey(b.id);
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 6),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primarySoft
                                    : AppColors.elevated,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                          .withValues(alpha: 0.4)
                                      : AppColors.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: selected,
                                    onChanged: (_) => _toggleBill(b),
                                    activeColor: AppColors.primary,
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          b.number,
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                  fontWeight:
                                                      FontWeight.w600),
                                        ),
                                        Text(
                                          'Due: ${b.currency} ${b.outstanding.toStringAsFixed(2)}',
                                          style: AppTextStyles.caption,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (selected)
                                    SizedBox(
                                      width: 120,
                                      child: TextField(
                                        controller:
                                            _allocations[b.id]!.amountCtrl,
                                        keyboardType:
                                            TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                        style: AppTextStyles.bodyMedium,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 10,
                                                  vertical: 10),
                                          fillColor: AppColors.card,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
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
                onPressed: () => context.go('/purchasing/payments'),
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
                    : const Icon(LucideIcons.check, size: 16),
                label: Text(_saving ? 'Saving...' : 'Save Payment'),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _methodLabel(String m) {
    switch (m) {
      case 'cash':
        return 'Cash';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'cheque':
        return 'Cheque';
      case 'online':
        return 'Online';
      default:
        return m;
    }
  }
}

class _AllocationDraft {
  final String billId;
  final String billNumber;
  final num outstanding;
  final TextEditingController amountCtrl;

  _AllocationDraft({
    required this.billId,
    required this.billNumber,
    required this.outstanding,
    required this.amountCtrl,
  });

  void dispose() {
    amountCtrl.dispose();
  }
}