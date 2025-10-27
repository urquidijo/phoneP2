import 'package:intl/intl.dart';

final NumberFormat currencyFormatter = NumberFormat.currency(
  locale: 'en_US',
  symbol: '\$',
  decimalDigits: 2,
);

final NumberFormat percentFormatter = NumberFormat.decimalPercentPattern(
  locale: 'en_US',
  decimalDigits: 1,
);

String formatDateTime(String isoDate) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return isoDate;
  return DateFormat.yMMMd('en_US').add_Hm().format(date);
}

String formatShortDate(String isoDate) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return isoDate;
  return DateFormat.yMMMd('en_US').format(date);
}
