import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/sales_invoice.dart';
import '../providers/sales_invoice_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/empty_state.dart';

class SalesInvoicesScreen extends ConsumerWidget {
  const SalesInvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(salesInvoicesStreamProvider);
    final search = ref.watch(invoiceSearchProvider);
    final status = ref.watch(invoiceStatusFilterProvider);

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
                    Text('Sales Invoices',
                        style: AppTextStyles.displayMedium),
                    const SizedBox(height: 6),
                    Text('Posted invoices deduct stock automatically.',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => context.go('/invoices/new'),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('New Invoice'),
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
                              .read(invoiceSearchProvider.notifier)
                              .state = v,
                          style: AppTextStyles.bodyMedium,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            hintText: 'Search by invoice number or customer...',
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
                      ...InvoiceStatus.values.map((s) => DropdownMenuItem(
                            value: s.name,
                            child: Text(invoiceStatusLabel(s)),
                          )),
                    ],
                    onChanged: (v) => ref
                        .read(invoiceStatusFilterProvider.notifier)
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
              child: invoices.when(
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
                          ? 'No invoices yet'
                          : 'No matching invoices',
                      message: search.isEmpty && status == null
                          ? 'Create your first sales invoice.'
                          : 'Adjust your filters or search.',
                      actionLabel: search.isEmpty && status == null
                          ? 'New Invoice'
                          : null,
                      onAction: search.isEmpty && status == null
                          ? () => context.go('/invoices/new')
                          : null,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, i) {
                      final inv = list[i];
                      return ListTile(
                        onTap: () => context.go('/invoices/${inv.id}'),
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: _statusColor(inv.statusEnum)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _statusColor(inv.statusEnum)
                                    .withValues(alpha: 0.35)),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            _statusIcon(inv.statusEnum),
                            size: 16,
                            color: _statusColor(inv.statusEnum),
                          ),
                        ),
                        title: Text(
                          '${inv.number}  •  ${inv.customerName}',
                          style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${invoiceStatusLabel(inv.statusEnum)}  •  ${inv.lines.length} line(s)',
                          style: AppTextStyles.caption,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${inv.currency} ${inv.grandTotal.toStringAsFixed(2)}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary),
                            ),
                            if (inv.outstanding > 0)
                              Text(
                                'Due: ${inv.currency} ${inv.outstanding.toStringAsFixed(0)}',
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

  Color _statusColor(InvoiceStatus s) {
    switch (s) {
      case InvoiceStatus.draft:
        return AppColors.textDim;
      case InvoiceStatus.posted:
        return AppColors.info;
      case InvoiceStatus.partiallyPaid:
        return AppColors.warning;
      case InvoiceStatus.paid:
        return AppColors.primary;
      case InvoiceStatus.cancelled:
        return AppColors.error;
    }
  }

  IconData _statusIcon(InvoiceStatus s) {
    switch (s) {
      case InvoiceStatus.draft:
        return LucideIcons.fileEdit;
      case InvoiceStatus.posted:
        return LucideIcons.checkCircle;
      case InvoiceStatus.partiallyPaid:
        return LucideIcons.clock;
      case InvoiceStatus.paid:
        return LucideIcons.checkCircle2;
      case InvoiceStatus.cancelled:
        return LucideIcons.xCircle;
    }
  }
}