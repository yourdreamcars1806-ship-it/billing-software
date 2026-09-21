import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/business_selection/providers/business_provider.dart';
import '../../theme/app_colors.dart';
import 'app_drawer.dart';
import 'business_switcher.dart';

class AppScaffold extends ConsumerStatefulWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.showBusinessSwitcher = true,
    this.bottomBar,
    this.showDrawer = true,
    this.showBack,
    this.fallbackRoute = '/dashboard',
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showBusinessSwitcher;
  final Widget? bottomBar;
  final bool showDrawer;
  final bool? showBack;
  final String fallbackRoute;

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openMenu() {
    final state = _scaffoldKey.currentState;
    if (state == null) return;
    if (state.isDrawerOpen) {
      state.closeDrawer();
    } else {
      state.openDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(activeBusinessProvider);
    final brand = AppColors.brand(business?.businessType);
    final canPop = context.canPop();
    final useBack =
        widget.showBack ?? (!widget.showBusinessSwitcher && canPop);
    final path = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bg,
      drawer: widget.showDrawer ? AppDrawer(currentPath: path) : null,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        titleSpacing: 0,
        leadingWidth: useBack && widget.showDrawer ? 96 : 56,
        leading: useBack
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Back',
                    onPressed: () => popOrFallback(
                      context,
                      fallback: widget.fallbackRoute,
                    ),
                  ),
                  if (widget.showDrawer)
                    IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      tooltip: 'Menu',
                      onPressed: _openMenu,
                    ),
                ],
              )
            : (widget.showDrawer
                ? IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    tooltip: 'Menu',
                    onPressed: _openMenu,
                  )
                : null),
        title: widget.showBusinessSwitcher
            ? const BusinessSwitcher()
            : Text(
                widget.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
        actions: [
          if (widget.actions != null) ...widget.actions!,
          if (widget.showBusinessSwitcher)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: IconButton(
                tooltip: 'New invoice',
                style: IconButton.styleFrom(
                  backgroundColor: brand.withValues(alpha: 0.12),
                  foregroundColor: brand,
                ),
                icon: const Icon(Icons.add_rounded, size: 22),
                onPressed: () => context.go('/billing'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Settings',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.slate100,
                foregroundColor: AppColors.slate700,
              ),
              icon: const Icon(Icons.settings_outlined, size: 20),
              onPressed: () => context.push('/settings'),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.slate200),
        ),
      ),
      body: widget.body,
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: widget.bottomBar,
    );
  }
}

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(activeBusinessProvider);
    final brand = AppColors.brand(business?.businessType);

    // Standard shell: tab body gets bounded height from Scaffold.
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: navigationShell,
      bottomNavigationBar: Material(
        color: Colors.white,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: AppColors.slate900.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
            border: const Border(top: BorderSide(color: AppColors.slate200)),
          ),
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (i) => navigationShell.goBranch(
              i,
              initialLocation: i == navigationShell.currentIndex,
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            height: 66,
            indicatorColor: brand.withValues(alpha: 0.14),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded, color: brand),
                label: 'Home',
              ),
              NavigationDestination(
                icon: const Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded, color: brand),
                label: 'Bill',
              ),
              NavigationDestination(
                icon: const Icon(Icons.description_outlined),
                selectedIcon: Icon(Icons.description_rounded, color: brand),
                label: 'Invoices',
              ),
              NavigationDestination(
                icon: const Icon(Icons.apps_outlined),
                selectedIcon: Icon(Icons.apps_rounded, color: brand),
                label: 'More',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
