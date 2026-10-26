import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class AppDateUtils {
  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Chào buổi sáng 👋';
    } else if (hour >= 12 && hour < 18) {
      return 'Chào buổi chiều 🌤️';
    } else {
      return 'Chào buổi tối 🌙';
    }
  }

  static String formatMonthYearVi(DateTime date) {
    return 'Tháng ${date.month}, ${date.year}';
  }

  static String toMonthKey(DateTime date) {
    return AppConstants.monthKeyFormat.format(date);
  }

  static DateTime fromMonthKey(String key) {
    final parts = key.split('-');
    if (parts.length >= 2) {
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
    }
    return DateTime.now();
  }

  static String getWeekdayVi(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Thứ Hai';
      case DateTime.tuesday:
        return 'Thứ Ba';
      case DateTime.wednesday:
        return 'Thứ Tư';
      case DateTime.thursday:
        return 'Thứ Năm';
      case DateTime.friday:
        return 'Thứ Sáu';
      case DateTime.saturday:
        return 'Thứ Bảy';
      case DateTime.sunday:
        return 'Chủ Nhật';
      default:
        return '';
    }
  }

  static String formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final difference = today.difference(target).inDays;

    if (difference == 0) {
      return 'Hôm nay';
    } else if (difference == 1) {
      return 'Hôm qua';
    } else if (difference == -1) {
      return 'Ngày mai';
    } else if (difference > 1 && difference < 7) {
      return '${getWeekdayVi(date.weekday)}, ${DateFormat('dd/MM').format(date)}';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  static String formatFullDateVi(DateTime date) {
    return '${getWeekdayVi(date.weekday)}, ${DateFormat('dd/MM/yyyy').format(date)}';
  }

  static DateTime startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  static DateTime endOfMonth(DateTime date) {
    final nextMonth = (date.month == 12)
        ? DateTime(date.year + 1, 1, 1)
        : DateTime(date.year, date.month + 1, 1);
    return nextMonth.subtract(const Duration(milliseconds: 1));
  }
}
