import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/supplier_bill.dart';
import '../providers/auth_provider.dart';
import '../providers/supplier_bill_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_dialog.dart';
import '../widgets/section_card.dart';

class SupplierBillDetailScreen extends ConsumerStatefulWidget {
  final String billId;
  const SupplierBillDetailScreen({super.key, required this.billId});

  @override
  ConsumerState<SupplierBillDetailScreen> createState() =>
      _SupplierBillDetailScreenState();
}

class _SupplierBillDetailScreenState
    extends ConsumerState<SupplierBillDetailScreen> {
  SupplierBill? _bill;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final bill =
          await ref.read(supplierBillServiceProvider).getById(widget.billId);
      setState(() {
        _bill = bill;
        _loading = false;
        if (bill == null) _error = 'Bill not found';
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _post() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Post this bill?',
      message:
          'Posted bills become liabilities. You can then record payments against them.',
      confirmLabel: 'Post Bill',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final uid = ref.read(authServiceProvider).currentUser?.uid ?? '';
      await ref.read(supplierBillServiceProvider).post(
            billId: widget.billId,
            userId: uid,
          );
      await _load();
      _snack('Bill posted');
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete this draft bill?',
      message: 'This cannot be undone.',
      danger: true,
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await ref
          .read(supplierBillServiceProvider)
          .deleteDraft(widget.billId);
      if (mounted) context.go('/purchasing/bills');
    } catch (e) {
      _snack('Error: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null || _bill == null) {
      return Center(
        child: Text(_error ?? 'Error', style: AppTextStyles.bodyMedium),
      );
    }
    final b = _bill!;
    final isDraft = b.statusEnum == BillStatus.draft;
    final canPay = b.statusEnum == BillStatus.posted ||
        b.statusEnum == BillStatus.partiallyPaid;

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.number, style: AppTextStyles.displayMedium),
                    const SizedBox(height: 4),
                    Text(b.supplierName,
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              if (isDraft) ...[
                ElevatedButton.icon(
                  onPressed: _busy ? null : _post,
                  icon: _busy
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Icon(LucideIcons.check, size: 16),
                  label: const Text('Post Bill'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _delete,
                  icon: const Icon(LucideIcons.trash2, size: 15),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ],
              if (canPay) ...[
                ElevatedButton.icon(
                  onPressed: () => context
                      .go('/purchasing/payments/new?bill=${b.id}'),
                  icon: const Icon(LucideIcons.dollarSign, size: 16),
                  label: const Text('Record Payment'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Details',
            child: _grid([
              _row('Status', billStatusLabel(b.statusEnum)),
              _row('Supplier Bill #',
                  b.supplierBillNumber.isEmpty ? '—' : b.supplierBillNumber),
              _row('Currency',
                  '${b.currency}  (Rate: ${b.exchangeRate})'),
              _row(
                'Bill Date',
                b.billDate == null
                    ? '—'
                    : '${b.billDate!.year}-${b.billDate!.month.toString().padLeft(2, '0')}-${b.billDate!.day.toString().padLeft(2, '0')}',
              ),
              _row(
                'Due Date',
                b.dueDate == null
                    ? '—'
                    : '${b.dueDate!.year}-${b.dueDate!.month.toString().padLeft(2, '0')}-${b.dueDate!.day.toString().padLeft(2, '0')}',
              ),
            ]),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Line Items',
            child: Column(
              children: [
                _lineHeader(),
                const SizedBox(height: 6),
                ...b.lines.asMap().entries.map((e) {
                  final i = e.key;
                  final l = e.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                            width: 28,
                            child: Text('${i + 1}',
                                style: AppTextStyles.caption)),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.productName,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600)),
                              Text(l.sku,
                                  style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            '${l.quantity.toStringAsFixed(2)} ${l.baseUnit}',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            l.unitPrice.toStringAsFixed(2),
                            style: AppTextStyles.bodyMedium,
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            l.lineTotal.toStringAsFixed(2),
                            style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Totals',
            child: Column(
              children: [
                _totRow('Subtotal',
                    '${b.currency} ${b.subtotal.toStringAsFixed(2)}'),
                _totRow('Tax',
                    '${b.currency} ${b.taxTotal.toStringAsFixed(2)}'),
                _totRow('Freight',
                    '${b.currency} ${b.freight.toStringAsFixed(2)}'),
                _totRow('Other Charges',
                    '${b.currency} ${b.otherCharges.toStringAsFixed(2)}'),
                const Divider(color: AppColors.border, height: 20),
                _totRow(
                  'Grand Total',
                  '${b.currency} ${b.grandTotal.toStringAsFixed(2)}',
                  bold: true,
                ),
                _totRow(
                  'Paid',
                  '${b.currency} ${b.amountPaid.toStringAsFixed(2)}',
                ),
                _totRow(
                  'Outstanding',
                  '${b.currency} ${b.outstanding.toStringAsFixed(2)}',
                  color: b.outstanding > 0 ? AppColors.warning : null,
                ),
              ],
            ),
          ),
          if (b.notes.isNotEmpty) ...[
            const SizedBox(height: 20),
            SectionCard(
              title: 'Notes',
              child: Text(b.notes, style: AppTextStyles.bodyMedium),
            ),
          ],
        ],
      ),
    );
  }

  Widget _grid(List<Widget> items) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 700 ? 2 : 1;
      return Wrap(
        spacing: 16,
        runSpacing: 14,
        children: items
            .map((w) => SizedBox(
                  width: (c.maxWidth - (cols - 1) * 16) / cols,
                  child: w,
                ))
            .toList(),
      );
    });
  }

  Widget _row(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.bodyMedium),
      ],
    );
  }

  Widget _lineHeader() {
    return Row(
      children: [
        const SizedBox(width: 28),
        Expanded(
            flex: 3,
            child: Text('Product', style: AppTextStyles.label)),
        Expanded(flex: 1, child: Text('Qty', style: AppTextStyles.label)),
        Expanded(
            flex: 1,
            child: Text('Price',
                style: AppTextStyles.label, textAlign: TextAlign.right)),
        Expanded(
            flex: 1,
            child: Text('Total',
                style: AppTextStyles.label, textAlign: TextAlign.right)),
      ],
    );
  }

  Widget _totRow(String label, String value,
      {bool bold = false, Color? color}) {
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
              style: (bold
                      ? AppTextStyles.bodyLarge
                          .copyWith(fontWeight: FontWeight.w700)
                      : AppTextStyles.bodyMedium)
                  .copyWith(color: color)),
        ],
      ),
    );
  }
}