import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/category_model.dart';
import '../../providers/categories_provider.dart';

class AddCategoryDialog extends ConsumerStatefulWidget {
  final String initialType; // 'EXPENSE' or 'INCOME'

  const AddCategoryDialog({
    super.key,
    this.initialType = 'EXPENSE',
  });

  static Future<void> show(BuildContext context, {String initialType = 'EXPENSE'}) {
    return showDialog(
      context: context,
      builder: (ctx) => AddCategoryDialog(initialType: initialType),
    );
  }

  @override
  ConsumerState<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends ConsumerState<AddCategoryDialog> {
  static const _uuid = Uuid();
  final TextEditingController _nameController = TextEditingController();

  late String _type;
  String _selectedIconCode = 'restaurant';
  String _selectedColorHex = '#FB923C';

  final List<Map<String, String>> _availableIcons = [
    {'code': 'restaurant', 'emoji': '🍜', 'label': 'Ăn uống'},
    {'code': 'local_cafe', 'emoji': '☕', 'label': 'Cà phê'},
    {'code': 'two_wheeler', 'emoji': '🛵', 'label': 'Xe cộ'},
    {'code': 'directions_car', 'emoji': '🚗', 'label': 'Ô tô'},
    {'code': 'home', 'emoji': '🏠', 'label': 'Nhà cửa'},
    {'code': 'shopping_bag', 'emoji': '🛍️', 'label': 'Mua sắm'},
    {'code': 'movie', 'emoji': '🎬', 'label': 'Giải trí'},
    {'code': 'sports_esports', 'emoji': '🎮', 'label': 'Trò chơi'},
    {'code': 'flight', 'emoji': '✈️', 'label': 'Du lịch'},
    {'code': 'fitness_center', 'emoji': '🏋️', 'label': 'Thể thao'},
    {'code': 'medical_services', 'emoji': '💊', 'label': 'Y tế'},
    {'code': 'school', 'emoji': '📚', 'label': 'Học tập'},
    {'code': 'pets', 'emoji': '🐾', 'label': 'Thú cưng'},
    {'code': 'work', 'emoji': '💼', 'label': 'Công việc'},
    {'code': 'card_giftcard', 'emoji': '🎁', 'label': 'Quà tặng'},
    {'code': 'trending_up', 'emoji': '📈', 'label': 'Đầu tư'},
    {'code': 'savings', 'emoji': '💰', 'label': 'Tiết kiệm'},
    {'code': 'inventory_2', 'emoji': '📦', 'label': 'Khác'},
  ];

  final List<String> _availableColors = [
    '#FB923C', // Cam
    '#06B6D4', // Cyan
    '#8B5CF6', // Tím
    '#EC4899', // Hồng
    '#FBBF24', // Vàng
    '#10B981', // Xanh ngọc
    '#3B82F6', // Xanh dương
    '#EF4444', // Đỏ
    '#14B8A6', // Teal
    '#94A3B8', // Xám
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    if (_type == 'INCOME') {
      _selectedIconCode = 'work';
      _selectedColorHex = '#10B981';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên danh mục'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final newCat = CategoryModel(
      id: _uuid.v4(),
      name: name,
      type: _type,
      iconCode: _selectedIconCode,
      colorHex: _selectedColorHex,
      isDefault: false,
    );

    await ref.read(categoriesProvider.notifier).addCategory(newCat);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Thêm danh mục mới',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Segmented Button: Chi vs Thu
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'EXPENSE',
                  label: Text('Khoản chi'),
                  icon: Icon(Icons.arrow_downward_rounded, size: 16),
                ),
                ButtonSegment(
                  value: 'INCOME',
                  label: Text('Khoản thu'),
                  icon: Icon(Icons.arrow_upward_rounded, size: 16),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (set) {
                setState(() {
                  _type = set.first;
                });
              },
            ),
            const SizedBox(height: 16),

            // Tên danh mục
            const Text(
              'Tên danh mục',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Ví dụ: Cà phê, Du lịch, Nuôi thú...',
                filled: true,
                fillColor: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Chọn Icon
            const Text(
              'Chọn biểu tượng (Icon)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableIcons.map((item) {
                final isSelected = item['code'] == _selectedIconCode;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedIconCode = item['code']!;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : (isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(item['emoji']!, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Chọn Màu sắc
            const Text(
              'Chọn màu đại diện',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableColors.map((hex) {
                final color = _parseColor(hex);
                final isSelected = hex == _selectedColorHex;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedColorHex = hex;
                    });
                  },
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 6,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _submit,
          child: const Text('Tạo danh mục'),
        ),
      ],
    );
  }
}
