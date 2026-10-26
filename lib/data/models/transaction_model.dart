import 'category_model.dart';

class TransactionModel {
  final String id;
  final double amount;
  final String type; // 'EXPENSE' or 'INCOME'
  final String categoryId;
  final DateTime date;
  final String? note;
  final DateTime createdAt;

  // Joined category data (if joined in SQL query)
  final CategoryModel? category;

  const TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.date,
    this.note,
    required this.createdAt,
    this.category,
  });

  bool get isExpense => type == 'EXPENSE';
  bool get isIncome => type == 'INCOME';

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    CategoryModel? category;
    if (map.containsKey('category_name') && map['category_name'] != null) {
      category = CategoryModel(
        id: map['category_id'] as String,
        name: map['category_name'] as String,
        type: map['category_type'] as String? ?? map['type'] as String,
        iconCode: map['category_icon_code'] as String? ?? 'inventory_2',
        colorHex: map['category_color_hex'] as String? ?? '#94A3B8',
        isDefault: (map['category_is_default'] as int? ?? 0) == 1,
      );
    }

    return TransactionModel(
      id: map['id'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      categoryId: map['category_id'] as String,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      category: category,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'type': type,
      'category_id': categoryId,
      'date': date.toIso8601String(),
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  TransactionModel copyWith({
    String? id,
    double? amount,
    String? type,
    String? categoryId,
    DateTime? date,
    String? note,
    DateTime? createdAt,
    CategoryModel? category,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
    );
  }
}
