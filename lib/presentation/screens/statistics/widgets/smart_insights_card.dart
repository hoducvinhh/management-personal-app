import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../providers/statistics_provider.dart';

class SmartInsightsCard extends StatelessWidget {
  final SmartInsights insights;

  const SmartInsightsCard({
    super.key,
    required this.insights,
  });

  @override
  Widget build(BuildContext context) {
    if (!insights.hasData) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
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
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Nhận định tài chính thông minh',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Insight 1: Top category
          if (insights.topCategoryName != null) ...[
            _buildInsightItem(
              iconEmoji: '💡',
              textSpan: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                children: [
                  const TextSpan(text: 'Danh mục chi nhiều nhất: '),
                  TextSpan(
                    text:
                        '${insights.topCategoryEmoji ?? ""} ${insights.topCategoryName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text:
                        ' (chiếm ${insights.topCategoryPercent.toStringAsFixed(1)}% chi tiêu)',
                    style: const TextStyle(
                      color: AppColors.expense,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Insight 2: Savings Rate
          _buildInsightItem(
            iconEmoji: '📈',
            textSpan: TextSpan(
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              children: [
                const TextSpan(text: 'Tỷ lệ tiết kiệm tháng này: '),
                TextSpan(
                  text: '${insights.savingsRate.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: insights.savingsRate > 0
                        ? AppColors.income
                        : AppColors.expense,
                  ),
                ),
                TextSpan(
                  text: insights.savingsRate >= 20
                      ? ' (Đang tích lũy rất tốt 👍)'
                      : (insights.savingsRate > 0
                          ? ' (Cần duy trì tiết kiệm)'
                          : ' (Chi đang lớn hơn thu ⚠️)'),
                ),
              ],
            ),
          ),

          // Insight 3: Comparison with previous month
          if (insights.expenseChangeVsLastMonth != null) ...[
            const SizedBox(height: 8),
            _buildInsightItem(
              iconEmoji:
                  insights.expenseChangeVsLastMonth! <= 0 ? '📉' : '📊',
              textSpan: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                children: [
                  TextSpan(
                    text: insights.expenseChangeVsLastMonth! <= 0
                        ? 'Chi tiêu giảm '
                        : 'Chi tiêu tăng ',
                  ),
                  TextSpan(
                    text:
                        '${insights.expenseChangeVsLastMonth!.abs().toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: insights.expenseChangeVsLastMonth! <= 0
                          ? AppColors.income
                          : AppColors.expense,
                    ),
                  ),
                  const TextSpan(text: ' so với tháng trước.'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightItem({
    required String iconEmoji,
    required InlineSpan textSpan,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(iconEmoji, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: textSpan,
          ),
        ),
      ],
    );
  }
}
