import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class SidebarItem {
  final String label;
  final IconData icon;
  final String route;
  const SidebarItem({
    required this.label,
    required this.icon,
    required this.route,
  });
}

/// Main navigation items, grouped logically:
///   Core      → Dashboard, Products, Categories, Inventory, Warehouses
///   Parties   → Suppliers, Customers
///   Purchasing→ Purchasing, GRN, Bills, Payments
///   Sales     → Sales, Invoices
///   Accounting→ COA, Journal, Trial Balance, P&L, Balance Sheet
///   Admin     → Users, Roles, Settings
const List<SidebarItem> _items = [
  // ── Core ──
  SidebarItem(
    label: 'Dashboard',
    icon: LucideIcons.layoutDashboard,
    route: '/dashboard',
  ),
  SidebarItem(label: 'Products', icon: LucideIcons.package, route: '/products'),
  SidebarItem(label: 'Categories', icon: LucideIcons.tags, route: '/categories'),
  SidebarItem(
    label: 'Inventory',
    icon: LucideIcons.warehouse,
    route: '/inventory',
  ),
  SidebarItem(
    label: 'Warehouses',
    icon: LucideIcons.building2,
    route: '/warehouses',
  ),

  // ── Parties ──
  SidebarItem(label: 'Suppliers', icon: LucideIcons.truck, route: '/suppliers'),
  SidebarItem(label: 'Customers', icon: LucideIcons.users, route: '/customers'),

  // ── Purchasing ──
  SidebarItem(
    label: 'Purchasing',
    icon: LucideIcons.shoppingCart,
    route: '/purchasing',
  ),
  SidebarItem(
    label: 'Goods Receipts',
    icon: LucideIcons.packagePlus,
    route: '/purchasing/receipts',
  ),
  SidebarItem(
    label: 'Supplier Bills',
    icon: LucideIcons.fileText,
    route: '/purchasing/bills',
  ),
  SidebarItem(
    label: 'Supplier Payments',
    icon: LucideIcons.dollarSign,
    route: '/purchasing/payments',
  ),

  // ── Sales ──
  SidebarItem(label: 'Sales', icon: LucideIcons.receipt, route: '/sales'),
  SidebarItem(
    label: 'Invoices',
    icon: LucideIcons.fileText,
    route: '/invoices',
  ),

  // ── Accounting ──
  SidebarItem(
    label: 'Chart of Accounts',
    icon: LucideIcons.bookOpen,
    route: '/accounting/coa',
  ),
  SidebarItem(
    label: 'Journal Entries',
    icon: LucideIcons.clipboardList,
    route: '/accounting/journal',
  ),
  SidebarItem(
    label: 'Trial Balance',
    icon: LucideIcons.scale,
    route: '/accounting/trial-balance',
  ),
  SidebarItem(
    label: 'Profit & Loss',
    icon: LucideIcons.trendingUp,
    route: '/accounting/profit-loss',
  ),
  SidebarItem(
    label: 'Balance Sheet',
    icon: LucideIcons.landmark,
    route: '/accounting/balance-sheet',
  ),

  // ── Admin ──
  SidebarItem(label: 'Users', icon: LucideIcons.userCog, route: '/users'),
  SidebarItem(
    label: 'Roles & Permissions',
    icon: LucideIcons.shieldCheck,
    route: '/roles',
  ),
  SidebarItem(
    label: 'Settings',
    icon: LucideIcons.settings,
    route: '/settings',
  ),
];

class AppSidebar extends StatelessWidget {
  final bool collapsed;
  final VoidCallback onToggle;
  const AppSidebar({
    super.key,
    required this.collapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;

    return Container(
      color: AppColors.sidebar,
      child: Column(
        children: [
          Container(
            height: 64,
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 12 : 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'ACC',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppConfig.companyName,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text('Enterprise ERP',
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final item = _items[i];
                return _SidebarTile(
                  item: item,
                  collapsed: collapsed,
                  selected: currentPath == item.route,
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: _HoverIconButton(
              icon: collapsed
                  ? LucideIcons.chevronsRight
                  : LucideIcons.chevronsLeft,
              onTap: onToggle,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatefulWidget {
  final SidebarItem item;
  final bool collapsed;
  final bool selected;
  const _SidebarTile({
    required this.item,
    required this.collapsed,
    required this.selected,
  });

  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.selected
        ? AppColors.primarySoft
        : _hovered
            ? AppColors.elevated
            : Colors.transparent;
    final fg = widget.selected
        ? AppColors.primary
        : _hovered
            ? AppColors.textPrimary
            : AppColors.textSecondary;

    final tile = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go(widget.item.route),
        child: Container(
          height: 42,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: EdgeInsets.symmetric(horizontal: widget.collapsed ? 0 : 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.selected
                  ? AppColors.primary.withValues(alpha: 0.25)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: widget.collapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(widget.item.icon, size: 18, color: fg),
              if (!widget.collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.item.label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: fg,
                      fontWeight: widget.selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (widget.collapsed) {
      return Tooltip(
        message: widget.item.label,
        preferBelow: false,
        verticalOffset: 0,
        child: tile,
      );
    }
    return tile;
  }
}

class _HoverIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HoverIconButton({required this.icon, required this.onTap});

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: _hovered ? AppColors.elevated : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon,
              size: 16, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}