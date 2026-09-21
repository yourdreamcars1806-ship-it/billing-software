import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import '../../features/business_selection/providers/business_provider.dart';
import 'business_logo.dart';

/// App bar brand chip — display only (no switch / account picker).
class BusinessSwitcher extends ConsumerWidget {
  const BusinessSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBusiness = ref.watch(activeBusinessProvider);

    if (activeBusiness == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          BusinessLogo(business: activeBusiness, size: 32, padding: 3),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  activeBusiness.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  activeBusiness.isClothing
                      ? 'Clothing desk'
                      : 'Automobile desk',
                  style: const TextStyle(
                    color: AppColors.slate500,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
