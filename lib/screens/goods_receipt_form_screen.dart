import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../models/goods_receipt.dart';
import '../models/purchase_order.dart';
import '../providers/auth_provider.dart';
import '../providers/goods_receipt_provider.dart';
import '../providers/purchase_order_provider.dart';
import '../providers/warehouse_provider.dart';
import '../services/warehouse_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/form_field.dart';
import '../widgets/section_card.dart';

class GoodsReceiptFormScreen extends ConsumerStatefulWidget {
  final String? poId;
  const GoodsReceiptFormScreen({super.key, this.poId});

  @override
  ConsumerState<GoodsReceiptFormScreen> createState() =>
      _GoodsReceiptFormScreenState();
}

class _GoodsReceiptFormScreenState
    extends ConsumerState<GoodsReceiptFormScreen> {
  // Use ID (String) as dropdown value — not the whole object
  String? _selectedPoId;
  PurchaseOrder? _po; // resolved object for internal use
  String? _selectedWarehouseId;
  Warehouse? _warehouse;
  final _notesCtrl = TextEditingController();
  DateTime _receivedDate = DateTime.now();
  final List<_GRNLineDraft> _lines = [];

  bool _loading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.poId != null) _loadFromPO(widget.poId!);
  }

  Future<void> _loadFromPO(String poId) async {
    setState(() => _loading = true);
    try {
      final po =
          await ref.read(purchaseOrderServiceProvider).getById(poId);
      if (po == null) {
        setState(() => _error = 'Purchase order not found');
        return;
      }
      if (po.statusEnum != POStatus.approved &&
          po.statusEnum != POStatus.partiallyReceived) {
        setState(() =>
            _error = 'Only approved or partially received POs can be received');
        return;
      }
      _selectedPoId = po.id;
      _po = po;
      _fillLinesFromPo(po);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fillLinesFromPo(PurchaseOrder po) {
    for (final l in _lines) {
      l.dispose();
    }
    _lines.clear();

    for (final l in po.lines) {
      final remaining = l.quantity - l.receivedQuantity;
      if (remaining <= 0) continue;
      _lines.add(_GRNLineDraft(
        id: const Uuid().v4(),
        poLineId: l.id,
        productId: l.productId,
        productName: l.productName,
        sku: l.sku,
        baseUnit: l.baseUnit,
        orderedQty: l.quantity,
        qtyCtrl: TextEditingController(text: remaining.toString()),
        costCtrl: TextEditingController(text: l.unitPrice.toString()),
      ));
    }

    if (_lines.isEmpty) {
      setState(() =>
          _error = 'All lines in this PO are already received');
    }
  }

  Future<void> _onPoSelected(String? poId) async {
    setState(() {
      _selectedPoId = poId;
      _error = null;
    });
    if (poId == null) {
      _po = null;
      for (final l in _lines) {
        l.dispose();
      }
      _lines.clear();
      setState(() {});
      return;
    }
    final po =
        await ref.read(purchaseOrderServiceProvider).getById(poId);
    if (po == null) {
      setState(() => _error = 'PO not found');
      return;
    }
    _po = po;
    _fillLinesFromPo(po);
    setState(() {});
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  num _parse(String s) => num.tryParse(s.trim()) ?? 0;

  Future<void> _save({bool andPost = false}) async {
    if (_po == null) {
      setState(() => _error = 'Select a purchase order');
      return;
    }
    if (_warehouse == null) {
      setState(() => _error = 'Select a warehouse');
      return;
    }
    final valid =
        _lines.where((l) => _parse(l.qtyCtrl.text) > 0).toList();
    if (valid.isEmpty) {
      setState(() => _error = 'Enter at least one quantity');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final uid = ref.read(authServiceProvider).currentUser?.uid ?? '';
      final lines = valid
          .map((l) => GRNLine(
                id: l.id,
                poLineId: l.poLineId,
                productId: l.productId,
                productName: l.productName,
                sku: l.sku,
                baseUnit: l.baseUnit,
                quantity: _parse(l.qtyCtrl.text),
                unitCost: _parse(l.costCtrl.text),
                orderedQty: l.orderedQty,
              ))
          .toList();

      final grn = GoodsReceipt(
        id: '',
        number: '',
        poId: _po!.id,
        poNumber: _po!.number,
        supplierId: _po!.supplierId,
        supplierName: _po!.supplierName,
        warehouseId: _warehouse!.id,
        warehouseName: _warehouse!.name,
        status: GRNStatus.draft.name,
        lines: lines,
        notes: _notesCtrl.text.trim(),
        receivedDate: _receivedDate,
        createdBy: uid,
      );

      final id =
          await ref.read(goodsReceiptServiceProvider).createDraft(grn);

      if (andPost) {
        await ref.read(goodsReceiptServiceProvider).post(
              grnId: id,
              userId: uid,
            );
      }
      if (mounted) context.go('/purchasing/receipts');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final warehouses = ref.watch(warehousesStreamProvider);
    final pos = ref.watch(purchaseOrdersStreamProvider);

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
                onPressed: () => context.go('/purchasing/receipts'),
                icon: const Icon(LucideIcons.arrowLeft, size: 18),
              ),
              const SizedBox(width: 8),
              Text('New Goods Receipt',
                  style: AppTextStyles.displayMedium),
            ],
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'PO & Warehouse',
            child: Column(
              children: [
                Text('Purchase Order', style: AppTextStyles.label),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: pos.when(
                    loading: () => const SizedBox(
                        height: 42, child: LinearProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                    data: (list) {
                      final eligible = list
                          .where((p) =>
                              p.statusEnum == POStatus.approved ||
                              p.statusEnum ==
                                  POStatus.partiallyReceived)
                          .toList();
                      // Guard: ensure current value still exists in list
                      final validIds = eligible.map((e) => e.id).toSet();
                      final safeValue =
                          validIds.contains(_selectedPoId)
                              ? _selectedPoId
                              : null;
                      return DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: safeValue,
                          isExpanded: true,
                          dropdownColor: AppColors.elevated,
                          style: AppTextStyles.bodyMedium,
                          hint: Text('Select purchase order',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textDim)),
                          items: eligible
                              .map((p) => DropdownMenuItem<String>(
                                    value: p.id,
                                    child: Text(
                                        '${p.number} — ${p.supplierName}'),
                                  ))
                              .toList(),
                          onChanged: _onPoSelected,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Text('Warehouse', style: AppTextStyles.label),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: warehouses.when(
                    loading: () => const SizedBox(
                        height: 42, child: LinearProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                    data: (list) {
                      final validIds = list.map((e) => e.id).toSet();
                      final safeValue =
                          validIds.contains(_selectedWarehouseId)
                              ? _selectedWarehouseId
                              : null;
                      return DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: safeValue,
                          isExpanded: true,
                          dropdownColor: AppColors.elevated,
                          style: AppTextStyles.bodyMedium,
                          hint: Text('Select warehouse',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textDim)),
                          items: list
                              .map((w) => DropdownMenuItem<String>(
                                    value: w.id,
                                    child: Text(w.name),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _selectedWarehouseId = v;
                              _warehouse = v == null
                                  ? null
                                  : list.firstWhere((x) => x.id == v);
                            });
                          },
                        ),
                      );
                    },
                  ),
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
          SectionCard(
            title: 'Line Items',
            subtitle:
                'Enter received quantity for each line. Empty lines are ignored.',
            child: _lines.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        _po == null
                            ? 'Select a purchase order to see lines.'
                            : 'No lines to receive.',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  )
                : Column(
                    children: List.generate(_lines.length, (i) {
                      return _GRNLineRow(
                        index: i + 1,
                        draft: _lines[i],
                        onChanged: () => setState(() {}),
                      );
                    }),
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
                onPressed: () => context.go('/purchasing/receipts'),
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

class _GRNLineDraft {
  final String id;
  final String poLineId;
  final String productId;
  final String productName;
  final String sku;
  final String baseUnit;
  final num orderedQty;
  final TextEditingController qtyCtrl;
  final TextEditingController costCtrl;

  _GRNLineDraft({
    required this.id,
    required this.poLineId,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.baseUnit,
    required this.orderedQty,
    required this.qtyCtrl,
    required this.costCtrl,
  });

  void dispose() {
    qtyCtrl.dispose();
    costCtrl.dispose();
  }
}

class _GRNLineRow extends StatelessWidget {
  final int index;
  final _GRNLineDraft draft;
  final VoidCallback onChanged;

  const _GRNLineRow({
    required this.index,
    required this.draft,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('#$index', style: AppTextStyles.caption),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(draft.productName,
                        style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600)),
                    Text(
                      '${draft.sku} • Ordered: ${draft.orderedQty.toStringAsFixed(2)} ${draft.baseUnit}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _smallField(
                    'Receive Qty', draft.qtyCtrl, onChanged),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _smallField(
                    'Unit Cost', draft.costCtrl, onChanged),
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            fillColor: AppColors.card,
          ),
        ),
      ],
    );
  }
}