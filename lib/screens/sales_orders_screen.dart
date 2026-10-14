import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/sales_order.dart';
import '../providers/sales_order_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/empty_state.dart';

class SalesOrdersScreen extends ConsumerWidget {
  const SalesOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(salesOrdersStreamProvider);
    final search = ref.watch(soSearchProvider);
    final status = ref.watch(soStatusFilterProvider);

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
                    Text('Sales Orders',
                        style: AppTextStyles.displayMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Customer orders before invoicing.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => context.go('/sales/new'),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('New Sales Order'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
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
                              .read(soSearchProvider.notifier)
                              .state = v,
                          style: AppTextStyles.bodyMedium,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            hintText: 'Search by SO number or customer...',
                            hintStyle: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textDim),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.elevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: status,
                    dropdownColor: AppColors.elevated,
                    style: AppTextStyles.bodyMedium,
                    hint: Text('All statuses',
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textDim)),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('All statuses')),
                      ...SOStatus.values.map((s) => DropdownMenuItem(
                            value: s.name,
                            child: Text(soStatusLabel(s)),
                          )),
                    ],
                    onChanged: (v) => ref
                        .read(soStatusFilterProvider.notifier)
                        .state = v,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: orders.when(
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
                      icon: LucideIcons.receipt,
                      title: search.isEmpty && status == null
                          ? 'No sales orders yet'
                          : 'No matching orders',
                      message: search.isEmpty && status == null
                          ? 'Create your first sales order to start selling.'
                          : 'Adjust your filters or search.',
                      actionLabel:
                          search.isEmpty && status == null ? 'New SO' : null,
                      onAction: search.isEmpty && status == null
                          ? () => context.go('/sales/new')
                          : null,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, i) {
                      final so = list[i];
                      return ListTile(
                        onTap: () => context.go('/sales/${so.id}'),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _statusColor(so.statusEnum)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _statusColor(so.statusEnum)
                                    .withValues(alpha: 0.35)),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            _statusIcon(so.statusEnum),
                            size: 16,
                            color: _statusColor(so.statusEnum),
                          ),
                        ),
                        title: Text(
                          '${so.number}  •  ${so.customerName}',
                          style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${so.lines.length} line(s)  •  ${soStatusLabel(so.statusEnum)}',
                          style: AppTextStyles.caption,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${so.currency} ${so.grandTotal.toStringAsFixed(2)}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary),
                            ),
                            Text(
                              so.currency == 'PKR'
                                  ? 'base'
                                  : 'base PKR ${so.baseTotal.toStringAsFixed(0)}',
                              style: AppTextStyles.caption,
                            ),
                          ],
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

  Color _statusColor(SOStatus s) {
    switch (s) {
      case SOStatus.draft:
        return AppColors.textDim;
      case SOStatus.confirmed:
        return AppColors.info;
      case SOStatus.partiallyInvoiced:
        return AppColors.warning;
      case SOStatus.invoiced:
        return AppColors.primary;
      case SOStatus.cancelled:
        return AppColors.error;
      case SOStatus.closed:
        return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(SOStatus s) {
    switch (s) {
      case SOStatus.draft:
        return LucideIcons.fileEdit;
      case SOStatus.confirmed:
        return LucideIcons.checkCircle;
      case SOStatus.partiallyInvoiced:
        return LucideIcons.receipt;
      case SOStatus.invoiced:
        return LucideIcons.receipt;
      case SOStatus.cancelled:
        return LucideIcons.xCircle;
      case SOStatus.closed:
        return LucideIcons.archive;
    }
  }
}