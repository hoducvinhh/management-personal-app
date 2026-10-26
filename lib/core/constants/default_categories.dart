import 'package:flutter/material.dart';

class CategorySeedData {
  final String id;
  final String name;
  final String type; // 'EXPENSE' or 'INCOME'
  final String iconCode;
  final String emoji;
  final String colorHex;
  final bool isDefault;

  const CategorySeedData({
    required this.id,
    required this.name,
    required this.type,
    required this.iconCode,
    required this.emoji,
    required this.colorHex,
    this.isDefault = true,
  });
}

class DefaultCategories {
  static const List<CategorySeedData> expenseCategories = [
    CategorySeedData(
      id: 'cat_exp_food',
      name: 'Ăn uống',
      type: 'EXPENSE',
      iconCode: 'restaurant',
      emoji: '🍜',
      colorHex: '#FB923C',
    ),
    CategorySeedData(
      id: 'cat_exp_transport',
      name: 'Di chuyển',
      type: 'EXPENSE',
      iconCode: 'two_wheeler',
      emoji: '🛵',
      colorHex: '#06B6D4',
    ),
    CategorySeedData(
      id: 'cat_exp_housing',
      name: 'Nhà cửa & Hóa đơn',
      type: 'EXPENSE',
      iconCode: 'home',
      emoji: '🏠',
      colorHex: '#8B5CF6',
    ),
    CategorySeedData(
      id: 'cat_exp_shopping',
      name: 'Mua sắm',
      type: 'EXPENSE',
      iconCode: 'shopping_bag',
      emoji: '🛍️',
      colorHex: '#EC4899',
    ),
    CategorySeedData(
      id: 'cat_exp_entertainment',
      name: 'Giải trí',
      type: 'EXPENSE',
      iconCode: 'movie',
      emoji: '🎬',
      colorHex: '#FBBF24',
    ),
    CategorySeedData(
      id: 'cat_exp_health',
      name: 'Sức khỏe & Y tế',
      type: 'EXPENSE',
      iconCode: 'medical_services',
      emoji: '💊',
      colorHex: '#14B8A6',
    ),
    CategorySeedData(
      id: 'cat_exp_education',
      name: 'Học tập & Tri thức',
      type: 'EXPENSE',
      iconCode: 'school',
      emoji: '📚',
      colorHex: '#3B82F6',
    ),
    CategorySeedData(
      id: 'cat_exp_family',
      name: 'Gia đình',
      type: 'EXPENSE',
      iconCode: 'family_restroom',
      emoji: '👨‍👩‍👧',
      colorHex: '#7C3AED',
    ),
    CategorySeedData(
      id: 'cat_exp_other',
      name: 'Khoản chi khác',
      type: 'EXPENSE',
      iconCode: 'inventory_2',
      emoji: '📦',
      colorHex: '#94A3B8',
    ),
  ];

  static const List<CategorySeedData> incomeCategories = [
    CategorySeedData(
      id: 'cat_inc_salary',
      name: 'Tiền lương',
      type: 'INCOME',
      iconCode: 'work',
      emoji: '💼',
      colorHex: '#10B981',
    ),
    CategorySeedData(
      id: 'cat_inc_bonus',
      name: 'Thưởng & Lì xì',
      type: 'INCOME',
      iconCode: 'card_giftcard',
      emoji: '🎁',
      colorHex: '#EF4444',
    ),
    CategorySeedData(
      id: 'cat_inc_investment',
      name: 'Đầu tư & Tiết kiệm',
      type: 'INCOME',
      iconCode: 'trending_up',
      emoji: '📈',
      colorHex: '#EAB308',
    ),
    CategorySeedData(
      id: 'cat_inc_side_job',
      name: 'Thu nhập phụ',
      type: 'INCOME',
      iconCode: 'lightbulb',
      emoji: '💡',
      colorHex: '#A855F7',
    ),
    CategorySeedData(
      id: 'cat_inc_other',
      name: 'Thu nhập khác',
      type: 'INCOME',
      iconCode: 'account_balance_wallet',
      emoji: '💰',
      colorHex: '#0EA5E9',
    ),
  ];

  static List<CategorySeedData> get all => [
        ...expenseCategories,
        ...incomeCategories,
      ];

  static IconData getIconData(String iconCode) {
    switch (iconCode) {
      case 'restaurant':
      case 'fastfood':
        return Icons.restaurant;
      case 'two_wheeler':
      case 'motorcycle':
      case 'directions_bike':
        return Icons.two_wheeler;
      case 'home':
        return Icons.home_rounded;
      case 'shopping_bag':
      case 'shopping_cart':
        return Icons.shopping_bag_rounded;
      case 'movie':
        return Icons.movie_rounded;
      case 'medical_services':
        return Icons.medical_services_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'family_restroom':
        return Icons.family_restroom_rounded;
      case 'inventory_2':
        return Icons.category_rounded;
      case 'work':
        return Icons.work_rounded;
      case 'card_giftcard':
        return Icons.card_giftcard_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'lightbulb':
        return Icons.lightbulb_rounded;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.attach_money_rounded;
    }
  }

  static String getEmoji(String iconCode) {
    for (final cat in all) {
      if (cat.iconCode == iconCode) return cat.emoji;
    }
    return '🏷️';
  }

  static Color parseHexColor(String hex) {
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
  }
}
