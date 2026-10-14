import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:printing/printing.dart';

import '../models/purchase_order.dart';
import '../providers/auth_provider.dart';
import '../providers/purchase_order_provider.dart';
import '../providers/settings_provider.dart';
import '../services/pdf_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_dialog.dart';
import '../widgets/section_card.dart';

class PurchaseOrderDetailScreen extends ConsumerStatefulWidget {
  final String poId;
  const PurchaseOrderDetailScreen({super.key, required this.poId});

  @override
  ConsumerState<PurchaseOrderDetailScreen> createState() =>
      _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState
    extends ConsumerState<PurchaseOrderDetailScreen> {
  PurchaseOrder? _po;
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
      final po =
          await ref.read(purchaseOrderServiceProvider).getById(widget.poId);
      setState(() {
        _po = po;
        _loading = false;
        if (po == null) _error = 'PO not found';
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _approve() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Approve this purchase order?',
      message:
          'Once approved, this PO cannot be edited. You can still cancel it.',
      confirmLabel: 'Approve',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final uid = ref.read(authServiceProvider).currentUser?.uid ?? '';
      await ref.read(purchaseOrderServiceProvider).approve(widget.poId, uid);
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
      title: 'Cancel this PO?',
      message:
          'The PO will be marked as cancelled. This action cannot be undone.',
      danger: true,
      confirmLabel: 'Cancel PO',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final uid = ref.read(authServiceProvider).currentUser?.uid ?? '';
      await ref.read(purchaseOrderServiceProvider).cancel(widget.poId, uid);
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
      title: 'Delete this draft PO?',
      message: 'This cannot be undone.',
      danger: true,
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await ref.read(purchaseOrderServiceProvider).delete(widget.poId);
      if (mounted) context.go('/purchasing');
    } catch (e) {
      _snack('Error: $e', error: true);
    }
  }

  Future<void> _print() async {
    if (_po == null) return;
    try {
      final settings = ref.read(companySettingsProvider).value;
      final bytes = await PdfService.generatePurchaseOrder(
        _po!,
        settings: settings,
      );
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: _po!.number,
      );
    } catch (e) {
      _snack('PDF failed: $e', error: true);
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
    if (_error != null || _po == null) {
      return Center(
        child: Text(_error ?? 'Error', style: AppTextStyles.bodyMedium),
      );
    }
    final po = _po!;
    final isDraft = po.statusEnum == POStatus.draft;
    final canReceive = po.statusEnum == POStatus.approved ||
        po.statusEnum == POStatus.partiallyReceived;
    final canCancel = po.statusEnum == POStatus.draft ||
        po.statusEnum == POStatus.approved ||
        po.statusEnum == POStatus.partiallyReceived;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              IconButton(
                onPressed: () => context.go('/purchasing'),
                icon: const Icon(LucideIcons.arrowLeft, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(po.number, style: AppTextStyles.displayMedium),
                    const SizedBox(height: 4),
                    Text(po.supplierName,
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              if (isDraft)
                OutlinedButton.icon(
                  onPressed: () =>
                      context.go('/purchasing/${po.id}/edit'),
                  icon: const Icon(LucideIcons.pencil, size: 15),
                  label: const Text('Edit'),
                ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _print,
                icon: const Icon(LucideIcons.printer, size: 15),
                label: const Text('Print'),
              ),
              // ⬇️ NAYA — Receive Stock (opens GRN form with this PO)
              if (canReceive) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => context
                      .go('/purchasing/receipts/new?po=${po.id}'),
                  icon: const Icon(LucideIcons.packagePlus, size: 16),
                  label: const Text('Receive Stock'),
                ),
              ],
              if (isDraft) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _approve,
                  icon: _busy
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Icon(LucideIcons.check, size: 16),
                  label: const Text('Approve'),
                ),
              ],
              if (canCancel) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _cancel,
                  icon: const Icon(LucideIcons.xCircle, size: 15),
                  label: const Text('Cancel PO'),
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

          // Info card
          SectionCard(
            title: 'Details',
            child: _grid([
              _row('Status', poStatusLabel(po.statusEnum)),
              _row('Currency',
                  '${po.currency}  (Rate: ${po.exchangeRate})'),
              _row(
                'Expected Delivery',
                po.expectedDelivery == null
                    ? '—'
                    : '${po.expectedDelivery!.year}-${po.expectedDelivery!.month.toString().padLeft(2, '0')}-${po.expectedDelivery!.day.toString().padLeft(2, '0')}',
              ),
              _row(
                'Created',
                po.createdAt == null
                    ? '—'
                    : '${po.createdAt!.year}-${po.createdAt!.month.toString().padLeft(2, '0')}-${po.createdAt!.day.toString().padLeft(2, '0')}',
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Lines
          SectionCard(
            title: 'Line Items',
            child: Column(
              children: [
                _lineHeader(),
                const SizedBox(height: 6),
                ...po.lines.asMap().entries.map((e) {
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
                              // Show received quantity if > 0
                              if (l.receivedQuantity > 0)
                                Text(
                                  'Received: ${l.receivedQuantity.toStringAsFixed(2)} / ${l.quantity.toStringAsFixed(2)}',
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

          // Totals
          SectionCard(
            title: 'Totals',
            child: Column(
              children: [
                _totRow('Subtotal',
                    '${po.currency} ${po.subtotal.toStringAsFixed(2)}'),
                _totRow('Tax',
                    '${po.currency} ${po.taxTotal.toStringAsFixed(2)}'),
                _totRow('Freight',
                    '${po.currency} ${po.freight.toStringAsFixed(2)}'),
                _totRow('Other Charges',
                    '${po.currency} ${po.otherCharges.toStringAsFixed(2)}'),
                const Divider(color: AppColors.border, height: 20),
                _totRow(
                  'Grand Total',
                  '${po.currency} ${po.grandTotal.toStringAsFixed(2)}',
                  bold: true,
                ),
                if (po.currency != 'PKR')
                  _totRow('Base Total (PKR)',
                      po.baseTotal.toStringAsFixed(2)),
              ],
            ),
          ),

          if (po.notes.isNotEmpty) ...[
            const SizedBox(height: 20),
            SectionCard(
              title: 'Notes',
              child: Text(po.notes, style: AppTextStyles.bodyMedium),
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
        Expanded(
            flex: 1, child: Text('Qty', style: AppTextStyles.label)),
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