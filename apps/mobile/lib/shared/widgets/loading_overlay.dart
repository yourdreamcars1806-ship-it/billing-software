import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Full-screen dim + spinner card so user clearly sees an action is running.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    this.message = 'Please wait…',
    this.isVisible = true,
  });

  final String message;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final brand = Theme.of(context).colorScheme.primary;

    return SizedBox.expand(
      child: AbsorbPointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.32),
          child: Center(
            child: Material(
              color: Colors.white,
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: brand,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.slate800,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Primary button that shows a white spinner + label while busy.
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.loading = false,
    this.loadingLabel,
    this.icon,
    this.backgroundColor,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool loading;
  final String? loadingLabel;
  final IconData? icon;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final busy = loading;
    final child = busy
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Text(loadingLabel ?? 'Please wait…'),
            ],
          )
        : (icon == null
            ? Text(label)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                  Text(label),
                ],
              ));

    return ElevatedButton(
      style: backgroundColor == null
          ? null
          : ElevatedButton.styleFrom(backgroundColor: backgroundColor),
      onPressed: busy ? null : onPressed,
      child: child,
    );
  }
}
