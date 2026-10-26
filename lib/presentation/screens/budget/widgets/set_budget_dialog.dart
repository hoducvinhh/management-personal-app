import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../data/models/budget_model.dart';
import '../../../../data/models/category_model.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/categories_provider.dart';

class SetBudgetDialog extends ConsumerStatefulWidget {
  final String monthKey;
  final BudgetModel? initialBudget;
  final bool forceCategory;

  const SetBudgetDialog({
    super.key,
    required this.monthKey,
    this.initialBudget,
    this.forceCategory = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String monthKey,
    BudgetModel? initialBudget,
    bool forceCategory = false,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => SetBudgetDialog(
        monthKey: monthKey,
        initialBudget: initialBudget,
        forceCategory: forceCategory,
      ),
    );
  }

  @override
  ConsumerState<SetBudgetDialog> createState() => _SetBudgetDialogState();
}

class _SetBudgetDialogState extends ConsumerState<SetBudgetDialog> {
  late bool _isOverall;
  String? _selectedCategoryId;
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final b = widget.initialBudget;
    if (b != null) {
      _isOverall = b.isOverall;
      _selectedCategoryId = b.categoryId;
      _amountController.text =
          CurrencyUtils.formatWithoutSymbol(b.limitAmount);
    } else {
      _isOverall = !widget.forceCategory;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = CurrencyUtils.parseAmount(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập hạn mức lớn hơn 0 ₫'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_isOverall && _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn danh mục cho ngân sách'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final actions = ref.read(budgetActionsProvider);
    await actions.setBudget(
      categoryId: _isOverall ? null : _selectedCategoryId,
      monthKey: widget.monthKey,
      limitAmount: amount,
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseCategories = ref.watch(expenseCategoriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.initialBudget != null ? 'Sửa hạn mức ngân sách' : 'Đặt hạn mức ngân sách',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Option: Overall vs Category
            if (widget.initialBudget == null && !widget.forceCategory) ...[
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Tổng tháng'),
                    icon: Icon(Icons.all_inclusive_rounded),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Danh mục'),
                    icon: Icon(Icons.category_rounded),
                  ),
                ],
                selected: {_isOverall},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _isOverall = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            // Select category if category budget
            if (!_isOverall) ...[
              const Text(
                'Chọn danh mục',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedCategoryId ??
                        (expenseCategories.isNotEmpty
                            ? expenseCategories.first.id
                            : null),
                    hint: const Text('Chọn danh mục chi tiêu'),
                    items: expenseCategories.map((CategoryModel cat) {
                      return DropdownMenuItem<String>(
                        value: cat.id,
                        child: Row(
                          children: [
                            Text(cat.emoji, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(cat.name, style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCategoryId = val;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Input limit amount
            const Text(
              'Hạn mức chi tiêu tối đa (₫)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '5.000.000',
                suffixText: '₫',
                filled: true,
                fillColor: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Quick amount buttons
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _quickChip('1Tr', 1000000),
                  _quickChip('2Tr', 2000000),
                  _quickChip('5Tr', 5000000),
                  _quickChip('10Tr', 10000000),
                  _quickChip('20Tr', 20000000),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.initialBudget != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Xác nhận xóa ngân sách'),
                  content: const Text('Bạn có chắc muốn xóa hạn mức này?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Hủy'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.expense,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Xóa'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref
                    .read(budgetActionsProvider)
                    .deleteBudget(widget.initialBudget!.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Xóa'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _submit,
          child: const Text('Lưu'),
        ),
      ],
    );
  }

  Widget _quickChip(String label, int val) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        onPressed: () {
          setState(() {
            _amountController.text = CurrencyUtils.formatWithoutSymbol(val);
          });
        },
      ),
    );
  }
}
