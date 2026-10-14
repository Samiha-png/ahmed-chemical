import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../providers/customer_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/empty_state.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersStreamProvider);
    final search = ref.watch(customerSearchProvider);

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
                    Text('Customers', style: AppTextStyles.displayMedium),
                    const SizedBox(height: 6),
                    Text('Manage customer profiles, terms, and contacts',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => context.go('/customers/new'),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Add Customer'),
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
                    onChanged: (v) =>
                        ref.read(customerSearchProvider.notifier).state = v,
                    style: AppTextStyles.bodyMedium,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      hintText: 'Search by name, code, or email...',
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
              child: customers.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e', style: AppTextStyles.bodySmall),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: LucideIcons.users,
                      title: search.isEmpty
                          ? 'No customers yet'
                          : 'No results',
                      message: search.isEmpty
                          ? 'Add your first customer to start selling.'
                          : 'Try a different search.',
                      actionLabel: search.isEmpty ? 'Add Customer' : null,
                      onAction: search.isEmpty
                          ? () => context.go('/customers/new')
                          : null,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, i) {
                      final c = list[i];
                      return ListTile(
                        onTap: () => context.go('/customers/${c.id}'),
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            c.name.isNotEmpty
                                ? c.name[0].toUpperCase()
                                : '?',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        title: Text(c.name,
                            style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${c.code} • ${c.country} • ${c.currency}',
                          style: AppTextStyles.caption,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${c.paymentTermsDays} days',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600),
                            ),
                            Text('terms', style: AppTextStyles.caption),
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
}