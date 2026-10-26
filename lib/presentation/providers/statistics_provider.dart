import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/date_utils.dart';
import '../../data/repositories/transaction_repository.dart';
import 'selected_month_provider.dart';
import 'transactions_provider.dart';

class SmartInsights {
  final String? topCategoryName;
  final String? topCategoryEmoji;
  final double topCategoryPercent;
  final double savingsRate; // e.g. 38.0%
  final double? expenseChangeVsLastMonth; // e.g. -8.5% (reduction) or +12% (increase)
  final bool hasData;

  const SmartInsights({
    this.topCategoryName,
    this.topCategoryEmoji,
    this.topCategoryPercent = 0.0,
    this.savingsRate = 0.0,
    this.expenseChangeVsLastMonth,
    this.hasData = false,
  });

  factory SmartInsights.empty() => const SmartInsights(hasData: false);
}

final categoryExpenseBreakdownProvider =
    FutureProvider.autoDispose<List<CategoryExpenseItem>>((ref) async {
  ref.watch(transactionVersionProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);
  final repo = ref.watch(transactionRepositoryProvider);

  final start = AppDateUtils.startOfMonth(selectedMonth);
  final end = AppDateUtils.endOfMonth(selectedMonth);

  return repo.getCategoryExpenseBreakdown(start, end);
});

final monthlyTrendsProvider =
    FutureProvider.autoDispose<List<MonthTrendItem>>((ref) async {
  ref.watch(transactionVersionProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);
  final repo = ref.watch(transactionRepositoryProvider);

  return repo.getMonthlyTrends(currentMonth: selectedMonth, monthsCount: 6);
});

final smartInsightsProvider =
    FutureProvider.autoDispose<SmartInsights>((ref) async {
  ref.watch(transactionVersionProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);
  final repo = ref.watch(transactionRepositoryProvider);

  final thisStart = AppDateUtils.startOfMonth(selectedMonth);
  final thisEnd = AppDateUtils.endOfMonth(selectedMonth);

  final thisMonthSummary = await repo.getMonthlySummary(thisStart, thisEnd);
  final breakdown = await repo.getCategoryExpenseBreakdown(thisStart, thisEnd);

  // Previous month summary
  final prevMonth = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
  final prevStart = AppDateUtils.startOfMonth(prevMonth);
  final prevEnd = AppDateUtils.endOfMonth(prevMonth);
  final prevMonthSummary = await repo.getMonthlySummary(prevStart, prevEnd);

  if (thisMonthSummary.income == 0.0 && thisMonthSummary.expense == 0.0) {
    return SmartInsights.empty();
  }

  // Top category
  String? topName;
  String? topEmoji;
  double topPercent = 0.0;
  if (breakdown.isNotEmpty) {
    topName = breakdown.first.category.name;
    topEmoji = breakdown.first.category.emoji;
    topPercent = breakdown.first.percentage;
  }

  // Savings rate
  double savingsRate = 0.0;
  if (thisMonthSummary.income > 0) {
    savingsRate = ((thisMonthSummary.balance / thisMonthSummary.income) * 100)
        .clamp(-100.0, 100.0);
  }

  // Expense change vs last month
  double? expenseChange;
  if (prevMonthSummary.expense > 0) {
    expenseChange = ((thisMonthSummary.expense - prevMonthSummary.expense) /
            prevMonthSummary.expense) *
        100;
  }

  return SmartInsights(
    topCategoryName: topName,
    topCategoryEmoji: topEmoji,
    topCategoryPercent: topPercent,
    savingsRate: savingsRate,
    expenseChangeVsLastMonth: expenseChange,
    hasData: true,
  );
});
