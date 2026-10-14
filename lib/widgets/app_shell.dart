import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_sidebar.dart';
import 'app_header.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _sidebarCollapsed = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1024;
    final isTablet = width >= 600 && width < 1024;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _sidebarCollapsed ? 76 : 260,
              child: AppSidebar(
                collapsed: _sidebarCollapsed,
                onToggle: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  const AppHeader(showMenuButton: false),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (isTablet) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            const SizedBox(width: 76, child: AppSidebar(collapsed: true, onToggle: _noop)),
            Expanded(
              child: Column(
                children: [
                  const AppHeader(showMenuButton: false),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: const Drawer(
        backgroundColor: AppColors.sidebar,
        child: AppSidebar(collapsed: false, onToggle: _noop),
      ),
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              showMenuButton: true,
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }
}

void _noop() {}