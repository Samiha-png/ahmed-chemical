import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../providers/supplier_provider.dart';
import '../services/supplier_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_dialog.dart';
import '../widgets/section_card.dart';

class SupplierDetailScreen extends ConsumerStatefulWidget {
  final String supplierId;
  const SupplierDetailScreen({super.key, required this.supplierId});

  @override
  ConsumerState<SupplierDetailScreen> createState() =>
      _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends ConsumerState<SupplierDetailScreen> {
  Supplier? _supplier;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s =
          await ref.read(supplierServiceProvider).getById(widget.supplierId);
      setState(() {
        _supplier = s;
        _loading = false;
        if (s == null) _error = 'Supplier not found';
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete supplier?',
      message: 'Delete ${_supplier!.name}?',
      danger: true,
      confirmLabel: 'Delete',
    );
    if (ok) {
      await ref.read(supplierServiceProvider).delete(widget.supplierId);
      if (mounted) context.go('/suppliers');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null || _supplier == null) {
      return Center(
        child: Text(_error ?? 'Error', style: AppTextStyles.bodyMedium),
      );
    }
    final s = _supplier!;
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
              Expanded(
                child: Text(s.name, style: AppTextStyles.displayMedium),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/suppliers/${s.id}/edit'),
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
            title: 'Identity',
            child: _grid([
              _row('Code', s.code),
              _row(
                'Contact Person',
                s.contactPerson.isEmpty ? '—' : s.contactPerson,
              ),
            ]),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Contact',
            child: _grid([
              _row('Email', s.email.isEmpty ? '—' : s.email),
              _row('Phone', s.phone.isEmpty ? '—' : s.phone),
              _row('Address', s.address.isEmpty ? '—' : s.address),
              _row('Country', s.country),
            ]),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Commercial Terms',
            child: _grid([
              _row('Currency', s.currency),
              _row('Payment Terms', '${s.paymentTermsDays} days'),
              _row('Credit Limit',
                  '${s.currency} ${s.creditLimit.toStringAsFixed(2)}'),
              _row('Opening Balance',
                  '${s.currency} ${s.openingBalance.toStringAsFixed(2)}'),
            ]),
          ),
          if (s.notes.isNotEmpty) ...[
            const SizedBox(height: 20),
            SectionCard(
              title: 'Notes',
              child: Text(s.notes, style: AppTextStyles.bodyMedium),
            ),
          ],
        ],
      ),
    );
  }

  Widget _grid(List<Widget> items) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 700 ? 2 : 1;
      return Wrap(
        spacing: 16,
        runSpacing: 14,
        children: items
            .map((w) => SizedBox(
                  width: (constraints.maxWidth - (cols - 1) * 16) / cols,
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