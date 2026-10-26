import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() =>
      DateTime(DateTime.now().year, DateTime.now().month, 1);

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
    NotifierProvider<SelectedMonthNotifier, DateTime>(
        SelectedMonthNotifier.new);
