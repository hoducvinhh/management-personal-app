import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/budget_model.dart';
import '../../data/repositories/budget_repository.dart';
import 'selected_month_provider.dart';
import 'transactions_provider.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository();
});

class BudgetVersionNotifier extends StateNotifier<int> {
  BudgetVersionNotifier() : super(0);
  void bump() => state = state + 1;
}

final budgetVersionProvider =
    StateNotifierProvider<BudgetVersionNotifier, int>((ref) {
  return BudgetVersionNotifier();
});

// Overall monthly budget
final overallBudgetProvider =
    FutureProvider.autoDispose<BudgetModel?>((ref) async {
  ref.watch(budgetVersionProvider);
  ref.watch(transactionVersionProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);
  final repo = ref.watch(budgetRepositoryProvider);

  final monthKey = AppDateUtils.toMonthKey(selectedMonth);
  return repo.getOverallBudget(monthKey);
});

// Category budgets
final categoryBudgetsProvider =
    FutureProvider.autoDispose<List<BudgetModel>>((ref) async {
  ref.watch(budgetVersionProvider);
  ref.watch(transactionVersionProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);
  final repo = ref.watch(budgetRepositoryProvider);

  final monthKey = AppDateUtils.toMonthKey(selectedMonth);
  return repo.getCategoryBudgets(monthKey);
});

class BudgetActionsNotifier {
  final Ref _ref;

  BudgetActionsNotifier(this._ref);

  Future<void> setBudget({
    String? categoryId,
    required String monthKey,
    required double limitAmount,
  }) async {
    final repo = _ref.read(budgetRepositoryProvider);
    await repo.setBudget(
      categoryId: categoryId,
      monthKey: monthKey,
      limitAmount: limitAmount,
    );
    _ref.read(budgetVersionProvider.notifier).bump();
  }

  Future<void> deleteBudget(String id) async {
    final repo = _ref.read(budgetRepositoryProvider);
    await repo.deleteBudget(id);
    _ref.read(budgetVersionProvider.notifier).bump();
  }
}

final budgetActionsProvider = Provider<BudgetActionsNotifier>((ref) {
  return BudgetActionsNotifier(ref);
});
