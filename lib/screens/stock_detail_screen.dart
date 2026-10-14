import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../providers/inventory_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/empty_state.dart';
import '../widgets/inventory_widgets.dart';
import '../widgets/section_card.dart';

class StockDetailScreen extends ConsumerWidget {
  final String productId;
  final String? warehouseId;
  const StockDetailScreen({
    super.key,
    required this.productId,
    this.warehouseId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movements = ref.watch(movementsProvider(
      (productId: productId, warehouseId: warehouseId),
    ));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.go('/inventory'),
                icon: const Icon(LucideIcons.arrowLeft, size: 18),
              ),
              const SizedBox(width: 8),
              Text('Stock Movement History',
                  style: AppTextStyles.displayMedium),
            ],
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Movement History',
            subtitle: 'Latest 100 movements',
            child: movements.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (e, _) => Text('Error: $e',
                  style: AppTextStyles.bodySmall),
              data: (list) {
                if (list.isEmpty) {
                  return const SizedBox(
                    height: 180,
                    child: EmptyState(
                      icon: LucideIcons.history,
                      title: 'No movements yet',
                      message:
                          'Stock movements will appear here once you receive, adjust, or transfer stock.',
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, i) {
                    final m = list[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    MovementTypeChip(type: m.type),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        m.warehouseName,
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                                fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if (m.reason.isNotEmpty)
                                  Text('Reason: ${m.reason}',
                                      style: AppTextStyles.caption),
                                if (m.reference != null &&
                                    m.reference!.isNotEmpty)
                                  Text('Ref: ${m.reference}',
                                      style: AppTextStyles.caption),
                                Text(
                                  m.createdAt == null
                                      ? '—'
                                      : '${m.createdAt!.year}-${m.createdAt!.month.toString().padLeft(2, '0')}-${m.createdAt!.day.toString().padLeft(2, '0')} ${m.createdAt!.hour.toString().padLeft(2, '0')}:${m.createdAt!.minute.toString().padLeft(2, '0')}',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          QtyText(
                              value: m.quantity,
                              unit: 'units'),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '@ PKR ${m.unitCost.toStringAsFixed(2)}',
                                style: AppTextStyles.caption,
                              ),
                              Text(
                                'PKR ${m.totalValue.toStringAsFixed(0)}',
                                style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}