import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/purchase_order.dart';
import '../providers/purchase_order_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/empty_state.dart';

class PurchaseOrdersScreen extends ConsumerWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(purchaseOrdersStreamProvider);
    final search = ref.watch(poSearchProvider);
    final status = ref.watch(poStatusFilterProvider);

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
                    Text('Purchase Orders',
                        style: AppTextStyles.displayMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Orders to suppliers. Stock is updated only when goods are received.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => context.go('/purchasing/new'),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('New Purchase Order'),
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
                              .read(poSearchProvider.notifier)
                              .state = v,
                          style: AppTextStyles.bodyMedium,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            hintText: 'Search by PO number or supplier...',
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
                      ...POStatus.values.map((s) => DropdownMenuItem(
                            value: s.name,
                            child: Text(poStatusLabel(s)),
                          )),
                    ],
                    onChanged: (v) => ref
                        .read(poStatusFilterProvider.notifier)
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
                      icon: LucideIcons.shoppingCart,
                      title: search.isEmpty && status == null
                          ? 'No purchase orders yet'
                          : 'No matching orders',
                      message: search.isEmpty && status == null
                          ? 'Create a purchase order to order from suppliers.'
                          : 'Adjust your filters or search.',
                      actionLabel:
                          search.isEmpty && status == null ? 'New PO' : null,
                      onAction: search.isEmpty && status == null
                          ? () => context.go('/purchasing/new')
                          : null,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, i) {
                      final po = list[i];
                      return ListTile(
                        onTap: () =>
                            context.go('/purchasing/${po.id}'),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _statusColor(po.statusEnum)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _statusColor(po.statusEnum)
                                    .withValues(alpha: 0.35)),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            _statusIcon(po.statusEnum),
                            size: 16,
                            color: _statusColor(po.statusEnum),
                          ),
                        ),
                        title: Text(
                          '${po.number}  •  ${po.supplierName}',
                          style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${po.lines.length} line(s)  •  ${poStatusLabel(po.statusEnum)}',
                          style: AppTextStyles.caption,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${po.currency} ${po.grandTotal.toStringAsFixed(2)}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary),
                            ),
                            Text(
                              po.currency == 'PKR'
                                  ? 'base'
                                  : 'base PKR ${po.baseTotal.toStringAsFixed(0)}',
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

  Color _statusColor(POStatus s) {
    switch (s) {
      case POStatus.draft:
        return AppColors.textDim;
      case POStatus.approved:
        return AppColors.info;
      case POStatus.partiallyReceived:
        return AppColors.warning;
      case POStatus.received:
        return AppColors.primary;
      case POStatus.cancelled:
        return AppColors.error;
      case POStatus.closed:
        return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(POStatus s) {
    switch (s) {
      case POStatus.draft:
        return LucideIcons.fileEdit;
      case POStatus.approved:
        return LucideIcons.checkCircle;
      case POStatus.partiallyReceived:
        return LucideIcons.packageOpen;
      case POStatus.received:
        return LucideIcons.packageCheck;
      case POStatus.cancelled:
        return LucideIcons.xCircle;
      case POStatus.closed:
        return LucideIcons.archive;
    }
  }
}