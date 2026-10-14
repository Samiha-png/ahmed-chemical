import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../providers/category_provider.dart';
import '../providers/product_provider.dart';
import '../services/product_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/form_field.dart';
import '../widgets/section_card.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;
  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _gradeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _specCtrl = TextEditingController();
  final _purchaseCtrl = TextEditingController();
  final _sellingCtrl = TextEditingController();
  final _reorderCtrl = TextEditingController();
  final _storageCtrl = TextEditingController();
  final _hazardCtrl = TextEditingController();
  final _sdsCtrl = TextEditingController();
  final _packTypeCtrl = TextEditingController();
  final _packSizeCtrl = TextEditingController();
  final _densityCtrl = TextEditingController();

  String? _categoryId;
  String _baseUnit = 'kg';
  String _currency = 'PKR';
  bool _batchTracking = false;
  bool _saving = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.productId != null) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // Simple: Firestore se ek dafa read
    try {
      final service = ref.read(productServiceProvider);
      // We fetch via stream and pick first, or direct doc read
      // For brevity, use a direct read via collection
      // (Better: service.getById — but keeping it simple)
      final doc = await service.getById(widget.productId!);
      if (doc == null) {
        setState(() => _error = 'Product nahi mila');
      } else {
        _nameCtrl.text = doc.name;
        _skuCtrl.text = doc.sku;
        _gradeCtrl.text = doc.grade;
        _descCtrl.text = doc.description;
        _specCtrl.text = doc.specifications;
        _purchaseCtrl.text = doc.purchasePrice.toString();
        _sellingCtrl.text = doc.sellingPrice.toString();
        _reorderCtrl.text = doc.reorderLevel.toString();
        _storageCtrl.text = doc.storageRequirements;
        _hazardCtrl.text = doc.hazardInfo;
        _sdsCtrl.text = doc.sdsUrl;
        _packTypeCtrl.text = doc.packagingType;
        _packSizeCtrl.text = doc.packageSize;
        _densityCtrl.text = doc.density?.toString() ?? '';
        _categoryId = doc.categoryId.isEmpty ? null : doc.categoryId;
        _baseUnit = doc.baseUnit;
        _currency = doc.purchaseCurrency;
        _batchTracking = doc.batchTracking;
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _gradeCtrl.dispose();
    _descCtrl.dispose();
    _specCtrl.dispose();
    _purchaseCtrl.dispose();
    _sellingCtrl.dispose();
    _reorderCtrl.dispose();
    _storageCtrl.dispose();
    _hazardCtrl.dispose();
    _sdsCtrl.dispose();
    _packTypeCtrl.dispose();
    _packSizeCtrl.dispose();
    _densityCtrl.dispose();
    super.dispose();
  }


  num _parse(String s) => num.tryParse(s.trim()) ?? 0;

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _skuCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Naam aur SKU zaroori hain');
      return;
    }
    setState(() { _saving = true; _error = null; });

    final catName = ref
        .read(categoriesStreamProvider)
        .value
        ?.firstWhere(
          (c) => c.id == _categoryId,
          orElse: () => throw Exception('no cat'),
        )
        .name;

    try {
      final p = Product(
        id: widget.productId ?? '',
        name: _nameCtrl.text.trim(),
        sku: _skuCtrl.text.trim().toUpperCase(),
        categoryId: _categoryId ?? '',
        categoryName: catName,
        grade: _gradeCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        specifications: _specCtrl.text.trim(),
        purchasePrice: _parse(_purchaseCtrl.text),
        sellingPrice: _parse(_sellingCtrl.text),
        baseUnit: _baseUnit,
        purchaseCurrency: _currency,
        reorderLevel: _parse(_reorderCtrl.text),
        storageRequirements: _storageCtrl.text.trim(),
        hazardInfo: _hazardCtrl.text.trim(),
        sdsUrl: _sdsCtrl.text.trim(),
        packagingType: _packTypeCtrl.text.trim(),
        packageSize: _packSizeCtrl.text.trim(),
        density: _densityCtrl.text.trim().isEmpty
            ? null
            : _parse(_densityCtrl.text),
        batchTracking: _batchTracking,
        active: true,
      );
      if (widget.productId == null) {
        await ref.read(productServiceProvider).create(p);
      } else {
        await ref.read(productServiceProvider).update(widget.productId!, p);
      }
      if (mounted) context.go('/products');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesStreamProvider);
    final isEdit = widget.productId != null;

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
                onPressed: () => context.go('/products'),
                icon: const Icon(LucideIcons.arrowLeft, size: 18),
              ),
              const SizedBox(width: 8),
              Text(isEdit ? 'Edit Product' : 'New Product',
                  style: AppTextStyles.displayMedium),
            ],
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Basic Info',
            child: Column(
              children: [
                AppFormField(
                  label: 'Product Name',
                  controller: _nameCtrl,
                  hint: 'Sulphuric Acid 98%',
                  icon: LucideIcons.package,
                  required: true,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: AppFormField(
                      label: 'SKU',
                      controller: _skuCtrl,
                      hint: 'SUL-98-001',
                      icon: LucideIcons.hash,
                      required: true,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: AppFormField(
                      label: 'Grade',
                      controller: _gradeCtrl,
                      hint: 'Technical / Industrial',
                      icon: LucideIcons.award,
                    )),
                  ],
                ),
                const SizedBox(height: 14),
                categories.when(
                  loading: () => const SizedBox(),
                  error: (_, _) => const SizedBox(),
                  data: (list) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Category', style: AppTextStyles.label),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.elevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _categoryId,
                            isExpanded: true,
                            dropdownColor: AppColors.elevated,
                            style: AppTextStyles.bodyMedium,
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: Text('(No category)')),
                              ...list.map((c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.name),
                                  )),
                            ],
                            onChanged: (v) => setState(() => _categoryId = v),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Pricing',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: AppFormField(
                      label: 'Purchase Price',
                      controller: _purchaseCtrl,
                      hint: '0.00',
                      icon: LucideIcons.trendingDown,
                      keyboardType: TextInputType.number,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: AppFormField(
                      label: 'Selling Price',
                      controller: _sellingCtrl,
                      hint: '0.00',
                      icon: LucideIcons.trendingUp,
                      keyboardType: TextInputType.number,
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Currency', style: AppTextStyles.label),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                items: ['PKR', 'USD', 'EUR', 'GBP', 'AED']
                                    .map((c) => DropdownMenuItem(
                                          value: c, child: Text(c)))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _currency = v ?? 'PKR'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Units & Packaging',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Base Unit', style: AppTextStyles.label),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.elevated,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _baseUnit,
                                isExpanded: true,
                                dropdownColor: AppColors.elevated,
                                style: AppTextStyles.bodyMedium,
                                items: baseUnits
                                    .map((u) => DropdownMenuItem(
                                          value: u, child: Text(u)))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _baseUnit = v ?? 'kg'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: AppFormField(
                      label: 'Packaging Type',
                      controller: _packTypeCtrl,
                      hint: 'Drum, Bag, Bottle',
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: AppFormField(
                      label: 'Package Size',
                      controller: _packSizeCtrl,
                      hint: '25 kg',
                    )),
                  ],
                ),
                const SizedBox(height: 14),
                AppFormField(
                  label: 'Density (kg/L) — agar mass↔volume conversion chahiye',
                  controller: _densityCtrl,
                  hint: '1.84 (e.g. for H2SO4)',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                Text(
                  'Note: kg aur L ko tab hi convert karein jab density di gayi ho.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Safety & Storage',
            child: Column(
              children: [
                AppFormField(
                  label: 'Storage Requirements',
                  controller: _storageCtrl,
                  hint: 'Cool, dry place. Away from bases.',
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                AppFormField(
                  label: 'Hazard & Handling Info',
                  controller: _hazardCtrl,
                  hint: 'Corrosive. Wear PPE.',
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                AppFormField(
                  label: 'Safety Data Sheet URL (Cloudinary)',
                  controller: _sdsCtrl,
                  hint: 'https://res.cloudinary.com/...',
                  icon: LucideIcons.fileText,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Switch(
                      value: _batchTracking,
                      onChanged: (v) => setState(() => _batchTracking = v),
                      activeThumbColor: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Batch / Lot tracking enable karein',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Inventory',
            child: AppFormField(
              label: 'Reorder Level',
              controller: _reorderCtrl,
              hint: '100',
              icon: LucideIcons.alertTriangle,
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Description',
            child: Column(
              children: [
                AppFormField(
                  label: 'Description',
                  controller: _descCtrl,
                  hint: 'Short product description',
                  maxLines: 3,
                ),
                const SizedBox(height: 14),
                AppFormField(
                  label: 'Specifications',
                  controller: _specCtrl,
                  hint: 'Purity, assay, etc.',
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
                border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                const Icon(LucideIcons.alertCircle,
                    size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.error))),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => context.go('/products'),
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
                    : const Icon(LucideIcons.save, size: 16),
                label: Text(_saving ? 'Saving...' : 'Save Product'),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}