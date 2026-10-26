import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/budget_model.dart';
import '../../providers/budget_provider.dart';
import '../../providers/selected_month_provider.dart';
import 'widgets/set_budget_dialog.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final monthKey = AppDateUtils.toMonthKey(selectedMonth);
    final monthLabel = AppDateUtils.formatMonthYearVi(selectedMonth);

    final overallAsync = ref.watch(overallBudgetProvider);
    final categoryBudgetsAsync = ref.watch(categoryBudgetsProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hạn mức ngân sách'),
        actions: [
          // Month Selector
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkSurfaceLight : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  onPressed: () {
                    ref.read(selectedMonthProvider.notifier).previousMonth();
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    monthLabel,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  onPressed: () {
                    ref.read(selectedMonthProvider.notifier).nextMonth();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Overall Monthly Budget Card
              const Text(
                'Ngân sách tổng tháng',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              overallAsync.when(
                data: (budget) {
                  if (budget == null) {
                    return InkWell(
                      onTap: () {
                        SetBudgetDialog.show(
                          context,
                          monthKey: monthKey,
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkSurfaceLight
                                : const Color(0xFFE2E8F0),
                            strokeAlign: BorderSide.strokeAlignInside,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_circle_outline_rounded,
                                color: AppColors.primary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Thiết lập ngân sách tổng tháng',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Đặt hạn mức để nhận cảnh báo khi gần chạm hoặc vượt trần chi tiêu.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return _buildBudgetCard(
                    context: context,
                    budget: budget,
                    isOverall: true,
                    monthKey: monthKey,
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Lỗi: $err'),
              ),

              const SizedBox(height: 28),

              // 2. Category Budgets Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ngân sách theo danh mục',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(60, 30),
                    ),
                    onPressed: () {
                      SetBudgetDialog.show(
                        context,
                        monthKey: monthKey,
                        forceCategory: true,
                      );
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'Thêm danh mục',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              categoryBudgetsAsync.when(
                data: (budgets) {
                  if (budgets.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkSurfaceLight
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            const Text('🎯', style: TextStyle(fontSize: 36)),
                            const SizedBox(height: 10),
                            const Text(
                              'Chưa có ngân sách danh mục',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Bạn có thể đặt hạn mức riêng cho từng mục như Ăn uống, Mua sắm...',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 14),
                            FilledButton.tonalIcon(
                              onPressed: () {
                                SetBudgetDialog.show(
                                  context,
                                  monthKey: monthKey,
                                  forceCategory: true,
                                );
                              },
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Đặt hạn mức danh mục'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: budgets.map((b) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildBudgetCard(
                          context: context,
                          budget: b,
                          isOverall: false,
                          monthKey: monthKey,
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Lỗi: $err'),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetCard({
    required BuildContext context,
    required BudgetModel budget,
    required bool isOverall,
    required String monthKey,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percent = budget.percentSpent;
    final color = AppColors.getBudgetColor(percent);
    final cat = budget.category;

    return InkWell(
      onTap: () {
        SetBudgetDialog.show(
          context,
          monthKey: monthKey,
          initialBudget: budget,
          forceCategory: !isOverall,
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: budget.isOverBudget
                ? AppColors.budgetDanger.withValues(alpha: 0.5)
                : (isDark ? AppColors.darkSurfaceLight : const Color(0xFFE2E8F0)),
            width: budget.isOverBudget ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Category Icon + Name & Percentage
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: (cat?.color ?? AppColors.primary)
                        .withValues(alpha: isDark ? 0.25 : 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      isOverall ? '💳' : (cat?.emoji ?? '🏷️'),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOverall
                            ? 'Tổng chi tiêu tháng'
                            : (cat?.name ?? 'Danh mục'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Hạn mức: ${CurrencyUtils.format(budget.limitAmount)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(percent * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: percent.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFF1F5F9),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 10),

            // Amounts Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Đã chi: ${CurrencyUtils.format(budget.spentAmount)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  budget.isOverBudget
                      ? 'Vượt: ${CurrencyUtils.format(budget.spentAmount - budget.limitAmount)}'
                      : 'Còn lại: ${CurrencyUtils.format(budget.remainingAmount)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: budget.isOverBudget ? AppColors.budgetDanger : color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Status Badge / Message
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    budget.isOverBudget
                        ? Icons.error_outline_rounded
                        : (percent >= 0.70
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline_rounded),
                    size: 14,
                    color: color,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      budget.statusMessage,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
