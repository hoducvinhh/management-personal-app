import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../providers/budget_provider.dart';
import '../../providers/selected_month_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/transactions_provider.dart';
import '../budget/widgets/set_budget_dialog.dart';
import '../transaction_form/quick_transaction_sheet.dart';
import 'widgets/balance_hero_card.dart';
import 'widgets/mini_budget_gauge.dart';
import 'widgets/transaction_item_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final recentTxAsync = ref.watch(recentTransactionsProvider);
    final overallBudgetAsync = ref.watch(overallBudgetProvider);

    final monthLabel = AppDateUtils.formatMonthYearVi(selectedMonth);
    final greeting = AppDateUtils.getGreeting();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.read(transactionVersionProvider.notifier).bump();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. App Header with greeting and month switcher (100% responsive, zero overflow)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Flexible(
                                  child: Text(
                                    'Quản lý chi tiêu',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  icon: Icon(
                                    isDark
                                        ? Icons.light_mode_rounded
                                        : Icons.dark_mode_rounded,
                                    size: 20,
                                    color: isDark
                                        ? const Color(0xFFFBBF24)
                                        : const Color(0xFFF59E0B),
                                  ),
                                  tooltip: isDark
                                      ? 'Chế độ sáng'
                                      : 'Chế độ tối',
                                  onPressed: () {
                                    ref
                                        .read(themeModeProvider.notifier)
                                        .toggle();
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Month Selector with < >
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardTheme.color,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkSurfaceLight
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.chevron_left_rounded,
                                    size: 18,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 26,
                                    minHeight: 26,
                                  ),
                                  onPressed: () {
                                    ref
                                        .read(selectedMonthProvider.notifier)
                                        .previousMonth();
                                  },
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    monthLabel,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 26,
                                    minHeight: 26,
                                  ),
                                  onPressed: () {
                                    ref
                                        .read(selectedMonthProvider.notifier)
                                        .nextMonth();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Hero Card (Số dư, tổng thu, tổng chi)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: summaryAsync.when(
                    data: (summary) => BalanceHeroCard(summary: summary),
                    loading: () => Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (_, _) => BalanceHeroCard(
                      summary: MonthlySummary.zero(),
                    ),
                  ),
                ),
              ),

              // 3. Mini Budget Gauge
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: overallBudgetAsync.when(
                    data: (budget) => MiniBudgetGauge(
                      overallBudget: budget,
                      onSetupBudget: () {
                        SetBudgetDialog.show(
                          context,
                          monthKey: AppDateUtils.toMonthKey(selectedMonth),
                          initialBudget: budget,
                        );
                      },
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ),
              ),

              // 4. Section Title: "Giao dịch gần đây"
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Giao dịch gần đây',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          QuickTransactionSheet.show(context);
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.add_circle_outline_rounded,
                                size: 16, color: AppColors.tabOverview),
                            SizedBox(width: 4),
                            Text(
                              'Thêm mới',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.tabOverview,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 5. Recent Transactions List (Grouped by Date)
              recentTxAsync.when(
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkSurfaceLight
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text('🌱', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            const Text(
                              'Chưa có giao dịch trong tháng',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Bắt đầu ghi chép chi tiêu để quản lý tài chính hiệu quả hơn nhé!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () =>
                                  QuickTransactionSheet.show(context),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Thêm giao dịch đầu tiên'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final grouped = <String, List<TransactionModel>>{};
                  for (final tx in transactions) {
                    final dateKey = AppDateUtils.formatRelativeDate(tx.date);
                    grouped.putIfAbsent(dateKey, () => []).add(tx);
                  }

                  final dateKeys = grouped.keys.toList();

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, groupIndex) {
                          final dateKey = dateKeys[groupIndex];
                          final groupItems = grouped[dateKey]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 10,
                                  bottom: 6,
                                  left: 4,
                                ),
                                child: Text(
                                  dateKey,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              ...groupItems.map((tx) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: TransactionItemTile(
                                    transaction: tx,
                                    onTap: () {
                                      QuickTransactionSheet.show(
                                        context,
                                        editTransaction: tx,
                                      );
                                    },
                                    onDelete: () {
                                      ref
                                          .read(transactionActionsProvider)
                                          .deleteTransaction(tx.id);
                                    },
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                        childCount: dateKeys.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
                error: (err, _) => SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text('Lỗi tải dữ liệu: $err'),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
