import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../providers/report_provider.dart';
import '../services/report_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_card.dart';

class ProfitLossScreen extends ConsumerWidget {
  const ProfitLossScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pl = ref.watch(profitAndLossProvider);
    final range = ref.watch(plRangeProvider);

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
                    Text('Profit & Loss',
                        style: AppTextStyles.displayMedium),
                    const SizedBox(height: 6),
                    Text('Revenue minus expenses for the period.',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    initialDateRange: DateTimeRange(
                        start: range.from, end: range.to),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now()
                        .add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    ref.read(plRangeProvider.notifier).state = DateRange(
                      from: picked.start,
                      to: picked.end,
                    );
                  }
                },
                icon: const Icon(LucideIcons.calendar, size: 15),
                label: Text(
                  '${_fmt(range.from)} — ${_fmt(range.to)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          pl.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (e, _) => Text('Error: $e',
                style: AppTextStyles.bodySmall),
            data: (data) {
              if (data.revenues.isEmpty && data.expenses.isEmpty) {
                return const SectionCard(
                  title: 'Profit & Loss',
                  child: SizedBox(
                    height: 240,
                    child: EmptyState(
                      icon: LucideIcons.trendingUp,
                      title: 'No data for this period',
                      message:
                          'Post revenue or expense journal entries to see the P&L.',
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  SectionCard(
                    title: 'Revenue',
                    child: Column(
                      children: [
                        ...data.revenues.map((r) => _row(r)),
                        const SizedBox(height: 10),
                        _total('Total Revenue', data.totalRevenue,
                            color: AppColors.primary),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Expenses',
                    child: Column(
                      children: [
                        ...data.expenses.map((r) => _row(r)),
                        const SizedBox(height: 10),
                        _total('Total Expenses', data.totalExpense,
                            color: AppColors.error),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: data.netProfit >= 0
                          ? AppColors.primarySoft
                          : AppColors.errorSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: data.netProfit >= 0
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : AppColors.error.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          data.netProfit >= 0
                              ? LucideIcons.trendingUp
                              : LucideIcons.trendingDown,
                          color: data.netProfit >= 0
                              ? AppColors.primary
                              : AppColors.error,
                          size: 24,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.netProfit >= 0
                                    ? 'Net Profit'
                                    : 'Net Loss',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: data.netProfit >= 0
                                      ? AppColors.primary
                                      : AppColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'PKR ${data.netProfit.abs().toStringAsFixed(2)}',
                                style: AppTextStyles.displayMedium
                                    .copyWith(
                                  color: data.netProfit >= 0
                                      ? AppColors.primary
                                      : AppColors.error,
                                ),
                              ),
                            ],
                          ),
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

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}