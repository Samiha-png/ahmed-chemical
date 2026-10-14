import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../providers/customer_provider.dart';
import '../services/customer_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_dialog.dart';
import '../widgets/section_card.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  Customer? _customer;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c =
          await ref.read(customerServiceProvider).getById(widget.customerId);
      setState(() {
        _customer = c;
        _loading = false;
        if (c == null) _error = 'Customer not found';
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete customer?',
      message: 'Delete ${_customer!.name}?',
      danger: true,
      confirmLabel: 'Delete',
    );
    if (ok) {
      await ref.read(customerServiceProvider).delete(widget.customerId);
      if (mounted) context.go('/customers');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null || _customer == null) {
      return Center(
        child: Text(_error ?? 'Error', style: AppTextStyles.bodyMedium),
      );
    }
    final c = _customer!;
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
              Expanded(
                child: Text(c.name, style: AppTextStyles.displayMedium),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/customers/${c.id}/edit'),
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
              _row('Code', c.code),
              _row('Contact Person',
                  c.contactPerson.isEmpty ? '—' : c.contactPerson),
            ]),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Contact',
            child: _grid([
              _row('Email', c.email.isEmpty ? '—' : c.email),
              _row('Phone', c.phone.isEmpty ? '—' : c.phone),
              _row('Billing Address',
                  c.billingAddress.isEmpty ? '—' : c.billingAddress),
              _row('Shipping Address',
                  c.shippingAddress.isEmpty ? '—' : c.shippingAddress),
              _row('Country', c.country),
            ]),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Commercial Terms',
            child: _grid([
              _row('Currency', c.currency),
              _row('Payment Terms', '${c.paymentTermsDays} days'),
              _row('Credit Limit',
                  '${c.currency} ${c.creditLimit.toStringAsFixed(2)}'),
              _row('Opening Balance',
                  '${c.currency} ${c.openingBalance.toStringAsFixed(2)}'),
            ]),
          ),
          if (c.notes.isNotEmpty) ...[
            const SizedBox(height: 20),
            SectionCard(
              title: 'Notes',
              child: Text(c.notes, style: AppTextStyles.bodyMedium),
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
                  width:
                      (constraints.maxWidth - (cols - 1) * 16) / cols,
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