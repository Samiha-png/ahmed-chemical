import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../providers/warehouse_provider.dart';
import '../services/warehouse_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/form_field.dart';

class WarehousesScreen extends ConsumerWidget {
  const WarehousesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    Text('Warehouses', style: AppTextStyles.displayMedium),
                    const SizedBox(height: 6),
                    Text('Multiple storage locations manage karein',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showForm(context, ref, null),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Add Warehouse'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: warehouses.when(
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
                      title: 'Koi warehouse nahi',
                      message:
                          'Warehouses se stock locations manage karein. Jaise: Main Store, Karachi Depot.',
                      actionLabel: 'Pehla Warehouse Banayein',
                      onAction: () => _showForm(context, ref, null),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, i) {
                      final w = list[i];
                      return ListTile(
                        leading: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(LucideIcons.warehouse,
                              size: 16, color: AppColors.primary),
                        ),
                        title: Text(w.name,
                            style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text('${w.code} • ${w.location}',
                            style: AppTextStyles.caption),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _showForm(context, ref, w),
                              icon: const Icon(LucideIcons.pencil, size: 16),
                              color: AppColors.textSecondary,
                            ),
                            IconButton(
                              onPressed: () => _delete(context, ref, w),
                              icon: const Icon(LucideIcons.trash2, size: 16),
                              color: AppColors.error,
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

  void _showForm(BuildContext context, WidgetRef ref, Warehouse? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final locCtrl = TextEditingController(text: existing?.location ?? '');
    final mgrCtrl = TextEditingController(text: existing?.manager ?? '');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing == null ? 'Add Warehouse' : 'Edit Warehouse',
                  style: AppTextStyles.headingMedium,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: AppFormField(
                      label: 'Name', controller: nameCtrl,
                      hint: 'Main Store', icon: LucideIcons.warehouse,
                      required: true)),
                    const SizedBox(width: 12),
                    Expanded(child: AppFormField(
                      label: 'Code', controller: codeCtrl,
                      hint: 'WH-001', icon: LucideIcons.hash,
                      required: true)),
                  ],
                ),
                const SizedBox(height: 14),
                AppFormField(
                  label: 'Location', controller: locCtrl,
                  hint: 'Karachi, Pakistan',
                  icon: LucideIcons.mapPin),
                const SizedBox(height: 14),
                AppFormField(
                  label: 'Manager', controller: mgrCtrl,
                  hint: 'Manager ka naam',
                  icon: LucideIcons.user),
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
                        if (nameCtrl.text.trim().isEmpty ||
                            codeCtrl.text.trim().isEmpty) return;
                        try {
                          final w = Warehouse(
                            id: existing?.id ?? '',
                            name: nameCtrl.text.trim(),
                            code: codeCtrl.text.trim().toUpperCase(),
                            location: locCtrl.text.trim(),
                            manager: mgrCtrl.text.trim().isEmpty
                                ? null
                                : mgrCtrl.text.trim(),
                            active: true,
                          );
                          if (existing == null) {
                            await ref.read(warehouseServiceProvider).create(w);
                          } else {
                            await ref
                                .read(warehouseServiceProvider)
                                .update(existing.id, w);
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
    );
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, Warehouse w) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete warehouse?',
      message: '${w.name} ko delete karein?',
      danger: true,
      confirmLabel: 'Delete',
    );
    if (ok) {
      await ref.read(warehouseServiceProvider).delete(w.id);
    }
  }
}