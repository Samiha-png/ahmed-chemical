import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/goods_receipt.dart';
import '../providers/goods_receipt_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/empty_state.dart';

class GoodsReceiptsScreen extends ConsumerWidget {
  const GoodsReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grns = ref.watch(goodsReceiptsStreamProvider);
    final search = ref.watch(grnSearchProvider);
    final status = ref.watch(grnStatusFilterProvider);

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
                    Text('Goods Receipts',
                        style: AppTextStyles.displayMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Record received stock from suppliers. Stock increases when posted.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () =>
                    context.go('/purchasing/receipts/new'),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('New GRN'),
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
                              .read(grnSearchProvider.notifier)
                              .state = v,
                          style: AppTextStyles.bodyMedium,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            hintText:
                                'Search by GRN, PO number, or supplier...',
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
                      ...GRNStatus.values.map((s) => DropdownMenuItem(
                            value: s.name,
                            child: Text(grnStatusLabel(s)),
                          )),
                    ],
                    onChanged: (v) => ref
                        .read(grnStatusFilterProvider.notifier)
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
              child: grns.when(
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
                      icon: LucideIcons.packagePlus,
                      title: search.isEmpty && status == null
                          ? 'No goods receipts yet'
                          : 'No matching receipts',
                      message: search.isEmpty && status == null
                          ? 'Create a GRN from an approved purchase order.'
                          : 'Adjust your filters or search.',
                      actionLabel:
                          search.isEmpty && status == null ? 'New GRN' : null,
                      onAction: search.isEmpty && status == null
                          ? () => context.go('/purchasing/receipts/new')
                          : null,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, i) {
                      final g = list[i];
                      return ListTile(
                        onTap: () => context
                            .go('/purchasing/receipts/${g.id}'),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _statusColor(g.statusEnum)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _statusColor(g.statusEnum)
                                    .withValues(alpha: 0.35)),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            _statusIcon(g.statusEnum),
                            size: 16,
                            color: _statusColor(g.statusEnum),
                          ),
                        ),
                        title: Text(
                          '${g.number}  •  ${g.supplierName}',
                          style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'PO: ${g.poNumber}  •  ${g.lines.length} line(s)  •  ${grnStatusLabel(g.statusEnum)}',
                          style: AppTextStyles.caption,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'PKR ${g.totalValue.toStringAsFixed(2)}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary),
                            ),
                            Text(g.warehouseName,
                                style: AppTextStyles.caption),
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

  Color _statusColor(GRNStatus s) {
    switch (s) {
      case GRNStatus.draft:
        return AppColors.textDim;
      case GRNStatus.posted:
        return AppColors.primary;
      case GRNStatus.cancelled:
        return AppColors.error;
    }
  }

  IconData _statusIcon(GRNStatus s) {
    switch (s) {
      case GRNStatus.draft:
        return LucideIcons.fileEdit;
      case GRNStatus.posted:
        return LucideIcons.packageCheck;
      case GRNStatus.cancelled:
        return LucideIcons.xCircle;
    }
  }
}