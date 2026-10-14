import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/account.dart';
import '../providers/account_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/form_field.dart';
import '../widgets/section_card.dart';

class ChartOfAccountsScreen extends ConsumerWidget {
  const ChartOfAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(chartOfAccountsProvider);
    final typeFilter = ref.watch(accountTypeFilterProvider);

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
                    Text('Chart of Accounts',
                        style: AppTextStyles.displayMedium),
                    const SizedBox(height: 6),
                    Text(
                      'All accounts used for double-entry bookkeeping.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _seedCOA(context, ref),
                icon: const Icon(LucideIcons.download, size: 16),
                label: const Text('Seed Defaults'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showAccountForm(context, ref, null),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Add Account'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Type filter
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.filter,
                    size: 15, color: AppColors.textDim),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<AccountType?>(
                    value: typeFilter,
                    dropdownColor: AppColors.elevated,
                    style: AppTextStyles.bodyMedium,
                    hint: Text('All types',
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textDim)),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('All types')),
                      ...AccountType.values.map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(accountTypeLabel(t)),
                          )),
                    ],
                    onChanged: (v) => ref
                        .read(accountTypeFilterProvider.notifier)
                        .state = v,
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
              child: accounts.when(
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
                      icon: LucideIcons.bookOpen,
                      title: 'No accounts yet',
                      message:
                          'Start with the default Chart of Accounts by clicking "Seed Defaults".',
                      actionLabel: 'Seed Defaults',
                      onAction: () => _seedCOA(context, ref),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, i) {
                      final a = list[i];
                      return ListTile(
                        onTap: () => _showAccountForm(context, ref, a),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _typeColor(a.type)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            a.code,
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: _typeColor(a.type),
                              fontSize: 10,
                            ),
                          ),
                        ),
                        title: Text(a.name,
                            style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${accountTypeLabel(a.type)}  •  Normal: ${normalBalanceLabel(a.normalBalance)}',
                          style: AppTextStyles.caption,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (a.isSystem)
                              const Icon(LucideIcons.lock,
                                  size: 14, color: AppColors.textDim),
                            if (!a.isSystem) ...[
                              IconButton(
                                onPressed: () =>
                                    _delete(context, ref, a),
                                icon: const Icon(LucideIcons.trash2,
                                    size: 14),
                                color: AppColors.error,
                              ),
                            ],
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

  Color _typeColor(AccountType t) {
    switch (t) {
      case AccountType.asset:
        return AppColors.info;
      case AccountType.liability:
        return AppColors.warning;
      case AccountType.equity:
        return AppColors.primary;
      case AccountType.revenue:
        return const Color(0xFF10B981);
      case AccountType.expense:
        return AppColors.error;
    }
  }

  Future<void> _seedCOA(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Seed default Chart of Accounts?',
      message:
          'This adds ~30 default accounts (Cash, Bank, AR, AP, Revenue, Expenses, etc.). Only works if the chart is empty.',
      confirmLabel: 'Seed',
    );
    if (!ok) return;
    try {
      final didSeed =
          await ref.read(accountServiceProvider).seedDefaultCOA();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(didSeed
              ? 'Default Chart of Accounts created.'
              : 'Chart already has accounts — not seeded.'),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  void _showAccountForm(
      BuildContext context, WidgetRef ref, Account? existing) {
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    AccountType selectedType = existing?.type ?? AccountType.asset;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSt) => Dialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    existing == null ? 'Add Account' : 'Edit Account',
                    style: AppTextStyles.headingMedium,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: AppFormField(
                          label: 'Code',
                          controller: codeCtrl,
                          hint: '1000',
                          icon: LucideIcons.hash,
                          required: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: AppFormField(
                          label: 'Name',
                          controller: nameCtrl,
                          hint: 'Cash in Hand',
                          icon: LucideIcons.bookOpen,
                          required: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('Type', style: AppTextStyles.label),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.elevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<AccountType>(
                        value: selectedType,
                        isExpanded: true,
                        dropdownColor: AppColors.elevated,
                        style: AppTextStyles.bodyMedium,
                        items: AccountType.values
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(accountTypeLabel(t)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setSt(() => selectedType = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppFormField(
                    label: 'Description',
                    controller: descCtrl,
                    hint: 'Optional',
                    icon: LucideIcons.fileText,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Normal balance: ${normalBalanceLabel(normalBalanceFor(selectedType))}',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          if (codeCtrl.text.trim().isEmpty ||
                              nameCtrl.text.trim().isEmpty) {
                            return;
                          }
                          try {
                            final acc = Account(
                              id: existing?.id ?? '',
                              code: codeCtrl.text.trim(),
                              name: nameCtrl.text.trim(),
                              type: selectedType,
                              description: descCtrl.text.trim(),
                              isSystem: existing?.isSystem ?? false,
                              active: true,
                            );
                            if (existing == null) {
                              await ref
                                  .read(accountServiceProvider)
                                  .create(acc);
                            } else {
                              await ref
                                  .read(accountServiceProvider)
                                  .update(existing.id, acc);
                            }
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                        child: Text(existing == null ? 'Create' : 'Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, Account a) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete account?',
      message: 'Delete ${a.code} — ${a.name}?',
      danger: true,
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await ref.read(accountServiceProvider).delete(a.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}