import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/transaction_repository.dart';
import 'selected_month_provider.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository();
});

// A simple tick notifier to trigger data reload when transactions change
class TransactionVersionNotifier extends StateNotifier<int> {
  TransactionVersionNotifier() : super(0);
  void bump() => state = state + 1;
}

final transactionVersionProvider =
    StateNotifierProvider<TransactionVersionNotifier, int>((ref) {
  return TransactionVersionNotifier();
});

// Monthly summary for currently selected month
final monthlySummaryProvider =
    FutureProvider.autoDispose<MonthlySummary>((ref) async {
  ref.watch(transactionVersionProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);
  final repo = ref.watch(transactionRepositoryProvider);

  final start = AppDateUtils.startOfMonth(selectedMonth);
  final end = AppDateUtils.endOfMonth(selectedMonth);

  return repo.getMonthlySummary(start, end);
});

// Recent transactions for Dashboard (15 most recent in selected month)
final recentTransactionsProvider =
    FutureProvider.autoDispose<List<TransactionModel>>((ref) async {
  ref.watch(transactionVersionProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);
  final repo = ref.watch(transactionRepositoryProvider);

  final start = AppDateUtils.startOfMonth(selectedMonth);
  final end = AppDateUtils.endOfMonth(selectedMonth);

  return repo.getTransactions(
    startDate: start,
    endDate: end,
    limit: 15,
  );
});

// Filter state for history screen
enum HistoryTimeRange { thisMonth, lastMonth, today, all }

class HistoryFilterState {
  final String type; // 'ALL', 'EXPENSE', 'INCOME'
  final String categoryId; // 'ALL' or specific category id
  final HistoryTimeRange timeRange;
  final String searchQuery;

  const HistoryFilterState({
    this.type = 'ALL',
    this.categoryId = 'ALL',
    this.timeRange = HistoryTimeRange.thisMonth,
    this.searchQuery = '',
  });

  HistoryFilterState copyWith({
    String? type,
    String? categoryId,
    HistoryTimeRange? timeRange,
    String? searchQuery,
  }) {
    return HistoryFilterState(
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      timeRange: timeRange ?? this.timeRange,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class HistoryFilterNotifier extends StateNotifier<HistoryFilterState> {
  HistoryFilterNotifier() : super(const HistoryFilterState());

  void setType(String type) => state = state.copyWith(type: type);
  void setCategoryId(String catId) => state = state.copyWith(categoryId: catId);
  void setTimeRange(HistoryTimeRange range) => state = state.copyWith(timeRange: range);
  void setSearchQuery(String query) => state = state.copyWith(searchQuery: query);
  void reset() => state = const HistoryFilterState();
}

final historyFilterProvider =
    StateNotifierProvider<HistoryFilterNotifier, HistoryFilterState>((ref) {
  return HistoryFilterNotifier();
});

// Filtered transactions for History screen
final filteredTransactionsProvider =
    FutureProvider.autoDispose<List<TransactionModel>>((ref) async {
  ref.watch(transactionVersionProvider);
  final filter = ref.watch(historyFilterProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);
  final repo = ref.watch(transactionRepositoryProvider);

  DateTime? startDate;
  DateTime? endDate;

  final now = DateTime.now();
  switch (filter.timeRange) {
    case HistoryTimeRange.thisMonth:
      startDate = AppDateUtils.startOfMonth(selectedMonth);
      endDate = AppDateUtils.endOfMonth(selectedMonth);
      break;
    case HistoryTimeRange.lastMonth:
      final lastMonth = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
      startDate = AppDateUtils.startOfMonth(lastMonth);
      endDate = AppDateUtils.endOfMonth(lastMonth);
      break;
    case HistoryTimeRange.today:
      startDate = DateTime(now.year, now.month, now.day);
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      break;
    case HistoryTimeRange.all:
      startDate = null;
      endDate = null;
      break;
  }

  return repo.getTransactions(
    startDate: startDate,
    endDate: endDate,
    type: filter.type,
    categoryId: filter.categoryId,
    searchQuery: filter.searchQuery,
  );
});

// Actions
class TransactionActionsNotifier {
  final Ref _ref;

  TransactionActionsNotifier(this._ref);

  Future<void> addTransaction(TransactionModel transaction) async {
    final repo = _ref.read(transactionRepositoryProvider);
    await repo.insertTransaction(transaction);
    _ref.read(transactionVersionProvider.notifier).bump();
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    final repo = _ref.read(transactionRepositoryProvider);
    await repo.updateTransaction(transaction);
    _ref.read(transactionVersionProvider.notifier).bump();
  }

  Future<void> deleteTransaction(String id) async {
    final repo = _ref.read(transactionRepositoryProvider);
    await repo.deleteTransaction(id);
    _ref.read(transactionVersionProvider.notifier).bump();
  }
}

final transactionActionsProvider = Provider<TransactionActionsNotifier>((ref) {
  return TransactionActionsNotifier(ref);
});
