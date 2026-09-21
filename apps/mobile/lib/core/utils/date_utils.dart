import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  static String formatDate(DateTime date) => DateFormat('dd MMM yyyy').format(date);

  static String formatDateTime(DateTime date) =>
      DateFormat('dd MMM yyyy, hh:mm a').format(date);

  static String toIsoDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  static DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
