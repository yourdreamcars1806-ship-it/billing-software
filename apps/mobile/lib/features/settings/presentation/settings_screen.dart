import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/business_logo.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../../theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../business_selection/providers/business_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await ref.read(loginControllerProvider.notifier).signOut();
      ref.read(activeBusinessProvider.notifier).clearBusiness();
      if (mounted) context.go('/login');
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(activeBusinessProvider);
    final brand = AppColors.brand(business?.businessType);

    return Stack(
      children: [
        AppScaffold(
          title: 'Settings',
          showBusinessSwitcher: false,
          fallbackRoute: '/more',
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              const DeskHeader(
                title: 'Settings',
                subtitle: 'Workspace setup',
              ),
              if (business != null) ...[
                const SizedBox(height: 14),
                SoftSurface(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      BusinessLogo(business: business, size: 48, padding: 6),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              business.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              business.isClothing
                                  ? 'Clothing billing desk'
                                  : 'Automobile billing desk',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.slate500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const SectionLabel('Folders'),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.key_outlined,
                title: 'Login account',
                subtitle: 'Change password',
                accent: brand,
                onTap: () => context.push('/settings/change-password'),
              ),
              _SettingsTile(
                icon: Icons.storefront_outlined,
                title: 'Business profile',
                subtitle: 'Name, address, GST, logo',
                accent: brand,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Edit business profile from web Settings'),
                    ),
                  );
                },
              ),
              _SettingsTile(
                icon: Icons.receipt_long_outlined,
                title: 'Invoice & tax',
                subtitle: 'Prefix, tax, footer',
                accent: brand,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Edit invoice & tax from web Settings'),
                    ),
                  );
                },
              ),
              _SettingsTile(
                icon: Icons.bluetooth,
                title: 'Bluetooth printer',
                subtitle: '80mm thermal · pair & connect',
                accent: brand,
                onTap: () => context.push('/settings/bluetooth-printer'),
              ),
              _SettingsTile(
                icon: Icons.chat_outlined,
                title: 'WhatsApp invoice',
                subtitle: 'Auto-send bills',
                accent: brand,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Configure WhatsApp from web Settings'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const SectionLabel('Account'),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.analytics_outlined,
                title: 'Reports',
                subtitle: 'Sales & collection',
                accent: AppColors.info,
                onTap: () => context.push('/reports'),
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.logout,
                title: 'Sign out',
                subtitle: 'End this session',
                danger: true,
                onTap: _signOut,
              ),
            ],
          ),
        ),
        LoadingOverlay(
          isVisible: _signingOut,
          message: 'Signing out…',
        ),
      ],
    );
  }
}

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await ref.read(loginControllerProvider.notifier).signOut();
      ref.read(activeBusinessProvider.notifier).clearBusiness();
      if (mounted) context.go('/login');
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(activeBusinessProvider);
    final brand = AppColors.brand(business?.businessType);

    return Stack(
      children: [
        AppScaffold(
          title: 'More',
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              BrandBanner(
                title: 'More',
                subtitle: business == null
                    ? 'Workspace tools'
                    : '${business.name} · menu & settings',
                brand: brand,
                soft: AppColors.brandSoft(business?.businessType),
                icon: Icons.apps_rounded,
              ),
              const SizedBox(height: 18),
              const SectionLabel('Workspace'),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.dashboard_outlined,
                title: 'Dashboard',
                subtitle: 'Today sales & collection',
                accent: brand,
                onTap: () => context.go('/dashboard'),
              ),
              _SettingsTile(
                icon: Icons.receipt_long_outlined,
                title: 'Billing',
                subtitle: 'New invoice',
                accent: brand,
                onTap: () => context.go('/billing'),
              ),
              if (business?.isClothing == true)
                _SettingsTile(
                  icon: Icons.qr_code_2,
                  title: 'Products & Barcode',
                  subtitle: 'Generate · share stickers',
                  accent: brand,
                  onTap: () => context.push('/products'),
                ),
              if (business?.isClothing == true)
                _SettingsTile(
                  icon: Icons.inventory_2_outlined,
                  title: 'Stock by category',
                  subtitle: 'Stock · buy · sell per category',
                  accent: brand,
                  onTap: () => context.push('/stock'),
                ),
              _SettingsTile(
                icon: Icons.description_outlined,
                title: 'Invoices',
                subtitle: 'View, print, WhatsApp',
                accent: brand,
                onTap: () => context.go('/invoices'),
              ),
              _SettingsTile(
                icon: Icons.credit_card_outlined,
                title: 'Payments',
                subtitle: 'Collection history',
                accent: brand,
                onTap: () => context.push('/payments'),
              ),
              _SettingsTile(
                icon: Icons.bar_chart_outlined,
                title: 'Reports',
                subtitle: 'Sales and collection',
                accent: AppColors.info,
                onTap: () => context.push('/reports'),
              ),
              _SettingsTile(
                icon: Icons.bluetooth,
                title: 'Bluetooth printer',
                subtitle: '80mm thermal · pair & connect',
                accent: brand,
                onTap: () => context.push('/settings/bluetooth-printer'),
              ),
              _SettingsTile(
                icon: Icons.settings_outlined,
                title: 'Settings',
                subtitle: 'Login · profile · invoice · WhatsApp',
                accent: brand,
                onTap: () => context.push('/settings'),
              ),
              const SizedBox(height: 16),
              const SectionLabel('Session'),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.logout,
                title: 'Sign out',
                subtitle: 'End this session',
                danger: true,
                onTap: _signOut,
              ),
            ],
          ),
        ),
        LoadingOverlay(
          isVisible: _signingOut,
          message: 'Signing out…',
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.error : (accent ?? AppColors.slate700);
    return SoftSurface(
      elevated: true,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          IconBadge(icon: icon, color: color, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: danger ? AppColors.error : AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.slate500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: danger ? AppColors.error : AppColors.slate300,
          ),
        ],
      ),
    );
  }
}
