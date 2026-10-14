import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../providers/supplier_provider.dart';
import '../services/supplier_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/form_field.dart';
import '../widgets/section_card.dart';

class SupplierFormScreen extends ConsumerStatefulWidget {
  final String? supplierId;
  const SupplierFormScreen({super.key, this.supplierId});

  @override
  ConsumerState<SupplierFormScreen> createState() =>
      _SupplierFormScreenState();
}

class _SupplierFormScreenState extends ConsumerState<SupplierFormScreen> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _creditCtrl = TextEditingController();
  final _openingCtrl = TextEditingController();
  final _termsCtrl = TextEditingController(text: '30');
  final _notesCtrl = TextEditingController();

  String _country = 'Pakistan';
  String _currency = 'PKR';
  bool _loading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.supplierId != null) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s =
          await ref.read(supplierServiceProvider).getById(widget.supplierId!);
      if (s != null) {
        _codeCtrl.text = s.code;
        _nameCtrl.text = s.name;
        _contactCtrl.text = s.contactPerson;
        _emailCtrl.text = s.email;
        _phoneCtrl.text = s.phone;
        _addressCtrl.text = s.address;
        _creditCtrl.text = s.creditLimit.toString();
        _openingCtrl.text = s.openingBalance.toString();
        _termsCtrl.text = s.paymentTermsDays.toString();
        _notesCtrl.text = s.notes;
        _country = s.country;
        _currency = s.currency;
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _creditCtrl.dispose();
    _openingCtrl.dispose();
    _termsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  num _parse(String s) => num.tryParse(s.trim()) ?? 0;

  Future<void> _save() async {
    if (_codeCtrl.text.trim().isEmpty || _nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Code and Name are required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final s = Supplier(
        id: widget.supplierId ?? '',
        code: _codeCtrl.text.trim().toUpperCase(),
        name: _nameCtrl.text.trim(),
        contactPerson: _contactCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        country: _country,
        currency: _currency,
        paymentTermsDays: int.tryParse(_termsCtrl.text.trim()) ?? 30,
        creditLimit: _parse(_creditCtrl.text),
        openingBalance: _parse(_openingCtrl.text),
        notes: _notesCtrl.text.trim(),
        active: true,
      );
      if (widget.supplierId == null) {
        await ref.read(supplierServiceProvider).create(s);
      } else {
        await ref.read(supplierServiceProvider).update(widget.supplierId!, s);
      }
      if (mounted) context.go('/suppliers');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.supplierId != null;

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
                onPressed: () => context.go('/suppliers'),
                icon: const Icon(LucideIcons.arrowLeft, size: 18),
              ),
              const SizedBox(width: 8),
              Text(isEdit ? 'Edit Supplier' : 'New Supplier',
                  style: AppTextStyles.displayMedium),
            ],
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Identity',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppFormField(
                        label: 'Supplier Code',
                        controller: _codeCtrl,
                        hint: 'SUP-001',
                        icon: LucideIcons.hash,
                        required: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppFormField(
                        label: 'Supplier Name',
                        controller: _nameCtrl,
                        hint: 'ABC Chemicals',
                        icon: LucideIcons.building,
                        required: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppFormField(
                  label: 'Contact Person',
                  controller: _contactCtrl,
                  hint: 'Ahmed Ali',
                  icon: LucideIcons.user,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Contact',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppFormField(
                        label: 'Email',
                        controller: _emailCtrl,
                        hint: 'contact@supplier.com',
                        icon: LucideIcons.mail,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppFormField(
                        label: 'Phone',
                        controller: _phoneCtrl,
                        hint: '+92 300 1234567',
                        icon: LucideIcons.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppFormField(
                  label: 'Address',
                  controller: _addressCtrl,
                  hint: 'Street, city, country',
                  icon: LucideIcons.mapPin,
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _dropdown(
                        'Country',
                        _country,
                        countries,
                        (v) => setState(() => _country = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dropdown(
                        'Currency',
                        _currency,
                        supplierCurrencies,
                        (v) => setState(() => _currency = v!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Commercial Terms',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppFormField(
                        label: 'Payment Terms (days)',
                        controller: _termsCtrl,
                        hint: '30',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppFormField(
                        label: 'Credit Limit',
                        controller: _creditCtrl,
                        hint: '0.00',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppFormField(
                        label: 'Opening Balance',
                        controller: _openingCtrl,
                        hint: '0.00',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppFormField(
                  label: 'Notes',
                  controller: _notesCtrl,
                  hint: 'Any additional notes',
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
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertCircle,
                      size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.error)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => context.go('/suppliers'),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(LucideIcons.save, size: 16),
                label: Text(_saving ? 'Saving...' : 'Save Supplier'),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChange,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
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
              value: value,
              isExpanded: true,
              dropdownColor: AppColors.elevated,
              style: AppTextStyles.bodyMedium,
              items: options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: onChange,
            ),
          ),
        ),
      ],
    );
  }
}