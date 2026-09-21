import 'package:flutter/material.dart';

import '../../models/business.dart';
import '../../theme/app_colors.dart';

/// Circular brand logo — contain + light ring (matches web).
class BusinessLogo extends StatelessWidget {
  const BusinessLogo({
    super.key,
    required this.business,
    this.size = 40,
    this.padding = 5,
  });

  final Business business;
  final double size;
  final double padding;

  static const drapeAsset = 'assets/images/drape-and-dream-logo.png';
  static const carsAsset = 'assets/images/your-dream-cars-logo.png';

  @override
  Widget build(BuildContext context) {
    final color = AppColors.brand(business.businessType);
    final soft = AppColors.brandSoft(business.businessType);
    final border = business.isCar
        ? AppColors.carBorder
        : AppColors.clothingBorder;
    final logoPath = business.logoUrl?.isNotEmpty == true
        ? business.logoUrl!
        : (business.isClothing
            ? drapeAsset
            : (business.isCar ? carsAsset : null));
    final isAsset = logoPath != null && !logoPath.startsWith('http');
    final isNetwork = logoPath != null && logoPath.startsWith('http');

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isAsset || isNetwork ? Colors.white : soft,
        shape: BoxShape.circle,
        border: Border.all(color: border.withValues(alpha: 0.85), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: isAsset
          ? Padding(
              padding: EdgeInsets.all(padding),
              child: Image.asset(
                logoPath,
                fit: BoxFit.contain,
              ),
            )
          : isNetwork
              ? Padding(
                  padding: EdgeInsets.all(padding * 0.4),
                  child: Image.network(
                    logoPath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Icon(
                      business.isClothing
                          ? Icons.checkroom
                          : Icons.directions_car,
                      color: color,
                      size: size * 0.45,
                    ),
                  ),
                )
              : Icon(
                  business.isClothing
                      ? Icons.checkroom
                      : Icons.directions_car,
                  color: color,
                  size: size * 0.45,
                ),
    );
  }
}
