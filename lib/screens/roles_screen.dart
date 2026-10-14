import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/role.dart';
import '../providers/role_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_dialog.dart';
import '../widgets/empty_state.dart';

class RolesScreen extends ConsumerWidget {
  const RolesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(rolesStreamProvider);

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
                    Text('Roles & Permissions',
                        style: AppTextStyles.displayMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Create custom roles and assign granular permissions.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _seedRoles(context, ref),
                icon: const Icon(LucideIcons.download, size: 16),
                label: const Text('Seed Defaults'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => context.go('/roles/new'),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('New Role'),
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
              child: roles.when(
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
                      icon: LucideIcons.shieldCheck,
                      title: 'No roles yet',
                      message:
                          'Start with the 8 default roles, or create your own.',
                      actionLabel: 'Seed Default Roles',
                      onAction: () => _seedRoles(context, ref),
                    );
                  }
                  // System roles first, then custom
                  final systemRoles =
                      list.where((r) => r.isSystem).toList();
                  final customRoles =
                      list.where((r) => !r.isSystem).toList();

                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (systemRoles.isNotEmpty) ...[
                        _sectionLabel('System Roles'),
                        ...systemRoles.map((r) => _RoleTile(
                              role: r,
                              ref: ref,
                            )),
                        const SizedBox(height: 20),
                      ],
                      if (customRoles.isNotEmpty) ...[
                        _sectionLabel('Custom Roles'),
                        ...customRoles.map((r) => _RoleTile(
                              role: r,
                              ref: ref,
                            )),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          letterSpacing: 1,
          fontWeight: FontWeight.w700,
          color: AppColors.textDim,
        ),
      ),
    );
  }

  Future<void> _seedRoles(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Seed default roles?',
      message:
          'This adds 8 default roles (Super Admin, Director, Accountant, etc.). Only works if roles are empty.',
      confirmLabel: 'Seed',
    );
    if (!ok) return;
    try {
      final did = await ref.read(roleServiceProvider).seedDefaultRoles();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(did
              ? 'Default roles created'
              : 'Roles already exist — not seeded'),
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
}

class _RoleTile extends StatelessWidget {
  final Role role;
  final WidgetRef ref;

  const _RoleTile({required this.role, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: role.isSystem
                  ? AppColors.info.withValues(alpha: 0.15)
                  : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: role.isSystem
                    ? AppColors.info.withValues(alpha: 0.4)
                    : AppColors.primary.withValues(alpha: 0.4),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              role.isSystem
                  ? LucideIcons.shieldCheck
                  : LucideIcons.shield,
              size: 18,
              color:
                  role.isSystem ? AppColors.info : AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        role.name,
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (role.isSystem) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'System',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.info,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(role.description,
                    style: AppTextStyles.caption),
                const SizedBox(height: 4),
                Text(
                  '${role.permissions.length} permission(s)',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.textDim),
                ),
              ],
            ),
          ),
          // Actions
          if (!role.isSystem) ...[
            IconButton(
              onPressed: () => context.go('/roles/${role.id}'),
              icon: const Icon(LucideIcons.pencil, size: 16),
              color: AppColors.textSecondary,
              tooltip: 'Edit',
            ),
            IconButton(
              onPressed: () => _delete(context, ref),
              icon: const Icon(LucideIcons.trash2, size: 16),
              color: AppColors.error,
              tooltip: 'Delete',
            ),
          ] else
            IconButton(
              onPressed: () => context.go('/roles/${role.id}'),
              icon: const Icon(LucideIcons.eye, size: 16),
              color: AppColors.textSecondary,
              tooltip: 'View',
            ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete role?',
      message: 'Delete "${role.name}"? This cannot be undone.',
      danger: true,
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await ref.read(roleServiceProvider).delete(role.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }
}