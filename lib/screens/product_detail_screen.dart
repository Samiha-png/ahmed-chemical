import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../providers/product_provider.dart';
import '../services/product_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_dialog.dart';
import '../widgets/section_card.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  Product? _product;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await ref.read(productServiceProvider).getById(widget.productId);
      setState(() {
        _product = p;
        _loading = false;
        if (p == null) _error = 'Product nahi mila';
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete product?',
      message: '${_product!.name} ko delete karein?',
      danger: true,
      confirmLabel: 'Delete',
    );
    if (ok) {
      await ref.read(productServiceProvider).delete(widget.productId);
      if (mounted) context.go('/products');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null || _product == null) {
      return Center(
        child: Text(_error ?? 'Error', style: AppTextStyles.bodyMedium),
      );
    }
    final p = _product!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.go('/products'),
                icon: const Icon(LucideIcons.arrowLeft, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(p.name, style: AppTextStyles.displayMedium),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/products/${p.id}/edit'),
                icon: const Icon(LucideIcons.pencil, size: 15),
                label: const Text('Edit'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _delete,
                icon: const Icon(LucideIcons.trash2, size: 15),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Basic',
            child: _grid([
              _row('SKU', p.sku),
              _row('Category', p.categoryName ?? '—'),
              _row('Grade', p.grade.isEmpty ? '—' : p.grade),
            ]),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Pricing & Units',
            child: _grid([
              _row('Purchase Price', '${p.purchaseCurrency} ${p.purchasePrice}'),
              _row('Selling Price', 'PKR ${p.sellingPrice}'),
              _row('Base Unit', p.baseUnit),
              _row('Packaging', '${p.packagingType} ${p.packageSize}'.trim()),
              _row('Density', p.density?.toString() ?? 'Not set'),
              _row('Reorder Level', p.reorderLevel.toString()),
            ]),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Safety',
            child: _grid([
              _row('Storage', p.storageRequirements.isEmpty ? '—' : p.storageRequirements),
              _row('Hazards', p.hazardInfo.isEmpty ? '—' : p.hazardInfo),
              _row('SDS URL', p.sdsUrl.isEmpty ? 'Not uploaded' : p.sdsUrl),
              _row('Batch Tracking', p.batchTracking ? 'Yes' : 'No'),
            ]),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Description',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.description.isEmpty ? '—' : p.description,
                    style: AppTextStyles.bodyMedium),
                const SizedBox(height: 12),
                Text('Specifications', style: AppTextStyles.label),
                const SizedBox(height: 4),
                Text(p.specifications.isEmpty ? '—' : p.specifications,
                    style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
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
}