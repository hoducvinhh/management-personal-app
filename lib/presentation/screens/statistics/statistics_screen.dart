import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../providers/selected_month_provider.dart';
import '../../providers/statistics_provider.dart';
import '../../providers/transactions_provider.dart';
import 'widgets/expense_donut_chart.dart';
import 'widgets/monthly_bar_chart.dart';
import 'widgets/smart_insights_card.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final monthLabel = AppDateUtils.formatMonthYearVi(selectedMonth);

    final breakdownAsync = ref.watch(categoryExpenseBreakdownProvider);
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final trendsAsync = ref.watch(monthlyTrendsProvider);
    final insightsAsync = ref.watch(smartInsightsProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Thống kê tài chính',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Month Selector
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
        child: RefreshIndicator(
          onRefresh: () async {
            ref.read(transactionVersionProvider.notifier).bump();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Smart Insights Card
                insightsAsync.when(
                  data: (insights) => SmartInsightsCard(insights: insights),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),

                // 2. Donut Pie Chart (Cơ cấu chi tiêu)
                breakdownAsync.when(
                  data: (items) {
                    final totalExpense = summaryAsync.maybeWhen(
                      data: (s) => s.expense,
                      orElse: () => 0.0,
                    );
                    return ExpenseDonutChart(
                      items: items,
                      totalExpense: totalExpense,
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => Center(child: Text('Lỗi tải dữ liệu: $err')),
                ),
                const SizedBox(height: 16),

                // 3. Bar Chart (So sánh Thu - Chi qua các tháng)
                trendsAsync.when(
                  data: (trends) => MonthlyBarChart(trends: trends),
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => Center(child: Text('Lỗi tải dữ liệu: $err')),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
