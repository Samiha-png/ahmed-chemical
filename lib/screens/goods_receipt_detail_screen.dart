import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/goods_receipt.dart';
import '../providers/auth_provider.dart';
import '../providers/goods_receipt_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_dialog.dart';
import '../widgets/section_card.dart';

class GoodsReceiptDetailScreen extends ConsumerStatefulWidget {
  final String grnId;
  const GoodsReceiptDetailScreen({super.key, required this.grnId});

  @override
  ConsumerState<GoodsReceiptDetailScreen> createState() =>
      _GoodsReceiptDetailScreenState();
}

class _GoodsReceiptDetailScreenState
    extends ConsumerState<GoodsReceiptDetailScreen> {
  GoodsReceipt? _grn;
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
      final grn =
          await ref.read(goodsReceiptServiceProvider).getById(widget.grnId);
      setState(() {
        _grn = grn;
        _loading = false;
        if (grn == null) _error = 'GRN not found';
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _post() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Post this goods receipt?',
      message:
          'Stock will be increased in the selected warehouse. This cannot be undone.',
      confirmLabel: 'Post GRN',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final uid = ref.read(authServiceProvider).currentUser?.uid ?? '';
      await ref.read(goodsReceiptServiceProvider).post(
            grnId: widget.grnId,
            userId: uid,
          );
      await _load();
      _snack('GRN posted. Stock increased.');
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete this draft GRN?',
      message: 'This cannot be undone.',
      danger: true,
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await ref
          .read(goodsReceiptServiceProvider)
          .deleteDraft(widget.grnId);
      if (mounted) context.go('/purchasing/receipts');
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
    if (_error != null || _grn == null) {
      return Center(
        child: Text(_error ?? 'Error', style: AppTextStyles.bodyMedium),
      );
    }
    final grn = _grn!;
    final isDraft = grn.statusEnum == GRNStatus.draft;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.go('/purchasing/receipts'),
                icon: const Icon(LucideIcons.arrowLeft, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(grn.number, style: AppTextStyles.displayMedium),
                    const SizedBox(height: 4),
                    Text('${grn.supplierName}  •  PO: ${grn.poNumber}',
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
                  label: const Text('Post GRN'),
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
            ],
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Details',
            child: _grid([
              _row('Status', grnStatusLabel(grn.statusEnum)),
              _row('Warehouse', grn.warehouseName),
              _row(
                'Received Date',
                grn.receivedDate == null
                    ? '—'
                    : '${grn.receivedDate!.year}-${grn.receivedDate!.month.toString().padLeft(2, '0')}-${grn.receivedDate!.day.toString().padLeft(2, '0')}',
              ),
              _row(
                'Created',
                grn.createdAt == null
                    ? '—'
                    : '${grn.createdAt!.year}-${grn.createdAt!.month.toString().padLeft(2, '0')}-${grn.createdAt!.day.toString().padLeft(2, '0')}',
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
                ...grn.lines.asMap().entries.map((e) {
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
                            l.unitCost.toStringAsFixed(2),
                            style: AppTextStyles.bodyMedium,
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            l.totalValue.toStringAsFixed(2),
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
            title: 'Total Value',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Grand Total',
                    style: AppTextStyles.bodyLarge
                        .copyWith(fontWeight: FontWeight.w700)),
                Text('PKR ${grn.totalValue.toStringAsFixed(2)}',
                    style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ],
            ),
          ),
          if (grn.notes.isNotEmpty) ...[
            const SizedBox(height: 20),
            SectionCard(
              title: 'Notes',
              child: Text(grn.notes, style: AppTextStyles.bodyMedium),
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
            child: Text('Cost',
                style: AppTextStyles.label, textAlign: TextAlign.right)),
        Expanded(
            flex: 1,
            child: Text('Total',
                style: AppTextStyles.label, textAlign: TextAlign.right)),
      ],
    );
  }
}