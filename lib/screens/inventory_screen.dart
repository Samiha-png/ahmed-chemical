import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../providers/inventory_provider.dart';
import '../providers/warehouse_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/empty_state.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(stockBalancesProvider);
    final search = ref.watch(inventorySearchProvider);
    final whFilter = ref.watch(inventoryWarehouseFilterProvider);
    final warehouses = ref.watch(warehousesStreamProvider);

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
                    Text('Inventory', style: AppTextStyles.displayMedium),
                    const SizedBox(height: 6),
                    Text('Stock balances across warehouses',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/inventory/receive'),
                icon: const Icon(LucideIcons.arrowDownToLine, size: 16),
                label: const Text('Receive Stock'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => context.go('/inventory/adjust'),
                icon: const Icon(LucideIcons.sliders, size: 16),
                label: const Text('Adjust'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => context.go('/inventory/transfer'),
                icon: const Icon(LucideIcons.arrowLeftRight, size: 16),
                label: const Text('Transfer'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filters
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
                              .read(inventorySearchProvider.notifier)
                              .state = v,
                          style: AppTextStyles.bodyMedium,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            hintText: 'Search by name or SKU...',
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
                  child: warehouses.when(
                    loading: () => const SizedBox(width: 120),
                    error: (_, _) => const SizedBox(width: 120),
                    data: (list) => DropdownButton<String?>(
                      value: whFilter,
                      dropdownColor: AppColors.elevated,
                      style: AppTextStyles.bodyMedium,
                      hint: Text('All warehouses',
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textDim)),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('All warehouses')),
                        ...list.map((w) => DropdownMenuItem(
                              value: w.id,
                              child: Text(w.name),
                            )),
                      ],
                      onChanged: (v) => ref
                          .read(inventoryWarehouseFilterProvider.notifier)
                          .state = v,
                    ),
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
              child: balances.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e', style: AppTextStyles.bodySmall),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: LucideIcons.warehouse,
                      title: search.isEmpty
                          ? 'No stock yet'
                          : 'No results',
                      message: search.isEmpty
                          ? 'Receive stock to start tracking inventory.'
                          : 'Try a different search.',
                      actionLabel: search.isEmpty ? 'Receive Stock' : null,
                      onAction: search.isEmpty
                          ? () => context.go('/inventory/receive')
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
                        onTap: () => context.go(
                            '/inventory/product/${b.productId}?wh=${b.warehouseId}'),
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: b.isLowStock
                                ? AppColors.errorSoft
                                : AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            b.isLowStock
                                ? LucideIcons.alertTriangle
                                : LucideIcons.package,
                            size: 18,
                            color: b.isLowStock
                                ? AppColors.error
                                : AppColors.primary,
                          ),
                        ),
                        title: Text(b.productName,
                            style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${b.sku} • ${b.warehouseName}',
                          style: AppTextStyles.caption,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${b.quantity.toStringAsFixed(2)} ${b.baseUnit}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: b.isLowStock
                                    ? AppColors.error
                                    : AppColors.primary,
                              ),
                            ),
                            Text(
                              'PKR ${b.totalValue.toStringAsFixed(0)}',
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
}