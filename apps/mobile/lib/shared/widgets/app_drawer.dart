import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/business_selection/providers/business_provider.dart';
import '../../theme/app_colors.dart';
import 'business_logo.dart';

/// Web-parity side nav — hamburger se open.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key, this.currentPath});

  final String? currentPath;

  void _go(BuildContext context, String path) {
    Navigator.of(context).pop();
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc == path) return;

    const shell = {'/dashboard', '/billing', '/invoices', '/more'};
    if (shell.contains(path)) {
      context.go(path);
    } else {
      context.push(path);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(activeBusinessProvider);
    final brand = AppColors.brand(business?.businessType);
    final soft = AppColors.brandSoft(business?.businessType);
    final path = currentPath ?? GoRouterState.of(context).matchedLocation;
    final isClothing = business?.isClothing ?? true;

    bool active(String p) {
      if (p == '/dashboard') return path == '/dashboard';
      if (p == '/invoices') {
        return path == '/invoices' || path.startsWith('/invoices/');
      }
      return path == p || path.startsWith('$p/');
    }

    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.82,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [soft, Colors.white],
                ),
                border: const Border(
                  bottom: BorderSide(color: AppColors.slate200),
                ),
              ),
              child: Row(
                children: [
                  if (business != null)
                    BusinessLogo(business: business, size: 52, padding: 5)
                  else
                    _LogoFallback(brand: brand),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          business?.name ?? 'Billing',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: AppColors.brandDark(business?.businessType),
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isClothing ? 'Clothing desk' : 'Automobile desk',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.slate500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _go(context, '/billing'),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'New invoice',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                children: [
                  _section('Navigate'),
                  _NavTile(
                    icon: Icons.grid_view_rounded,
                    label: 'Dashboard',
                    active: active('/dashboard'),
                    brand: brand,
                    soft: soft,
                    onTap: () => _go(context, '/dashboard'),
                  ),
                  _NavTile(
                    icon: Icons.receipt_long_rounded,
                    label: 'Billing',
                    active: active('/billing'),
                    brand: brand,
                    soft: soft,
                    onTap: () => _go(context, '/billing'),
                  ),
                  if (isClothing)
                    _NavTile(
                      icon: Icons.qr_code_2_rounded,
                      label: 'Products',
                      active: active('/products'),
                      brand: brand,
                      soft: soft,
                      onTap: () => _go(context, '/products'),
                    ),
                  if (isClothing)
                    _NavTile(
                      icon: Icons.inventory_2_rounded,
                      label: 'Stock',
                      active: active('/stock'),
                      brand: brand,
                      soft: soft,
                      onTap: () => _go(context, '/stock'),
                    ),
                  _NavTile(
                    icon: Icons.description_rounded,
                    label: 'Invoices',
                    active: active('/invoices'),
                    brand: brand,
                    soft: soft,
                    onTap: () => _go(context, '/invoices'),
                  ),
                  _NavTile(
                    icon: Icons.credit_card_rounded,
                    label: 'Payments',
                    active: active('/payments'),
                    brand: brand,
                    soft: soft,
                    onTap: () => _go(context, '/payments'),
                  ),
                  _NavTile(
                    icon: Icons.bar_chart_rounded,
                    label: 'Reports',
                    active: active('/reports'),
                    brand: brand,
                    soft: soft,
                    onTap: () => _go(context, '/reports'),
                  ),
                  _NavTile(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    active: active('/settings'),
                    brand: brand,
                    soft: soft,
                    onTap: () => _go(context, '/settings'),
                  ),
                  const SizedBox(height: 8),
                  _section('Account'),
                  _NavTile(
                    icon: Icons.lock_reset_rounded,
                    label: 'Change password',
                    active: path.contains('change-password'),
                    brand: brand,
                    soft: soft,
                    onTap: () => _go(context, '/settings/change-password'),
                  ),
                  _NavTile(
                    icon: Icons.bluetooth_rounded,
                    label: 'Bluetooth printer',
                    active: path.contains('bluetooth'),
                    brand: brand,
                    soft: soft,
                    onTap: () => _go(context, '/settings/bluetooth-printer'),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.slate200)),
              ),
              child: Column(
                children: [
                  _NavTile(
                    icon: Icons.logout_rounded,
                    label: 'Sign out',
                    active: false,
                    brand: AppColors.error,
                    soft: AppColors.error.withValues(alpha: 0.08),
                    danger: true,
                    onTap: () async {
                      Navigator.pop(context);
                      await ref.read(loginControllerProvider.notifier).signOut();
                      ref.read(activeBusinessProvider.notifier).clearBusiness();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: AppColors.slate400,
        ),
      ),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback({required this.brand});
  final Color brand;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: brand.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: brand.withValues(alpha: 0.25)),
      ),
      child: Icon(Icons.storefront_rounded, color: brand, size: 24),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.brand,
    required this.soft,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color brand;
  final Color soft;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final fg = danger
        ? AppColors.error
        : (active ? brand : AppColors.slate700);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Material(
        color: active ? soft : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 3,
                  height: 22,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: active ? brand : Colors.transparent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Icon(icon, size: 22, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 14.5,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void popOrFallback(BuildContext context, {String fallback = '/dashboard'}) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}
