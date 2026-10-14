import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../providers/supplier_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/empty_state.dart';

class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(suppliersStreamProvider);
    final search = ref.watch(supplierSearchProvider);

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
                    Text('Suppliers', style: AppTextStyles.displayMedium),
                    const SizedBox(height: 6),
                    Text('Manage supplier profiles, terms, and contacts',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => context.go('/suppliers/new'),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Add Supplier'),
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
                        ref.read(supplierSearchProvider.notifier).state = v,
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
              child: suppliers.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e', style: AppTextStyles.bodySmall),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: LucideIcons.truck,
                      title: search.isEmpty
                          ? 'No suppliers yet'
                          : 'No results',
                      message: search.isEmpty
                          ? 'Add your first supplier to start purchasing.'
                          : 'Try a different search.',
                      actionLabel: search.isEmpty ? 'Add Supplier' : null,
                      onAction: search.isEmpty
                          ? () => context.go('/suppliers/new')
                          : null,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, i) {
                      final s = list[i];
                      return ListTile(
                        onTap: () => context.go('/suppliers/${s.id}'),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            s.name.isNotEmpty
                                ? s.name[0].toUpperCase()
                                : '?',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        title: Text(
                          s.name,
                          style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${s.code} • ${s.country} • ${s.currency}',
                          style: AppTextStyles.caption,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${s.paymentTermsDays} days',
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