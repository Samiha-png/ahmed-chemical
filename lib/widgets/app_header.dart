import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AppHeader extends StatelessWidget {
  final bool showMenuButton;
  final VoidCallback? onMenuTap;
  const AppHeader({super.key, required this.showMenuButton, this.onMenuTap});

  String _titleForPath(String path) {
    const map = {
      '/dashboard': 'Dashboard',
      '/products': 'Products & Chemicals',
      '/inventory': 'Inventory',
      '/suppliers': 'Suppliers',
      '/customers': 'Customers',
      '/purchasing': 'Purchasing',
      '/sales': 'Sales',
      '/invoices': 'Invoices',
      '/currencies': 'Currencies',
      '/finance': 'Finance & Accounts',
      '/reports': 'Reports',
      '/users': 'Users & Permissions',
      '/settings': 'Settings',
    };
    return map[path] ?? 'Ahmed Chemical Co.';
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          if (showMenuButton) ...[
            IconButton(
              onPressed: onMenuTap,
              icon: const Icon(LucideIcons.menu, size: 20),
              color: AppColors.textSecondary),
            const SizedBox(width: 8),
          ],
          Text(_titleForPath(path), style: AppTextStyles.headingMedium),
          const Spacer(),
          if (MediaQuery.of(context).size.width >= 768)
            Container(
              width: 280, height: 38,
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border)),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(LucideIcons.search, size: 15, color: AppColors.textDim),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      style: AppTextStyles.bodyMedium,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        hintText: 'Search...',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textDim)),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () {},
            icon: const Icon(LucideIcons.bell, size: 18),
            color: AppColors.textSecondary,
            tooltip: 'Notifications'),
          PopupMenuButton<String>(
            offset: const Offset(0, 48),
            color: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.border)),
            onSelected: (_) {},
            itemBuilder: (context) => [
              const PopupMenuItem(enabled: false,
                child: Text('admin@ahmedchemical.com')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'profile', child: Text('Profile')),
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: AppColors.elevated,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border)),
              alignment: Alignment.center,
              child: Text('A',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600, color: AppColors.primary)),
            ),
          ),
        ],
      ),
    );
  }
}
