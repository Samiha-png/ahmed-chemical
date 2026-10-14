import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/product_provider.dart';
import '../providers/warehouse_provider.dart';
import '../services/product_service.dart';
import '../services/warehouse_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/form_field.dart';
import '../widgets/section_card.dart';

class ReceiveStockScreen extends ConsumerStatefulWidget {
  const ReceiveStockScreen({super.key});

  @override
  ConsumerState<ReceiveStockScreen> createState() =>
      _ReceiveStockScreenState();
}

class _ReceiveStockScreenState extends ConsumerState<ReceiveStockScreen> {
  Product? _product;
  Warehouse? _warehouse;
  final _qtyCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  num _parse(String s) => num.tryParse(s.trim()) ?? 0;

  Future<void> _submit() async {
    if (_product == null) {
      setState(() => _error = 'Select a product');
      return;
    }
    if (_warehouse == null) {
      setState(() => _error = 'Select a warehouse');
      return;
    }
    final qty = _parse(_qtyCtrl.text);
    final cost = _parse(_costCtrl.text);
    if (qty <= 0) {
      setState(() => _error = 'Quantity must be greater than zero');
      return;
    }
    if (cost < 0) {
      setState(() => _error = 'Unit cost cannot be negative');
      return;
    }

    setState(() { _saving = true; _error = null; });
    try {
      final uid = ref.read(authServiceProvider).currentUser?.uid ?? '';
      await ref.read(inventoryServiceProvider).receiveStock(
            productId: _product!.id,
            productName: _product!.name,
            sku: _product!.sku,
            baseUnit: _product!.baseUnit,
            warehouseId: _warehouse!.id,
            warehouseName: _warehouse!.name,
            quantity: qty,
            unitCost: cost,
            reorderLevel: _product!.reorderLevel,
            userId: uid,
            reference: _refCtrl.text.trim().isEmpty
                ? null
                : _refCtrl.text.trim(),
          );
      if (mounted) context.go('/inventory');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsStreamProvider);
    final warehouses = ref.watch(warehousesStreamProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.go('/inventory'),
                icon: const Icon(LucideIcons.arrowLeft, size: 18),
              ),
              const SizedBox(width: 8),
              Text('Receive Stock', style: AppTextStyles.displayMedium),
            ],
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Receipt Details',
            subtitle:
                'Stock increases only when a receipt is posted. This updates the weighted average cost.',
            child: Column(
              children: [
                // Product dropdown
                Text('Product', style: AppTextStyles.label),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: products.when(
                    loading: () => const SizedBox(
                        height: 42, child: LinearProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                    data: (list) => DropdownButtonHideUnderline(
                      child: DropdownButton<Product?>(
                        value: _product,
                        isExpanded: true,
                        dropdownColor: AppColors.elevated,
                        style: AppTextStyles.bodyMedium,
                        hint: Text('Select product',
                            style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textDim)),
                        items: list
                            .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text('${p.name} (${p.sku})'),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _product = v;
                          if (v != null) {
                            _costCtrl.text = v.purchasePrice.toString();
                          }
                        }),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Warehouse dropdown
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
                    data: (list) => DropdownButtonHideUnderline(
                      child: DropdownButton<Warehouse?>(
                        value: _warehouse,
                        isExpanded: true,
                        dropdownColor: AppColors.elevated,
                        style: AppTextStyles.bodyMedium,
                        hint: Text('Select warehouse',
                            style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textDim)),
                        items: list
                            .map((w) => DropdownMenuItem(
                                  value: w, child: Text(w.name)))
                            .toList(),
                        onChanged: (v) => setState(() => _warehouse = v),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(child: AppFormField(
                      label: 'Quantity',
                      controller: _qtyCtrl,
                      hint: '100',
                      keyboardType: TextInputType.number,
                      icon: LucideIcons.hash,
                      required: true,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: AppFormField(
                      label: 'Unit Cost',
                      controller: _costCtrl,
                      hint: '0.00',
                      keyboardType: TextInputType.number,
                      icon: LucideIcons.dollarSign,
                    )),
                  ],
                ),
                const SizedBox(height: 14),
                AppFormField(
                  label: 'Reference (optional)',
                  controller: _refCtrl,
                  hint: 'PO number, invoice, GRN',
                  icon: LucideIcons.fileText,
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
                Expanded(child: Text(_error!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.error))),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => context.go('/inventory'),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Icon(LucideIcons.check, size: 16),
                label: Text(_saving ? 'Posting...' : 'Post Receipt'),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}