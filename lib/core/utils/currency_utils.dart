import '../constants/app_constants.dart';

class CurrencyUtils {
  static String format(num amount) {
    return AppConstants.currencyFormatter.format(amount);
  }

  static String formatWithoutSymbol(num amount) {
    return AppConstants.numberOnlyFormatter.format(amount);
  }

  static String formatSigned(num amount, String type) {
    final formatted = format(amount.abs());
    if (type == 'INCOME') {
      return '+ $formatted';
    } else {
      return '- $formatted';
    }
  }

  static String formatCompact(num amount) {
    final abs = amount.abs();
    if (abs >= 1000000000) {
      final val = abs / 1000000000;
      return '${val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 1)}Tỷ';
    } else if (abs >= 1000000) {
      final val = abs / 1000000;
      return '${val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 1)}Tr';
    } else if (abs >= 1000) {
      final val = abs / 1000;
      return '${val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 1)}k';
    }
    return abs.toInt().toString();
  }

  static double? parseAmount(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }
}
