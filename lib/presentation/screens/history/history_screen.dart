import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../providers/categories_provider.dart';
import '../../providers/transactions_provider.dart';
import '../home/widgets/transaction_item_tile.dart';
import '../transaction_form/quick_transaction_sheet.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(historyFilterProvider.notifier).setSearchQuery(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(historyFilterProvider);
    final filterNotifier = ref.read(historyFilterProvider.notifier);
    final transactionsAsync = ref.watch(filteredTransactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử giao dịch'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: () {
              ref.read(transactionVersionProvider.notifier).bump();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkSurfaceLight
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Tìm theo ghi chú, danh mục hoặc số tiền...',
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 14,
                    ),
                  ),
                ),
              ),
            ),

            // 2. Filter Chips: Type & Time Range
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Type filter
                  _buildFilterChip(
                    label: 'Tất cả',
                    isSelected: filter.type == 'ALL',
                    onSelected: () => filterNotifier.setType('ALL'),
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: 'Khoản chi',
                    isSelected: filter.type == 'EXPENSE',
                    selectedColor: AppColors.expense,
                    onSelected: () => filterNotifier.setType('EXPENSE'),
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: 'Khoản thu',
                    isSelected: filter.type == 'INCOME',
                    selectedColor: AppColors.income,
                    onSelected: () => filterNotifier.setType('INCOME'),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 1,
                    height: 24,
                    color: Colors.grey.withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 12),

                  // Time range filter
                  _buildFilterChip(
                    label: 'Tháng này',
                    isSelected: filter.timeRange == HistoryTimeRange.thisMonth,
                    onSelected: () =>
                        filterNotifier.setTimeRange(HistoryTimeRange.thisMonth),
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: 'Tháng trước',
                    isSelected: filter.timeRange == HistoryTimeRange.lastMonth,
                    onSelected: () =>
                        filterNotifier.setTimeRange(HistoryTimeRange.lastMonth),
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: 'Hôm nay',
                    isSelected: filter.timeRange == HistoryTimeRange.today,
                    onSelected: () =>
                        filterNotifier.setTimeRange(HistoryTimeRange.today),
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: 'Tất cả thời gian',
                    isSelected: filter.timeRange == HistoryTimeRange.all,
                    onSelected: () =>
                        filterNotifier.setTimeRange(HistoryTimeRange.all),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Category filter chips
            categoriesAsync.maybeWhen(
              data: (categories) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'Mọi danh mục',
                        isSelected: filter.categoryId == 'ALL',
                        onSelected: () => filterNotifier.setCategoryId('ALL'),
                      ),
                      ...categories.map((c) {
                        final isSelected = filter.categoryId == c.id;
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: _buildFilterChip(
                            label: '${c.emoji} ${c.name}',
                            isSelected: isSelected,
                            selectedColor: c.color,
                            onSelected: () => filterNotifier.setCategoryId(c.id),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),

            const Divider(height: 16, thickness: 0.5),

            // 3. Transactions List
            Expanded(
              child: transactionsAsync.when(
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🔍', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          const Text(
                            'Không tìm thấy giao dịch nào',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Thử đổi bộ lọc hoặc tìm kiếm bằng từ khóa khác nhé.',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: () {
                              _searchController.clear();
                              filterNotifier.reset();
                            },
                            icon: const Icon(Icons.restart_alt_rounded),
                            label: const Text('Đặt lại bộ lọc'),
                          ),
                        ],
                      ),
                    );
                  }

                  // Summary bar of filtered items
                  double totalExpense = 0.0;
                  double totalIncome = 0.0;
                  for (final tx in transactions) {
                    if (tx.isIncome) {
                      totalIncome += tx.amount;
                    } else {
                      totalExpense += tx.amount;
                    }
                  }

                  return Column(
                    children: [
                      // Mini status bar
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${transactions.length} giao dịch',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                            Row(
                              children: [
                                if (totalIncome > 0)
                                  Text(
                                    '+${CurrencyUtils.format(totalIncome)}  ',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.income,
                                    ),
                                  ),
                                if (totalExpense > 0)
                                  Text(
                                    '-${CurrencyUtils.format(totalExpense)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.expense,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // List
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: transactions.length,
                          itemBuilder: (ctx, index) {
                            final tx = transactions[index];
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
                          },
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Lỗi tải dữ liệu: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    Color? selectedColor,
    required VoidCallback onSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = selectedColor ?? AppColors.primary;

    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.25 : 0.15)
              : (isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? AppColors.darkSurfaceLight : Colors.transparent),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? activeColor
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }
}
