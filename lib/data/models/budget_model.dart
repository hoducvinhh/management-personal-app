import '../../core/utils/currency_utils.dart';
import 'category_model.dart';

class BudgetModel {
  final String id;
  final String? categoryId; // null = Ngân sách tổng tháng
  final String monthKey; // 'YYYY-MM'
  final double limitAmount;
  final double spentAmount;
  final CategoryModel? category;

  const BudgetModel({
    required this.id,
    this.categoryId,
    required this.monthKey,
    required this.limitAmount,
    this.spentAmount = 0.0,
    this.category,
  });

  bool get isOverall => categoryId == null || categoryId!.isEmpty;
  double get remainingAmount => limitAmount - spentAmount;
  double get percentSpent =>
      limitAmount > 0 ? (spentAmount / limitAmount).clamp(0.0, 2.0) : 0.0;
  bool get isOverBudget => spentAmount > limitAmount;
  double get overBudgetAmount => isOverBudget ? (spentAmount - limitAmount) : 0.0;

  String get statusMessage {
    if (isOverBudget) {
      final over = spentAmount - limitAmount;
      return 'Nguy cơ bội chi! Đã vượt hạn mức ${CurrencyUtils.format(over)}';
    } else if (percentSpent >= 0.90) {
      final pct = (percentSpent * 100).toStringAsFixed(0);
      return 'Báo động: Đã tiêu $pct% hạn mức!';
    } else if (percentSpent >= 0.70) {
      final pct = (percentSpent * 100).toStringAsFixed(0);
      return 'Cảnh báo: Đã tiêu $pct% ngân sách';
    } else {
      return 'Bạn đang kiểm soát chi tiêu rất tốt';
    }
  }

  factory BudgetModel.fromMap(
    Map<String, dynamic> map, {
    double spentAmount = 0.0,
    CategoryModel? category,
  }) {
    return BudgetModel(
      id: map['id'] as String,
      categoryId: map['category_id'] as String?,
      monthKey: map['month_key'] as String,
      limitAmount: (map['limit_amount'] as num).toDouble(),
      spentAmount: spentAmount,
      category: category,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'month_key': monthKey,
      'limit_amount': limitAmount,
    };
  }

  BudgetModel copyWith({
    String? id,
    String? categoryId,
    String? monthKey,
    double? limitAmount,
    double? spentAmount,
    CategoryModel? category,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      monthKey: monthKey ?? this.monthKey,
      limitAmount: limitAmount ?? this.limitAmount,
      spentAmount: spentAmount ?? this.spentAmount,
      category: category ?? this.category,
    );
  }
}
