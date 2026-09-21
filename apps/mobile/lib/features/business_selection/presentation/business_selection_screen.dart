import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/business.dart';
import '../../../shared/widgets/business_logo.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../../theme/app_colors.dart';
import '../providers/business_provider.dart';

class BusinessSelectionScreen extends ConsumerStatefulWidget {
  const BusinessSelectionScreen({super.key});

  @override
  ConsumerState<BusinessSelectionScreen> createState() =>
      _BusinessSelectionScreenState();
}

class _BusinessSelectionScreenState
    extends ConsumerState<BusinessSelectionScreen> {
  String? _openingId;

  Future<void> _openBusiness(Business business) async {
    if (_openingId != null) return;
    setState(() => _openingId = business.id);
    try {
      await ref.read(activeBusinessProvider.notifier).setActiveBusiness(business);
      if (mounted) context.go('/dashboard');
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessesAsync = ref.watch(businessSelectionProvider);
    final busy = _openingId != null;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            title: const Text('Select Business'),
            automaticallyImplyLeading: false,
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: AppColors.slate200),
            ),
          ),
          body: businessesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
            data: (businesses) {
              if (businesses.isEmpty) {
                return const Center(child: Text('No businesses available'));
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                itemCount: businesses.length + 1,
                separatorBuilder: (_, index) =>
                    SizedBox(height: index == 0 ? 14 : 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const SoftSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose your desk',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Open clothing or car billing with the matching brand theme.',
                            style: TextStyle(
                              color: AppColors.slate500,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final business = businesses[index - 1];
                  return _BusinessCard(
                    business: business,
                    busy: _openingId == business.id,
                    onTap: busy ? null : () => _openBusiness(business),
                  );
                },
              );
            },
          ),
        ),
        LoadingOverlay(
          isVisible: busy,
          message: 'Opening workspace…',
        ),
      ],
    );
  }
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({
    required this.business,
    required this.onTap,
    this.busy = false,
  });

  final Business business;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.brand(business.businessType);

    return SoftSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      borderColor: accent.withValues(alpha: 0.25),
      child: Row(
        children: [
          busy
              ? Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.brandSoft(business.businessType),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: accent,
                    ),
                  ),
                )
              : BusinessLogo(business: business, size: 56, padding: 6),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  business.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.slate900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  business.description ??
                      (business.isClothing
                          ? 'Clothing billing'
                          : 'Car billing'),
                  style: const TextStyle(
                    color: AppColors.slate500,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 8),
                StatusBadge(
                  label: business.isClothing ? 'CLOTHING' : 'CARS',
                  color: accent,
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: accent),
        ],
      ),
    );
  }
}
