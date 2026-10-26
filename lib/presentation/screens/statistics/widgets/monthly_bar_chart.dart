import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../data/repositories/transaction_repository.dart';

class MonthlyBarChart extends StatelessWidget {
  final List<MonthTrendItem> trends;

  const MonthlyBarChart({
    super.key,
    required this.trends,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (trends.isEmpty) return const SizedBox.shrink();

    // Find max value to calibrate Y axis
    double maxAmount = 0.0;
    for (final t in trends) {
      maxAmount = max(maxAmount, max(t.income, t.expense));
    }
    if (maxAmount == 0.0) maxAmount = 1000000;
    final maxY = maxAmount * 1.25;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'So sánh Thu - Chi 6 tháng',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Legend
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegendIndicator(AppColors.income, 'Thu'),
                  const SizedBox(width: 8),
                  _buildLegendIndicator(AppColors.expense, 'Chi'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bar Chart with fitInsideHorizontally / Vertically
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF0F172A),
                    tooltipBorderRadius: BorderRadius.circular(12),
                    tooltipPadding: const EdgeInsets.all(10),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = trends[group.x.toInt()];
                      return BarTooltipItem(
                        '${item.label}\n',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: '🟢 Thu: +${CurrencyUtils.format(item.income)}\n',
                            style: const TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: '🔴 Chi: -${CurrencyUtils.format(item.expense)}\n',
                            style: const TextStyle(
                              color: Color(0xFFFB7185),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text:
                                '💎 Dư: ${CurrencyUtils.formatSigned(item.savings, item.savings >= 0 ? "INCOME" : "EXPENSE")}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        if (value == meta.max) return const SizedBox.shrink();
                        return FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            CurrencyUtils.formatCompact(value),
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < trends.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              trends[index].label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(trends.length, (index) {
                  final t = trends[index];
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      // Thu (Income) Bar
                      BarChartRodData(
                        toY: t.income,
                        width: 9,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF34D399),
                            Color(0xFF10B981),
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                      // Chi (Expense) Bar
                      BarChartRodData(
                        toY: t.expense,
                        width: 9,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFB7185),
                            Color(0xFFF43F5E),
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendIndicator(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
