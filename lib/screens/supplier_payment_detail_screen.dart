import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/supplier_payment.dart';
import '../providers/auth_provider.dart';
import '../providers/supplier_payment_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_dialog.dart';
import '../widgets/section_card.dart';

class SupplierPaymentDetailScreen extends ConsumerStatefulWidget {
  final String paymentId;
  const SupplierPaymentDetailScreen({super.key, required this.paymentId});

  @override
  ConsumerState<SupplierPaymentDetailScreen> createState() =>
      _SupplierPaymentDetailScreenState();
}

class _SupplierPaymentDetailScreenState
    extends ConsumerState<SupplierPaymentDetailScreen> {
  SupplierPayment? _payment;
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
      final p = await ref
          .read(supplierPaymentServiceProvider)
          .getById(widget.paymentId);
      setState(() {
        _payment = p;
        _loading = false;
        if (p == null) _error = 'Payment not found';
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _cancelPayment() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Cancel this payment?',
      message:
          'The payment will be reversed and bill allocations will be removed.',
      danger: true,
      confirmLabel: 'Cancel Payment',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(supplierPaymentServiceProvider)
          .cancel(widget.paymentId);
      await _load();
      _snack('Payment cancelled');
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
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
    if (_error != null || _payment == null) {
      return Center(
        child: Text(_error ?? 'Error', style: AppTextStyles.bodyMedium),
      );
    }
    final p = _payment!;
    final isPosted = p.statusEnum == PaymentStatus.posted;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.go('/purchasing/payments'),
                icon: const Icon(LucideIcons.arrowLeft, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.number, style: AppTextStyles.displayMedium),
                    const SizedBox(height: 4),
                    Text(p.supplierName,
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              if (isPosted)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _cancelPayment,
                  icon: const Icon(LucideIcons.xCircle, size: 15),
                  label: const Text('Cancel Payment'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Details',
            child: _grid([
              _row('Status', paymentStatusLabel(p.statusEnum)),
              _row('Method', p.method),
              _row('Reference',
                  p.reference.isEmpty ? '—' : p.reference),
              _row('Currency',
                  '${p.currency}  (Rate: ${p.exchangeRate})'),
              _row(
                'Payment Date',
                p.paymentDate == null
                    ? '—'
                    : '${p.paymentDate!.year}-${p.paymentDate!.month.toString().padLeft(2, '0')}-${p.paymentDate!.day.toString().padLeft(2, '0')}',
              ),
              _row('Base Amount (PKR)',
                  'PKR ${p.baseAmount.toStringAsFixed(2)}'),
            ]),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Amount',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Payment Amount',
                    style: AppTextStyles.bodyLarge
                        .copyWith(fontWeight: FontWeight.w700)),
                Text(
                  '${p.currency} ${p.amount.toStringAsFixed(2)}',
                  style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary),
                ),
              ],
            ),
          ),
          if (p.allocations.isNotEmpty) ...[
            const SizedBox(height: 20),
            SectionCard(
              title: 'Allocations',
              child: Column(
                children: p.allocations
                    .map((a) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(a.billNumber,
                                  style: AppTextStyles.bodyMedium),
                              Text(
                                '${p.currency} ${a.amount.toStringAsFixed(2)}',
                                style: AppTextStyles.bodyMedium
                                    .copyWith(
                                        fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
          if (p.notes.isNotEmpty) ...[
            const SizedBox(height: 20),
            SectionCard(
              title: 'Notes',
              child: Text(p.notes, style: AppTextStyles.bodyMedium),
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
}