import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../providers/settings_provider.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/section_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  final _logoCtrl = TextEditingController();
  final _signatureCtrl = TextEditingController();

  String _currency = 'PKR';
  String _timezone = 'Asia/Karachi';
  String _fyStart = '07-01';
  bool _initialized = false;
  bool _saving = false;

  static const _currencies = ['PKR', 'USD', 'EUR', 'GBP', 'AED'];
  static const _timezones = ['Asia/Karachi', 'Asia/Dubai', 'UTC'];
  static const Map<String, String> _fyOptions = {
    '01-01': '1 January',
    '07-01': '1 July',
  };

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _taxCtrl.dispose();
    _logoCtrl.dispose();
    _signatureCtrl.dispose();
    super.dispose();
  }

  void _populate(CompanySettings s) {
    if (_initialized) return;
    _nameCtrl.text = s.companyName;
    _addressCtrl.text = s.address;
    _phoneCtrl.text = s.phone;
    _emailCtrl.text = s.email;
    _taxCtrl.text = s.taxNumber;
    _logoCtrl.text = s.logoUrl;
    _signatureCtrl.text = s.signatureUrl;
    _currency = s.baseCurrency;
    _timezone = s.timeZone;
    _fyStart = s.financialYearStart;
    _initialized = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final s = CompanySettings(
        companyName: _nameCtrl.text.trim(),
        baseCurrency: _currency,
        timeZone: _timezone,
        financialYearStart: _fyStart,
        logoUrl: _logoCtrl.text.trim(),
        signatureUrl: _signatureCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        taxNumber: _taxCtrl.text.trim(),
      );
      await ref.read(settingsServiceProvider).save(s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(companySettingsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: AppTextStyles.displayMedium),
          const SizedBox(height: 6),
          Text('Company profile and preferences',
              style: AppTextStyles.bodySmall),
          const SizedBox(height: 24),
          settings.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (e, _) => Text('Error: $e',
                style: AppTextStyles.bodySmall),
            data: (s) {
              _populate(s);
              return Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ─── Company Profile ───
                    SectionCard(
                      title: 'Company Profile',
                      child: Column(
                        children: [
                          _field('Company Name', _nameCtrl,
                              icon: LucideIcons.building),
                          const SizedBox(height: 14),
                          _field('Address', _addressCtrl,
                              icon: LucideIcons.mapPin, maxLines: 2),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _field('Phone', _phoneCtrl,
                                    icon: LucideIcons.phone),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _field('Email', _emailCtrl,
                                    icon: LucideIcons.mail),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _field('Tax / NTN Number', _taxCtrl,
                              icon: LucideIcons.fileText),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── Branding ───
                    SectionCard(
                      title: 'Branding',
                      subtitle:
                          'Paste image URLs from Cloudinary. Used on invoices and purchase orders.',
                      child: Column(
                        children: [
                          _field(
                            'Logo URL',
                            _logoCtrl,
                            icon: LucideIcons.image,
                            hint: 'https://res.cloudinary.com/.../logo.png',
                          ),
                          const SizedBox(height: 14),
                          _field(
                            'Authorized Signature URL',
                            _signatureCtrl,
                            icon: LucideIcons.signature,
                            hint:
                                'https://res.cloudinary.com/.../signature.png',
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _imagePreview(
                                  label: 'Logo Preview',
                                  url: _logoCtrl.text.trim(),
                                  height: 70,
                                  backgroundWhite: true,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _imagePreview(
                                  label: 'Signature Preview',
                                  url: _signatureCtrl.text.trim(),
                                  height: 70,
                                  backgroundWhite: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── Financial Preferences ───
                    SectionCard(
                      title: 'Financial Preferences',
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _dropdown(
                                  'Base Currency',
                                  _currency,
                                  _currencies,
                                  (v) => setState(() => _currency = v!),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _dropdown(
                                  'Time Zone',
                                  _timezone,
                                  _timezones,
                                  (v) => setState(() => _timezone = v!),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _dropdown(
                            'Financial Year Start',
                            _fyStart,
                            _fyOptions.keys.toList(),
                            (v) => setState(() => _fyStart = v!),
                            labelBuilder: (k) => _fyOptions[k] ?? k,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── Save Button ───
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(LucideIcons.save, size: 16),
                          label: Text(
                            _saving ? 'Saving...' : 'Save Settings',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // REUSABLE WIDGETS
  // ─────────────────────────────────────────────────────────

  Widget _field(
    String label,
    TextEditingController ctrl, {
    IconData? icon,
    int maxLines = 1,
    String? hint,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          onChanged: onChanged ?? (v) {
            // Trigger rebuild for URL previews
            if (label == 'Logo URL' || label == 'Authorized Signature URL') {
              setState(() {});
            }
          },
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, size: 16) : null,
          ),
        ),
      ],
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChange, {
    String Function(String)? labelBuilder,
  }) {
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
                  .map((o) => DropdownMenuItem(
                        value: o,
                        child: Text(labelBuilder?.call(o) ?? o),
                      ))
                  .toList(),
              onChanged: onChange,
            ),
          ),
        ),
      ],
    );
  }

  Widget _imagePreview({
    required String label,
    required String url,
    double height = 70,
    bool backgroundWhite = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 6),
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: backgroundWhite ? Colors.white : AppColors.elevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          child: url.isEmpty
              ? Text(
                  'No URL',
                  style: AppTextStyles.caption.copyWith(
                    color: backgroundWhite
                        ? Colors.grey.shade600
                        : AppColors.textDim,
                  ),
                )
              : Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Text(
                    'Invalid image',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.red.shade700,
                    ),
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}