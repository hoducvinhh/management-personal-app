import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedMonthNotifier extends StateNotifier<DateTime> {
  SelectedMonthNotifier()
      : super(DateTime(DateTime.now().year, DateTime.now().month, 1));

  void nextMonth() {
    state = DateTime(state.year, state.month + 1, 1);
  }

  void previousMonth() {
    state = DateTime(state.year, state.month - 1, 1);
  }

  void setMonth(DateTime month) {
    state = DateTime(month.year, month.month, 1);
  }
}

final selectedMonthProvider =
    StateNotifierProvider<SelectedMonthNotifier, DateTime>((ref) {
  return SelectedMonthNotifier();
});
