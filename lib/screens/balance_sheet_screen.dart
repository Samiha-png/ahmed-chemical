import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../providers/report_provider.dart';
import '../services/report_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_card.dart';

class BalanceSheetScreen extends ConsumerWidget {
  const BalanceSheetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bs = ref.watch(balanceSheetProvider);
    final asOf = ref.watch(balanceSheetAsOfProvider);

    return SingleChildScrollView(
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
                    Text('Balance Sheet',
                        style: AppTextStyles.displayMedium),
                    const SizedBox(height: 6),
                    Text('Assets = Liabilities + Equity',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: asOf,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now()
                        .add(const Duration(days: 365)),
                  );
                  if (d != null) {
                    ref
                        .read(balanceSheetAsOfProvider.notifier)
                        .state = d;
                  }
                },
                icon: const Icon(LucideIcons.calendar, size: 15),
                label: Text(
                  'As of ${asOf.year}-${asOf.month.toString().padLeft(2, '0')}-${asOf.day.toString().padLeft(2, '0')}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          bs.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (e, _) => Text('Error: $e',
                style: AppTextStyles.bodySmall),
            data: (data) {
              if (data.assets.isEmpty &&
                  data.liabilities.isEmpty &&
                  data.equity.isEmpty) {
                return const SectionCard(
                  title: 'Balance Sheet',
                  child: SizedBox(
                    height: 240,
                    child: EmptyState(
                      icon: LucideIcons.wallet,
                      title: 'No data yet',
                      message:
                          'Post journal entries to see the balance sheet.',
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  // Balance check
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: data.isBalanced
                          ? AppColors.primarySoft
                          : AppColors.errorSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: data.isBalanced
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : AppColors.error.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          data.isBalanced
                              ? LucideIcons.checkCircle
                              : LucideIcons.alertTriangle,
                          size: 18,
                          color: data.isBalanced
                              ? AppColors.primary
                              : AppColors.error,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            data.isBalanced
                                ? 'Balanced — Assets = Liabilities + Equity'
                                : 'Not balanced',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: data.isBalanced
                                  ? AppColors.primary
                                  : AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Assets',
                    child: Column(
                      children: [
                        ...data.assets.map((r) => _row(r)),
                        const SizedBox(height: 10),
                        _total('Total Assets', data.totalAssets,
                            color: AppColors.info),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Liabilities',
                    child: Column(
                      children: [
                        if (data.liabilities.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                            child: Text('No liabilities',
                                style: AppTextStyles.caption),
                          )
                        else
                          ...data.liabilities.map((r) => _row(r)),
                        const SizedBox(height: 10),
                        _total('Total Liabilities',
                            data.totalLiabilities,
                            color: AppColors.warning),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Equity',
                    child: Column(
                      children: [
                        ...data.equity.map((r) => _row(r)),
                        const SizedBox(height: 10),
                        _total('Total Equity', data.totalEquity,
                            color: AppColors.primary),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.elevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Assets',
                            style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.w700)),
                        Text(
                          'PKR ${data.totalAssets.toStringAsFixed(2)}',
                          style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.info),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _row(PLRow r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text('${r.accountCode} — ${r.accountName}',
                style: AppTextStyles.bodyMedium),
          ),
          Text(r.amount.toStringAsFixed(2),
              style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }

  Widget _total(String label, num amount, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: AppTextStyles.bodyLarge
                    .copyWith(fontWeight: FontWeight.w700)),
          ),
          Text(amount.toStringAsFixed(2),
              style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}