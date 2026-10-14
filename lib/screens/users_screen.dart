import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/role.dart';
import '../providers/auth_provider.dart';
import '../providers/role_provider.dart';
import '../providers/user_provider.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_dialog.dart';
import '../widgets/empty_state.dart';

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersStreamProvider);
    final roles = ref.watch(rolesStreamProvider);
    final currentUid = ref.watch(authServiceProvider).currentUser?.uid;

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
                    Text('Users & Permissions',
                        style: AppTextStyles.displayMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Manage users, assign roles, and control access.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
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
              child: users.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: AppTextStyles.bodySmall),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const EmptyState(
                      icon: LucideIcons.users,
                      title: 'No users yet',
                      message:
                          'When people sign up, they will appear here.',
                    );
                  }
                  return roles.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    ),
                    error: (e, _) => Center(
                      child: Text('Error loading roles: $e',
                          style: AppTextStyles.bodySmall),
                    ),
                    data: (roleList) {
                      // Fallback: if roles collection is empty, use
                      // system defaults from DefaultRoles.
                      final effectiveRoles = roleList.isEmpty
                          ? DefaultRoles.seed()
                          : roleList;

                      return ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const Divider(
                            height: 1, color: AppColors.border),
                        itemBuilder: (context, i) {
                          final u = list[i];
                          final isMe = u.uid == currentUid;
                          return _UserRow(
                            user: u,
                            isMe: isMe,
                            ref: ref,
                            roles: effectiveRoles,
                          );
                        },
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

class _UserRow extends StatelessWidget {
  final AppUser user;
  final bool isMe;
  final WidgetRef ref;
  final List<Role> roles;

  const _UserRow({
    required this.user,
    required this.isMe,
    required this.ref,
    required this.roles,
  });

  @override
  Widget build(BuildContext context) {
    // Guard: if the user's role is not in the roles list (e.g. deleted
    // custom role), fall back to null so the dropdown doesn't crash.
    final roleIds = roles.map((r) => r.id).toSet();
    final safeRoleValue =
        roleIds.contains(user.role) ? user.role : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              (user.fullName.isNotEmpty
                      ? user.fullName[0]
                      : user.email.isNotEmpty
                          ? user.email[0]
                          : '?')
                  .toUpperCase(),
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Name + email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.fullName.isEmpty
                            ? '(no name)'
                            : user.fullName,
                        style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'You',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(user.email, style: AppTextStyles.caption),
              ],
            ),
          ),

          // Role dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: safeRoleValue,
                dropdownColor: AppColors.elevated,
                style: AppTextStyles.bodySmall,
                icon: const Icon(LucideIcons.chevronDown, size: 14),
                hint: Text(
                  'Select role',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textDim),
                ),
                items: roles
                    .map((r) => DropdownMenuItem<String>(
                          value: r.id,
                          child: Text(r.name),
                        ))
                    .toList(),
                onChanged: isMe
                    ? null
                    : (v) {
                        if (v == null) return;
                        ref
                            .read(userServiceProvider)
                            .updateRole(user.uid, v);
                      },
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Active switch
          Tooltip(
            message: user.active ? 'Active' : 'Inactive',
            child: Switch(
              value: user.active,
              activeThumbColor: AppColors.primary,
              onChanged: isMe
                  ? null
                  : (v) async {
                      final ok = await showConfirmDialog(
                        context,
                        title: v ? 'Activate user?' : 'Deactivate user?',
                        message: v
                            ? 'Activate ${user.email}?'
                            : 'Deactivate ${user.email}? They will not be able to log in.',
                        danger: !v,
                      );
                      if (ok) {
                        ref
                            .read(userServiceProvider)
                            .toggleActive(user.uid, v);
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }
}