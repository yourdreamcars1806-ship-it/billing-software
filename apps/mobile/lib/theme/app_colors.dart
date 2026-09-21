import 'package:flutter/material.dart';

import '../models/business.dart';

class AppColors {
  AppColors._();

  // Shared neutrals (match web)
  static const bg = Color(0xFFF4F5F7);
  static const surface = Colors.white;
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);

  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);

  static const success = Color(0xFF059669);
  static const warning = Color(0xFFD97706);
  static const error = Color(0xFFDC2626);
  static const info = Color(0xFF0284C7);

  // Clothing = Drape & Dream logo gold (sampled from logo)
  static const clothingBrand = Color(0xFFA87000);
  static const clothingSolid = Color(0xFFC89018);
  static const clothingSoft = Color(0xFFFBF7EB);
  static const clothingBorder = Color(0xFFE5C76B);
  static const clothingInk = Color(0xFF8B6914);

  // Cars = blue (web)
  static const carBrand = Color(0xFF1D4ED8);
  static const carSolid = Color(0xFF2563EB);
  static const carSoft = Color(0xFFEFF6FF);
  static const carBorder = Color(0xFF93C5FD);

  /// Prefer brand color for active business
  static Color brand(BusinessType? type) =>
      type == BusinessType.car ? carSolid : clothingSolid;

  static Color brandDark(BusinessType? type) =>
      type == BusinessType.car ? carBrand : clothingBrand;

  static Color brandSoft(BusinessType? type) =>
      type == BusinessType.car ? carSoft : clothingSoft;

  // Legacy aliases used around the app
  static const primary = clothingSolid;
  static const primaryLight = Color(0xFFD8A028);
  static const primaryDark = clothingBrand;
  static const secondary = carSolid;
  static const secondaryLight = Color(0xFF60A5FA);
  static const clothingAccent = clothingSolid;
  static const carAccent = carSolid;
}

/// Payment status label — cars use Token amount, clothing uses Partial
String paymentStatusLabel(String status, {BusinessType? businessType}) {
  final s = status.toLowerCase();
  if (s == 'partial' || s == 'token') {
    return businessType == BusinessType.car ? 'Token amount' : 'Partial';
  }
  if (s == 'paid') return 'Paid';
  if (s == 'pending') return 'Pending';
  return status;
}
