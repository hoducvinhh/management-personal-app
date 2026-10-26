import 'package:flutter/material.dart';
import '../../core/constants/default_categories.dart';

class CategoryModel {
  final String id;
  final String name;
  final String type; // 'EXPENSE' or 'INCOME'
  final String iconCode;
  final String colorHex;
  final bool isDefault;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.iconCode,
    required this.colorHex,
    this.isDefault = false,
  });

  IconData get iconData => DefaultCategories.getIconData(iconCode);
  Color get color => DefaultCategories.parseHexColor(colorHex);
  String get emoji => DefaultCategories.getEmoji(iconCode);
  bool get isExpense => type == 'EXPENSE';
  bool get isIncome => type == 'INCOME';

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      iconCode: map['icon_code'] as String,
      colorHex: map['color_hex'] as String,
      isDefault: (map['is_default'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'icon_code': iconCode,
      'color_hex': colorHex,
      'is_default': isDefault ? 1 : 0,
    };
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    String? type,
    String? iconCode,
    String? colorHex,
    bool? isDefault,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      iconCode: iconCode ?? this.iconCode,
      colorHex: colorHex ?? this.colorHex,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
