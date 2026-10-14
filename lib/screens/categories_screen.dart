import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../providers/category_provider.dart';
import '../services/category_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/form_field.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesStreamProvider);

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
                    Text('Chemical Categories',
                        style: AppTextStyles.displayMedium),
                    const SizedBox(height: 6),
                    Text('Acids, bases, solvents, aur baaki categories',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showForm(context, ref, null),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Add Category'),
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
              child: categories.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e', style: AppTextStyles.bodySmall),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: LucideIcons.tags,
                      title: 'Koi category nahi',
                      message:
                          'Categories se products ko organize karein. Jaise: Acids, Bases, Solvents.',
                      actionLabel: 'Pehli Category Banayein',
                      onAction: () => _showForm(context, ref, null),
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
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(LucideIcons.tag,
                              size: 16, color: AppColors.primary),
                        ),
                        title: Text(c.name,
                            style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          c.description.isEmpty ? 'No description' : c.description,
                          style: AppTextStyles.caption,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _showForm(context, ref, c),
                              icon: const Icon(LucideIcons.pencil, size: 16),
                              color: AppColors.textSecondary,
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              onPressed: () => _delete(context, ref, c),
                              icon: const Icon(LucideIcons.trash2, size: 16),
                              color: AppColors.error,
                              tooltip: 'Delete',
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

  void _showForm(BuildContext context, WidgetRef ref, Category? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');

    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                  existing == null ? 'Add Category' : 'Edit Category',
                  style: AppTextStyles.headingMedium,
                ),
                const SizedBox(height: 20),
                AppFormField(
                  label: 'Name',
                  controller: nameCtrl,
                  hint: 'Acids, Bases, Solvents...',
                  icon: LucideIcons.tag,
                  required: true,
                ),
                const SizedBox(height: 14),
                AppFormField(
                  label: 'Description',
                  controller: descCtrl,
                  hint: 'Short description',
                  icon: LucideIcons.fileText,
                  maxLines: 3,
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
                        if (nameCtrl.text.trim().isEmpty) return;
                        try {
                          final cat = Category(
                            id: existing?.id ?? '',
                            name: nameCtrl.text.trim(),
                            parentId: null,
                            description: descCtrl.text.trim(),
                            active: true,
                          );
                          if (existing == null) {
                            await ref.read(categoryServiceProvider).create(cat);
                          } else {
                            await ref
                                .read(categoryServiceProvider)
                                .update(existing.id, cat);
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
      BuildContext context, WidgetRef ref, Category c) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete category?',
      message: '${c.name} ko delete karein?',
      danger: true,
      confirmLabel: 'Delete',
    );
    if (ok) {
      await ref.read(categoryServiceProvider).delete(c.id);
    }
  }
}