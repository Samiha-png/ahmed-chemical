import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:printing/printing.dart';

import '../models/sales_invoice.dart';
import '../providers/auth_provider.dart';
import '../providers/sales_invoice_provider.dart';
import '../providers/settings_provider.dart';
import '../services/pdf_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_dialog.dart';
import '../widgets/section_card.dart';

class SalesInvoiceDetailScreen extends ConsumerStatefulWidget {
  final String invoiceId;
  const SalesInvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  ConsumerState<SalesInvoiceDetailScreen> createState() =>
      _SalesInvoiceDetailScreenState();
}

class _SalesInvoiceDetailScreenState
    extends ConsumerState<SalesInvoiceDetailScreen> {
  SalesInvoice? _inv;
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
      final inv = await ref
          .read(salesInvoiceServiceProvider)
          .getById(widget.invoiceId);
      setState(() {
        _inv = inv;
        _loading = false;
        if (inv == null) _error = 'Invoice not found';
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _post() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Post this invoice?',
      message:
          'Stock will be deducted from the selected warehouses. This cannot be undone.',
      confirmLabel: 'Post Invoice',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final uid = ref.read(authServiceProvider).currentUser?.uid ?? '';
      await ref.read(salesInvoiceServiceProvider).postInvoice(
            invoiceId: widget.invoiceId,
            userId: uid,
          );
      await _load();
      _snack('Invoice posted. Stock deducted.');
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete this draft invoice?',
      message: 'This cannot be undone.',
      danger: true,
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await ref
          .read(salesInvoiceServiceProvider)
          .deleteDraft(widget.invoiceId);
      if (mounted) context.go('/invoices');
    } catch (e) {
      _snack('Error: $e', error: true);
    }
  }

  Future<void> _print() async {
    if (_inv == null) return;
    try {
      final settings = ref.read(companySettingsProvider).value;
      final bytes = await PdfService.generateSalesInvoice(
        _inv!,
        settings: settings,
      );
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: _inv!.number,
      );
    } catch (e) {
      _snack('PDF failed: $e', error: true);
    }
  }

  Future<void> _recordPayment() async {
    if (_inv == null) return;
    final ctrl = TextEditingController(
        text: _inv!.outstanding.toStringAsFixed(2));
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Record Payment'),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Amount (${_inv!.currency})',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != true) return;
    final amount = num.tryParse(ctrl.text.trim()) ?? 0;
    if (amount <= 0) return;
    try {
      await ref.read(salesInvoiceServiceProvider).recordPayment(
            invoiceId: widget.invoiceId,
            amount: amount,
          );
      await _load();
      _snack('Payment recorded');
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
    if (_error != null || _inv == null) {
      return Center(
        child: Text(_error ?? 'Error', style: AppTextStyles.bodyMedium),
      );
    }
    final inv = _inv!;
    final isDraft = inv.statusEnum == InvoiceStatus.draft;
    final canPay = inv.statusEnum == InvoiceStatus.posted ||
        inv.statusEnum == InvoiceStatus.partiallyPaid;

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inv.number, style: AppTextStyles.displayMedium),
                    const SizedBox(height: 4),
                    Text(inv.customerName,
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _print,
                icon: const Icon(LucideIcons.printer, size: 15),
                label: const Text('Print'),
              ),
              if (isDraft) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _post,
                  icon: _busy
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Icon(LucideIcons.check, size: 16),
                  label: const Text('Post Invoice'),
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
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _recordPayment,
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
              _row('Status', invoiceStatusLabel(inv.statusEnum)),
              _row('Currency',
                  '${inv.currency}  (Rate: ${inv.exchangeRate})'),
              _row(
                'Invoice Date',
                inv.invoiceDate == null
                    ? '—'
                    : '${inv.invoiceDate!.year}-${inv.invoiceDate!.month.toString().padLeft(2, '0')}-${inv.invoiceDate!.day.toString().padLeft(2, '0')}',
              ),
              _row(
                'Due Date',
                inv.dueDate == null
                    ? '—'
                    : '${inv.dueDate!.year}-${inv.dueDate!.month.toString().padLeft(2, '0')}-${inv.dueDate!.day.toString().padLeft(2, '0')}',
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
                ...inv.lines.asMap().entries.map((e) {
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
                    '${inv.currency} ${inv.subtotal.toStringAsFixed(2)}'),
                _totRow('Tax',
                    '${inv.currency} ${inv.taxTotal.toStringAsFixed(2)}'),
                _totRow('Freight',
                    '${inv.currency} ${inv.freight.toStringAsFixed(2)}'),
                _totRow('Other Charges',
                    '${inv.currency} ${inv.otherCharges.toStringAsFixed(2)}'),
                const Divider(color: AppColors.border, height: 20),
                _totRow(
                  'Grand Total',
                  '${inv.currency} ${inv.grandTotal.toStringAsFixed(2)}',
                  bold: true,
                ),
                _totRow(
                  'Paid',
                  '${inv.currency} ${inv.amountPaid.toStringAsFixed(2)}',
                ),
                _totRow(
                  'Outstanding',
                  '${inv.currency} ${inv.outstanding.toStringAsFixed(2)}',
                  color: inv.outstanding > 0 ? AppColors.warning : null,
                ),
                if (inv.currency != 'PKR')
                  _totRow('Base Total (PKR)',
                      inv.baseTotal.toStringAsFixed(2)),
              ],
            ),
          ),
          if (inv.statusEnum == InvoiceStatus.posted ||
              inv.statusEnum == InvoiceStatus.partiallyPaid ||
              inv.statusEnum == InvoiceStatus.paid) ...[
            const SizedBox(height: 20),
            SectionCard(
              title: 'Profitability',
              child: _grid([
                _row('COGS',
                    '${inv.currency} ${inv.cogs.toStringAsFixed(2)}'),
                _row('Gross Profit',
                    '${inv.currency} ${inv.grossProfit.toStringAsFixed(2)}'),
              ]),
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