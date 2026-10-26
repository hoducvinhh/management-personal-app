import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../data/repositories/transaction_repository.dart';

class ExpenseDonutChart extends StatefulWidget {
  final List<CategoryExpenseItem> items;
  final double totalExpense;

  const ExpenseDonutChart({
    super.key,
    required this.items,
    required this.totalExpense,
  });

  @override
  State<ExpenseDonutChart> createState() => _ExpenseDonutChartState();
}

class _ExpenseDonutChartState extends State<ExpenseDonutChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.items.isEmpty || widget.totalExpense <= 0) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.darkSurfaceLight : const Color(0xFFE2E8F0),
          ),
        ),
        child: const Center(
          child: Column(
            children: [
              Text('📊', style: TextStyle(fontSize: 40)),
              SizedBox(height: 10),
              Text(
                'Chưa có dữ liệu chi tiêu trong tháng',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Hãy thêm các khoản chi để xem phân tích biểu đồ.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Auto-group < 3% into "Khác" if there are > 5 items
    final displayItems = <_ChartSegment>[];
    double othersTotal = 0.0;
    double othersPercent = 0.0;

    for (int i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      if (widget.items.length > 5 && item.percentage < 3.0) {
        othersTotal += item.totalAmount;
        othersPercent += item.percentage;
      } else {
        displayItems.add(_ChartSegment(
          name: item.category.name,
          emoji: item.category.emoji,
          amount: item.totalAmount,
          percentage: item.percentage,
          color: item.category.color,
        ));
      }
    }

    if (othersTotal > 0) {
      displayItems.add(_ChartSegment(
        name: 'Khác',
        emoji: '📦',
        amount: othersTotal,
        percentage: othersPercent,
        color: const Color(0xFF94A3B8),
      ));
    }

    // Touched item
    final touchedSegment = (_touchedIndex >= 0 && _touchedIndex < displayItems.length)
        ? displayItems[_touchedIndex]
        : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.darkSurfaceLight : const Color(0xFFE2E8F0),
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
          const Text(
            'Cơ cấu chi tiêu',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Donut Chart with Center Information
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedIndex = -1;
                            return;
                          }
                          _touchedIndex = pieTouchResponse
                              .touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 3,
                    centerSpaceRadius: 65,
                    sections: List.generate(displayItems.length, (i) {
                      final isTouched = i == _touchedIndex;
                      final seg = displayItems[i];
                      final radius = isTouched ? 46.0 : 36.0;

                      return PieChartSectionData(
                        color: seg.color,
                        value: seg.amount,
                        title: isTouched
                            ? '${seg.percentage.toStringAsFixed(0)}%'
                            : '',
                        radius: radius,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }),
                  ),
                ),
                // Center information widget (Constrained width with FittedBox)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (touchedSegment != null) ...[
                        Text(
                          touchedSegment.emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            touchedSegment.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            CurrencyUtils.format(touchedSegment.amount),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: touchedSegment.color,
                            ),
                          ),
                        ),
                        Text(
                          '${touchedSegment.percentage.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'Tổng chi tháng',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            CurrencyUtils.format(widget.totalExpense),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.expense,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Chạm để xem',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Legend Cards ranked from highest to lowest
          const Text(
            'Bảng xếp hạng chi tiêu',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Column(
            children: widget.items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBackground
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkSurfaceLight
                          : const Color(0xFFF1F5F9),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: item.category.color.withValues(
                                  alpha: isDark ? 0.25 : 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                item.category.emoji,
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.category.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              CurrencyUtils.format(item.totalAmount),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${item.percentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: item.category.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (item.percentage / 100).clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFE2E8F0),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(item.category.color),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ChartSegment {
  final String name;
  final String emoji;
  final double amount;
  final double percentage;
  final Color color;

  _ChartSegment({
    required this.name,
    required this.emoji,
    required this.amount,
    required this.percentage,
    required this.color,
  });
}
