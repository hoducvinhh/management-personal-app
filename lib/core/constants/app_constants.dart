import 'package:intl/intl.dart';

class AppConstants {
  static final NumberFormat currencyFormatter = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  static final NumberFormat compactCurrencyFormatter = NumberFormat.compact(
    locale: 'vi_VN',
  );

  static final NumberFormat numberOnlyFormatter = NumberFormat('#,###', 'vi_VN');

  static final DateFormat dateFormatter = DateFormat('dd/MM/yyyy');
  static final DateFormat dateMonthFormatter = DateFormat('dd/MM');
  static final DateFormat monthYearFormatter = DateFormat('MM/yyyy');
  static final DateFormat isoDateFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
  static final DateFormat monthKeyFormat = DateFormat('yyyy-MM');

  // Quick Amount Buttons
  static const List<int> quickAddAmounts = [
    10000,
    50000,
    100000,
    500000,
    1000000,
  ];

  static const List<String> quickAddLabels = [
    '+10k',
    '+50k',
    '+100k',
    '+500k',
    '+1Tr',
  ];
}
