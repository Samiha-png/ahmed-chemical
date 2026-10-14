import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/sales_order.dart';
import '../providers/auth_provider.dart';
import '../providers/sales_order_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_dialog.dart';
import '../widgets/section_card.dart';

class SalesOrderDetailScreen extends ConsumerStatefulWidget {
  final String soId;
  const SalesOrderDetailScreen({super.key, required this.soId});

  @override
  ConsumerState<SalesOrderDetailScreen> createState() =>
      _SalesOrderDetailScreenState();
}

class _SalesOrderDetailScreenState
    extends ConsumerState<SalesOrderDetailScreen> {
  SalesOrder? _so;
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
      final so =
          await ref.read(salesOrderServiceProvider).getById(widget.soId);
      setState(() {
        _so = so;
        _loading = false;
        if (so == null) _error = 'Sales order not found';
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _confirm() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Confirm this sales order?',
      message: 'Once confirmed, this SO cannot be edited.',
      confirmLabel: 'Confirm',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final uid = ref.read(authServiceProvider).currentUser?.uid ?? '';
      await ref.read(salesOrderServiceProvider).confirm(widget.soId, uid);
      await _load();
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Cancel this sales order?',
      message: 'The SO will be marked as cancelled.',
      danger: true,
      confirmLabel: 'Cancel SO',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final uid = ref.read(authServiceProvider).currentUser?.uid ?? '';
      await ref.read(salesOrderServiceProvider).cancel(widget.soId, uid);
      await _load();
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete this draft sales order?',
      message: 'This cannot be undone.',
      danger: true,
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await ref.read(salesOrderServiceProvider).delete(widget.soId);
      if (mounted) context.go('/sales');
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
    if (_error != null || _so == null) {
      return Center(
        child: Text(_error ?? 'Error', style: AppTextStyles.bodyMedium),
      );
    }
    final so = _so!;
    final isDraft = so.statusEnum == SOStatus.draft;
    final canCancel = so.statusEnum == SOStatus.draft ||
        so.statusEnum == SOStatus.confirmed ||
        so.statusEnum == SOStatus.partiallyInvoiced;

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(so.number, style: AppTextStyles.displayMedium),
                    const SizedBox(height: 4),
                    Text(so.customerName, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              if (isDraft)
                OutlinedButton.icon(
                  onPressed: () => context.go('/sales/${so.id}/edit'),
                  icon: const Icon(LucideIcons.pencil, size: 15),
                  label: const Text('Edit'),
                ),
              if (so.statusEnum == SOStatus.confirmed ||
                  so.statusEnum == SOStatus.partiallyInvoiced) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => context.go('/invoices/new?so=${so.id}'),
                  icon: const Icon(LucideIcons.fileText, size: 16),
                  label: const Text('Create Invoice'),
                ),
              ],
              if (isDraft) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _confirm,
                  icon: _busy
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Icon(LucideIcons.check, size: 16),
                  label: const Text('Confirm'),
                ),
              ],
              if (canCancel) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _cancel,
                  icon: const Icon(LucideIcons.xCircle, size: 15),
                  label: const Text('Cancel SO'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ],
              if (isDraft) ...[
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
            ],
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Details',
            child: _grid([
              _row('Status', soStatusLabel(so.statusEnum)),
              _row('Currency',
                  '${so.currency}  (Rate: ${so.exchangeRate})'),
              _row(
                'Expected Delivery',
                so.expectedDelivery == null
                    ? '—'
                    : '${so.expectedDelivery!.year}-${so.expectedDelivery!.month.toString().padLeft(2, '0')}-${so.expectedDelivery!.day.toString().padLeft(2, '0')}',
              ),
              _row(
                'Created',
                so.createdAt == null
                    ? '—'
                    : '${so.createdAt!.year}-${so.createdAt!.month.toString().padLeft(2, '0')}-${so.createdAt!.day.toString().padLeft(2, '0')}',
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
                ...so.lines.asMap().entries.map((e) {
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
                              Text(
                                  '${l.sku} • ${l.warehouseName}',
                                  style: AppTextStyles.caption),
                              if (l.invoicedQuantity > 0)
                                Text(
                                  'Invoiced: ${l.invoicedQuantity.toStringAsFixed(2)} / ${l.quantity.toStringAsFixed(2)}',
                                  style: AppTextStyles.caption.copyWith(
                                      color: AppColors.primary),
                                ),
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
                    '${so.currency} ${so.subtotal.toStringAsFixed(2)}'),
                _totRow('Tax',
                    '${so.currency} ${so.taxTotal.toStringAsFixed(2)}'),
                _totRow('Freight',
                    '${so.currency} ${so.freight.toStringAsFixed(2)}'),
                _totRow('Other Charges',
                    '${so.currency} ${so.otherCharges.toStringAsFixed(2)}'),
                const Divider(color: AppColors.border, height: 20),
                _totRow(
                  'Grand Total',
                  '${so.currency} ${so.grandTotal.toStringAsFixed(2)}',
                  bold: true,
                ),
                if (so.currency != 'PKR')
                  _totRow('Base Total (PKR)',
                      so.baseTotal.toStringAsFixed(2)),
              ],
            ),
          ),
          if (so.notes.isNotEmpty) ...[
            const SizedBox(height: 20),
            SectionCard(
              title: 'Notes',
              child: Text(so.notes, style: AppTextStyles.bodyMedium),
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

  Widget _totRow(String label, String value, {bool bold = false}) {
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