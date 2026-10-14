import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../providers/report_provider.dart';
import '../services/report_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_card.dart';

class TrialBalanceScreen extends ConsumerWidget {
  const TrialBalanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tb = ref.watch(trialBalanceProvider);
    final to = ref.watch(trialBalanceToProvider);

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
                    Text('Trial Balance',
                        style: AppTextStyles.displayMedium),
                    const SizedBox(height: 6),
                    Text('All accounts with debit and credit balances.',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              // As-of date picker
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: to,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now()
                        .add(const Duration(days: 365)),
                  );
                  if (d != null) {
                    ref
                        .read(trialBalanceToProvider.notifier)
                        .state = d;
                  }
                },
                icon: const Icon(LucideIcons.calendar, size: 15),
                label: Text(
                  'As of ${to.year}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          tb.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (e, _) => Text('Error: $e',
                style: AppTextStyles.bodySmall),
            data: (data) {
              if (data.rows.isEmpty) {
                return const SectionCard(
                  title: 'Trial Balance',
                  child: SizedBox(
                    height: 240,
                    child: EmptyState(
                      icon: LucideIcons.barChart3,
                      title: 'No data yet',
                      message:
                          'Post some journal entries to see the trial balance.',
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  // Balance indicator
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
                                ? 'Balanced — Total Debit = Total Credit'
                                : 'Not balanced — check your entries',
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
                    title: 'Accounts',
                    child: Column(
                      children: [
                        _header(),
                        const SizedBox(height: 8),
                        ...data.rows.map((r) => _row(r)),
                        const SizedBox(height: 12),
                        const Divider(
                            color: AppColors.border, height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text('Total',
                                  style: AppTextStyles.bodyLarge.copyWith(
                                      fontWeight: FontWeight.w700)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                data.totalDebit.toStringAsFixed(2),
                                style: AppTextStyles.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w700),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                data.totalCredit.toStringAsFixed(2),
                                style: AppTextStyles.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w700),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
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

  Widget _header() {
    return Row(
      children: [
        Expanded(
            flex: 3,
            child: Text('Account', style: AppTextStyles.label)),
        Expanded(
          flex: 2,
          child: Text('Debit',
              style: AppTextStyles.label, textAlign: TextAlign.right),
        ),
        Expanded(
          flex: 2,
          child: Text('Credit',
              style: AppTextStyles.label, textAlign: TextAlign.right),
        ),
      ],
    );
  }

  Widget _row(TrialBalanceRow r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${r.accountCode} — ${r.accountName}',
                    style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600)),
                Text(_typeLabel(r.type),
                    style: AppTextStyles.caption),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              r.debit > 0 ? r.debit.toStringAsFixed(2) : '—',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              r.credit > 0 ? r.credit.toStringAsFixed(2) : '—',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _typeLabel(dynamic type) {
    final s = type.toString().split('.').last;
    return s[0].toUpperCase() + s.substring(1);
  }
}