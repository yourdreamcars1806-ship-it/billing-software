import 'package:intl/intl.dart';

class CurrencyUtils {
  CurrencyUtils._();

  /// Mobile UI + PDF/thermal: "Rs." — Helvetica / Plus Jakarta cannot draw ₹
  /// (shows as ✕). Web keeps ₹ with browser fonts.
  static final _formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs.',
    decimalDigits: 2,
  );

  static String format(num amount) => _formatter.format(amount);

  static String formatCompact(num amount) {
    if (amount >= 10000000) {
      return 'Rs.${(amount / 10000000).toStringAsFixed(2)}Cr';
    }
    if (amount >= 100000) {
      return 'Rs.${(amount / 100000).toStringAsFixed(2)}L';
    }
    if (amount >= 1000) {
      return 'Rs.${(amount / 1000).toStringAsFixed(1)}K';
    }
    return format(amount);
  }
}
