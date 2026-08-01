import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static String currency(num? value) {
    final v = value ?? 0;
    final n = NumberFormat('#,##,##0', 'en_PK');
    return 'Rs. ${n.format(v.round())}';
  }

  static String number(num? value) {
    final v = value ?? 0;
    return NumberFormat('#,##,##0', 'en_PK').format(v.round());
  }

  static String date(DateTime? value) {
    if (value == null) return '—';
    return DateFormat('dd-MMM-yyyy').format(value.toLocal());
  }

  static String dateTime(DateTime? value) {
    if (value == null) return '—';
    return DateFormat('dd-MMM-yyyy hh:mm a').format(value.toLocal());
  }

  static String time(DateTime? value) {
    if (value == null) return '—';
    return DateFormat('hh:mm a').format(value.toLocal());
  }

  static String title(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
