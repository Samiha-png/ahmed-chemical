import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/supplier_bill.dart';
import '../providers/supplier_bill_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/empty_state.dart';

class SupplierBillsScreen extends ConsumerWidget {
  const SupplierBillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(supplierBillsStreamProvider);
    final search = ref.watch(billSearchProvider);
    final status = ref.watch(billStatusFilterProvider);

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
                    Text('Supplier Bills',
                        style: AppTextStyles.displayMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Bills received from suppliers. Payments reduce outstanding.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => context.go('/purchasing/bills/new'),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('New Bill'),
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
                              .read(billSearchProvider.notifier)
                              .state = v,
                          style: AppTextStyles.bodyMedium,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            hintText:
                                'Search by bill number, supplier, or ref...',
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
                      ...BillStatus.values.map((s) => DropdownMenuItem(
                            value: s.name,
                            child: Text(billStatusLabel(s)),
                          )),
                    ],
                    onChanged: (v) => ref
                        .read(billStatusFilterProvider.notifier)
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
              child: bills.when(
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
                      icon: LucideIcons.fileText,
                      title: search.isEmpty && status == null
                          ? 'No supplier bills yet'
                          : 'No matching bills',
                      message: search.isEmpty && status == null
                          ? 'Create your first supplier bill.'
                          : 'Adjust your filters or search.',
                      actionLabel: search.isEmpty && status == null
                          ? 'New Bill'
                          : null,
                      onAction: search.isEmpty && status == null
                          ? () => context.go('/purchasing/bills/new')
                          : null,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, i) {
                      final b = list[i];
                      return ListTile(
                        onTap: () =>
                            context.go('/purchasing/bills/${b.id}'),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _statusColor(b.statusEnum)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _statusColor(b.statusEnum)
                                    .withValues(alpha: 0.35)),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            _statusIcon(b.statusEnum),
                            size: 16,
                            color: _statusColor(b.statusEnum),
                          ),
                        ),
                        title: Text(
                          '${b.number}  •  ${b.supplierName}',
                          style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${billStatusLabel(b.statusEnum)}  •  ${b.lines.length} line(s)',
                          style: AppTextStyles.caption,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${b.currency} ${b.grandTotal.toStringAsFixed(2)}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary),
                            ),
                            if (b.outstanding > 0)
                              Text(
                                'Due: ${b.currency} ${b.outstanding.toStringAsFixed(0)}',
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.warning),
                              )
                            else
                              Text('Paid',
                                  style: AppTextStyles.caption.copyWith(
                                      color: AppColors.primary)),
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

  Color _statusColor(BillStatus s) {
    switch (s) {
      case BillStatus.draft:
        return AppColors.textDim;
      case BillStatus.posted:
        return AppColors.info;
      case BillStatus.partiallyPaid:
        return AppColors.warning;
      case BillStatus.paid:
        return AppColors.primary;
      case BillStatus.cancelled:
        return AppColors.error;
    }
  }

  IconData _statusIcon(BillStatus s) {
    switch (s) {
      case BillStatus.draft:
        return LucideIcons.fileEdit;
      case BillStatus.posted:
        return LucideIcons.checkCircle;
      case BillStatus.partiallyPaid:
        return LucideIcons.clock;
      case BillStatus.paid:
        return LucideIcons.checkCircle2;
      case BillStatus.cancelled:
        return LucideIcons.xCircle;
    }
  }
}