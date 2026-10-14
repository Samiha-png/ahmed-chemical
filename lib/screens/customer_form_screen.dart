import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../providers/customer_provider.dart';
import '../services/customer_service.dart';
import '../services/supplier_service.dart' show countries, supplierCurrencies;
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/form_field.dart';
import '../widgets/section_card.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  final String? customerId;
  const CustomerFormScreen({super.key, this.customerId});

  @override
  ConsumerState<CustomerFormScreen> createState() =>
      _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _billingCtrl = TextEditingController();
  final _shippingCtrl = TextEditingController();
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
    if (widget.customerId != null) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final c = await ref
          .read(customerServiceProvider)
          .getById(widget.customerId!);
      if (c != null) {
        _codeCtrl.text = c.code;
        _nameCtrl.text = c.name;
        _contactCtrl.text = c.contactPerson;
        _emailCtrl.text = c.email;
        _phoneCtrl.text = c.phone;
        _billingCtrl.text = c.billingAddress;
        _shippingCtrl.text = c.shippingAddress;
        _creditCtrl.text = c.creditLimit.toString();
        _openingCtrl.text = c.openingBalance.toString();
        _termsCtrl.text = c.paymentTermsDays.toString();
        _notesCtrl.text = c.notes;
        _country = c.country;
        _currency = c.currency;
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
    _billingCtrl.dispose();
    _shippingCtrl.dispose();
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
    setState(() { _saving = true; _error = null; });
    try {
      final c = Customer(
        id: widget.customerId ?? '',
        code: _codeCtrl.text.trim().toUpperCase(),
        name: _nameCtrl.text.trim(),
        contactPerson: _contactCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        billingAddress: _billingCtrl.text.trim(),
        shippingAddress: _shippingCtrl.text.trim(),
        country: _country,
        currency: _currency,
        paymentTermsDays: int.tryParse(_termsCtrl.text.trim()) ?? 30,
        creditLimit: _parse(_creditCtrl.text),
        openingBalance: _parse(_openingCtrl.text),
        notes: _notesCtrl.text.trim(),
        active: true,
      );
      if (widget.customerId == null) {
        await ref.read(customerServiceProvider).create(c);
      } else {
        await ref.read(customerServiceProvider).update(widget.customerId!, c);
      }
      if (mounted) context.go('/customers');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.customerId != null;

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
                onPressed: () => context.go('/customers'),
                icon: const Icon(LucideIcons.arrowLeft, size: 18),
              ),
              const SizedBox(width: 8),
              Text(isEdit ? 'Edit Customer' : 'New Customer',
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
                    Expanded(child: AppFormField(
                      label: 'Customer Code',
                      controller: _codeCtrl,
                      hint: 'CUST-001',
                      icon: LucideIcons.hash,
                      required: true,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: AppFormField(
                      label: 'Customer Name',
                      controller: _nameCtrl,
                      hint: 'XYZ Industries',
                      icon: LucideIcons.building,
                      required: true,
                    )),
                  ],
                ),
                const SizedBox(height: 14),
                AppFormField(
                  label: 'Contact Person',
                  controller: _contactCtrl,
                  hint: 'Bilal Ahmed',
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
                    Expanded(child: AppFormField(
                      label: 'Email',
                      controller: _emailCtrl,
                      hint: 'customer@example.com',
                      icon: LucideIcons.mail,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: AppFormField(
                      label: 'Phone',
                      controller: _phoneCtrl,
                      hint: '+92 300 1234567',
                      icon: LucideIcons.phone,
                    )),
                  ],
                ),
                const SizedBox(height: 14),
                AppFormField(
                  label: 'Billing Address',
                  controller: _billingCtrl,
                  hint: 'Street, city, country',
                  icon: LucideIcons.mapPin,
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                AppFormField(
                  label: 'Shipping Address',
                  controller: _shippingCtrl,
                  hint: 'Delivery address',
                  icon: LucideIcons.truck,
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _dropdown(
                      'Country',
                      _country,
                      countries,
                      (v) => setState(() => _country = v!),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _dropdown(
                      'Currency',
                      _currency,
                      supplierCurrencies,
                      (v) => setState(() => _currency = v!),
                    )),
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
                    Expanded(child: AppFormField(
                      label: 'Payment Terms (days)',
                      controller: _termsCtrl,
                      hint: '30',
                      keyboardType: TextInputType.number,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: AppFormField(
                      label: 'Credit Limit',
                      controller: _creditCtrl,
                      hint: '0.00',
                      keyboardType: TextInputType.number,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: AppFormField(
                      label: 'Opening Balance',
                      controller: _openingCtrl,
                      hint: '0.00',
                      keyboardType: TextInputType.number,
                    )),
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
                onPressed: () => context.go('/customers'),
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
                label: Text(_saving ? 'Saving...' : 'Save Customer'),
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
                  .map((o) =>
                      DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: onChange,
            ),
          ),
        ),
      ],
    );
  }
}