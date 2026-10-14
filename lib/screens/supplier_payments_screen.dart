import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/supplier_payment.dart';
import '../providers/supplier_payment_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/empty_state.dart';

class SupplierPaymentsScreen extends ConsumerWidget {
  const SupplierPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(supplierPaymentsStreamProvider);
    final search = ref.watch(paymentSearchProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Supplier Payments',
                        style: AppTextStyles.displayMedium),
                    const SizedBox(height: 6),
                    Text('Record payments made to suppliers.',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () =>
                    context.go('/purchasing/payments/new'),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('New Payment'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(LucideIcons.search,
                    size: 15, color: AppColors.textDim),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: (v) => ref
                        .read(paymentSearchProvider.notifier)
                        .state = v,
                    style: AppTextStyles.bodyMedium,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      hintText: 'Search by payment # or supplier...',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textDim),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: payments.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: AppTextStyles.bodySmall),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: LucideIcons.dollarSign,
                      title: search.isEmpty
                          ? 'No payments yet'
                          : 'No matching payments',
                      message: search.isEmpty
                          ? 'Record your first supplier payment.'
                          : 'Try a different search.',
                      actionLabel: search.isEmpty ? 'New Payment' : null,
                      onAction: search.isEmpty
                          ? () => context.go('/purchasing/payments/new')
                          : null,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, i) {
                      final p = list[i];
                      return ListTile(
                        onTap: () => context
                            .go('/purchasing/payments/${p.id}'),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(LucideIcons.dollarSign,
                              size: 16, color: AppColors.primary),
                        ),
                        title: Text(
                          '${p.number}  •  ${p.supplierName}',
                          style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${p.method}  •  ${p.allocations.length} allocation(s)',
                          style: AppTextStyles.caption,
                        ),
                        trailing: Text(
                          '${p.currency} ${p.amount.toStringAsFixed(2)}',
                          style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}