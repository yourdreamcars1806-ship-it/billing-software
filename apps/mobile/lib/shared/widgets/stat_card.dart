import 'package:flutter/material.dart';

import '../../core/utils/currency_utils.dart';
import '../../theme/app_colors.dart';
import 'ui_kit.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.color,
    this.isCurrency = true,
  });

  final String title;
  final num value;
  final IconData icon;
  final String? subtitle;
  final Color? color;
  final bool isCurrency;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    final displayValue =
        isCurrency ? CurrencyUtils.formatCompact(value) : value.toString();

    return SoftSurface(
      elevated: true,
      padding: const EdgeInsets.all(15),
      borderColor: accent.withValues(alpha: 0.14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: icon, color: accent, size: 38),
              const Spacer(),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.slate500,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              displayValue,
              style: const TextStyle(
                color: AppColors.slate900,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent.withValues(alpha: 0.95),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
