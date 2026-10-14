import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/permission.dart';
import '../models/role.dart';
import '../providers/role_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/form_field.dart';
import '../widgets/section_card.dart';

class RoleFormScreen extends ConsumerStatefulWidget {
  final String? roleId;
  const RoleFormScreen({super.key, this.roleId});

  @override
  ConsumerState<RoleFormScreen> createState() => _RoleFormScreenState();
}

class _RoleFormScreenState extends ConsumerState<RoleFormScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final Set<String> _selected = {};
  bool _isSystem = false;

  bool _loading = false;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.roleId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final role =
          await ref.read(roleServiceProvider).getById(widget.roleId!);
      if (role == null) {
        setState(() => _error = 'Role not found');
      } else {
        _nameCtrl.text = role.name;
        _descCtrl.text = role.description;
        _selected.clear();
        _selected.addAll(role.permissions);
        _isSystem = role.isSystem;
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _toggle(String key) {
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
  }

  void _toggleGroup(List<AppPermission> group, bool select) {
    setState(() {
      for (final p in group) {
        if (select) {
          _selected.add(p.key);
        } else {
          _selected.remove(p.key);
        }
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selected.clear();
      _selected.addAll(allPermissions.map((p) => p.key));
    });
  }

  void _clearAll() {
    setState(() => _selected.clear());
  }

  Future<void> _save() async {
    if (_isSystem) {
      _snack('System roles cannot be edited', error: true);
      return;
    }
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Role name is required');
      return;
    }
    if (_selected.isEmpty) {
      setState(() => _error = 'Select at least one permission');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final role = Role(
        id: widget.roleId ?? '',
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        permissions: _selected.toList(),
        isSystem: false,
      );
      if (_isEdit) {
        await ref.read(roleServiceProvider).update(widget.roleId!, role);
      } else {
        await ref.read(roleServiceProvider).create(role);
      }
      if (mounted) context.go('/roles');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final grouped = groupPermissions();
    final total = allPermissions.length;
    final selectedCount = _selected.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.go('/roles'),
                icon: const Icon(LucideIcons.arrowLeft, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                _isEdit
                    ? (_isSystem ? 'View Role' : 'Edit Role')
                    : 'New Role',
                style: AppTextStyles.displayMedium,
              ),
            ],
          ),
          if (_isSystem) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                const Icon(LucideIcons.info,
                    size: 16, color: AppColors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This is a system role. Permissions can be viewed but not modified.',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.info),
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 20),

          // Role details
          SectionCard(
            title: 'Role Details',
            child: Column(
              children: [
                AppFormField(
                  label: 'Role Name',
                  controller: _nameCtrl,
                  hint: 'e.g. Karachi Sales Manager',
                  icon: LucideIcons.shield,
                  required: true,
                ),
                const SizedBox(height: 14),
                AppFormField(
                  label: 'Description',
                  controller: _descCtrl,
                  hint: 'Short description of what this role does',
                  icon: LucideIcons.fileText,
                  maxLines: 2,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Permissions header + bulk actions
          SectionCard(
            title: 'Permissions',
            subtitle: '$selectedCount of $total selected',
            trailing: _isSystem
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: _selectAll,
                        child: const Text('Select All'),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: _clearAll,
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
            child: Column(
              children: [
                for (final entry in grouped.entries) ...[
                  _PermissionGroup(
                    group: entry.key,
                    permissions: entry.value,
                    selected: _selected,
                    onToggle: _toggle,
                    onToggleGroup: _toggleGroup,
                    readOnly: _isSystem,
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                const Icon(LucideIcons.alertCircle,
                    size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.error)),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => context.go('/roles'),
                child: const Text('Cancel'),
              ),
              if (!_isSystem) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Icon(LucideIcons.save, size: 16),
                  label: Text(_saving
                      ? 'Saving...'
                      : (_isEdit ? 'Update Role' : 'Create Role')),
                ),
              ],
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _PermissionGroup extends StatelessWidget {
  final String group;
  final List<AppPermission> permissions;
  final Set<String> selected;
  final void Function(String) onToggle;
  final void Function(List<AppPermission>, bool) onToggleGroup;
  final bool readOnly;

  const _PermissionGroup({
    required this.group,
    required this.permissions,
    required this.selected,
    required this.onToggle,
    required this.onToggleGroup,
    required this.readOnly,
  });

  @override
  Widget build(BuildContext context) {
    final allSelected =
        permissions.every((p) => selected.contains(p.key));
    final someSelected = permissions
        .any((p) => selected.contains(p.key));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!readOnly)
                Checkbox(
                  value: allSelected
                      ? true
                      : (someSelected ? null : false),
                  tristate: true,
                  onChanged: readOnly
                      ? null
                      : (v) {
                          onToggleGroup(permissions, v ?? false);
                        },
                  activeColor: AppColors.primary,
                ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  group,
                  style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${permissions.where((p) => selected.contains(p.key)).length}/${permissions.length}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...permissions.map((p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: InkWell(
                  onTap: readOnly ? null : () => onToggle(p.key),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 6, horizontal: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: Checkbox(
                            value: selected.contains(p.key),
                            onChanged: readOnly
                                ? null
                                : (_) => onToggle(p.key),
                            activeColor: AppColors.primary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            p.label,
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}