import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/transaction_model.dart';
import '../../providers/categories_provider.dart';
import '../../providers/transactions_provider.dart';
import '../../widgets/category/add_category_dialog.dart';

class QuickTransactionSheet extends ConsumerStatefulWidget {
  final TransactionModel? editTransaction;

  const QuickTransactionSheet({
    super.key,
    this.editTransaction,
  });

  static Future<void> show(BuildContext context, {TransactionModel? editTransaction}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickTransactionSheet(editTransaction: editTransaction),
    );
  }

  @override
  ConsumerState<QuickTransactionSheet> createState() =>
      _QuickTransactionSheetState();
}

class _QuickTransactionSheetState
    extends ConsumerState<QuickTransactionSheet> {
  static const _uuid = Uuid();

  late String _type; // 'EXPENSE' or 'INCOME'
  late double _amount;
  String? _selectedCategoryId;
  late DateTime _selectedDate;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final edit = widget.editTransaction;
    if (edit != null) {
      _type = edit.type;
      _amount = edit.amount;
      _selectedCategoryId = edit.categoryId;
      _selectedDate = edit.date;
      _noteController.text = edit.note ?? '';
      _amountController.text = CurrencyUtils.formatWithoutSymbol(_amount);
    } else {
      _type = 'EXPENSE';
      _amount = 0.0;
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    final parsed = CurrencyUtils.parseAmount(val) ?? 0.0;
    setState(() {
      _amount = parsed;
    });
  }

  void _addQuickAmount(int add) {
    HapticFeedback.lightImpact();
    setState(() {
      _amount += add;
      _amountController.text = CurrencyUtils.formatWithoutSymbol(_amount);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'CHỌN NGÀY GIAO DỊCH',
      cancelText: 'HỦY',
      confirmText: 'CHỌN',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _save() async {
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số tiền lớn hơn 0'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn danh mục'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    final actions = ref.read(transactionActionsProvider);

    if (widget.editTransaction != null) {
      final updated = widget.editTransaction!.copyWith(
        amount: _amount,
        type: _type,
        categoryId: _selectedCategoryId!,
        date: _selectedDate,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      await actions.updateTransaction(updated);
    } else {
      final newTx = TransactionModel(
        id: _uuid.v4(),
        amount: _amount,
        type: _type,
        categoryId: _selectedCategoryId!,
        date: _selectedDate,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        createdAt: DateTime.now(),
      );
      await actions.addTransaction(newTx);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = _type == 'EXPENSE'
        ? ref.watch(expenseCategoriesProvider)
        : ref.watch(incomeCategoriesProvider);

    if (categories.isNotEmpty &&
        (_selectedCategoryId == null ||
            !categories.any((c) => c.id == _selectedCategoryId))) {
      _selectedCategoryId = categories.first.id;
    }

    final isIncome = _type == 'INCOME';
    final primaryActiveColor = isIncome ? AppColors.income : AppColors.expense;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top drag pill
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title and Mode
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.editTransaction != null
                        ? 'Chỉnh sửa giao dịch'
                        : 'Thêm giao dịch mới',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 1. Segmented Control: Khoản Chi vs Khoản Thu
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _type = 'EXPENSE';
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_typeIsIncome
                                ? AppColors.expense
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: !_typeIsIncome
                                ? [
                                    BoxShadow(
                                      color: AppColors.expense.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                    )
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'Khoản chi',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: !_typeIsIncome
                                    ? Colors.white
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _type = 'INCOME';
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _typeIsIncome
                                ? AppColors.income
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _typeIsIncome
                                ? [
                                    BoxShadow(
                                      color: AppColors.income.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                    )
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'Khoản thu',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _typeIsIncome
                                    ? Colors.white
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 2. Ô Nhập Số Tiền Cực Lớn
              Center(
                child: Column(
                  children: [
                    Text(
                      'Số tiền',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    IntrinsicWidth(
                      child: TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: primaryActiveColor,
                          letterSpacing: -0.5,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: '0',
                          hintStyle: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: primaryActiveColor.withValues(alpha: 0.3),
                          ),
                          suffixText: ' ₫',
                          suffixStyle: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: primaryActiveColor,
                          ),
                        ),
                        onChanged: _onAmountChanged,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Phím tắt cộng tiền nhanh: +10k, +50k, +100k, +500k, +1Tr
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    AppConstants.quickAddAmounts.length,
                    (index) {
                      final amountVal = AppConstants.quickAddAmounts[index];
                      final label = AppConstants.quickAddLabels[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ActionChip(
                          label: Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          backgroundColor: isDark
                              ? AppColors.darkSurfaceLight
                              : const Color(0xFFF1F5F9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide.none,
                          ),
                          onPressed: () => _addQuickAmount(amountVal),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 3. Lưới Chọn Danh Mục + Nút Thêm Danh Mục Tùy Ý
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Danh mục',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(60, 24),
                    ),
                    onPressed: () {
                      AddCategoryDialog.show(context, initialType: _type);
                    },
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 15),
                    label: const Text(
                      'Tạo danh mục',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              SizedBox(
                height: 170,
                child: GridView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length + 1,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  itemBuilder: (ctx, index) {
                    if (index == categories.length) {
                      // Add Category Tile
                      return InkWell(
                        onTap: () {
                          AddCategoryDialog.show(context, initialType: _type);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkBackground
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.4),
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_rounded, size: 26, color: Colors.grey),
                              SizedBox(height: 4),
                              Text(
                                'Thêm mới',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final cat = categories[index];
                    final isSelected = cat.id == _selectedCategoryId;
                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedCategoryId = cat.id;
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cat.color.withValues(alpha: 0.18)
                              : (isDark
                                  ? AppColors.darkBackground
                                  : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? cat.color
                                : (isDark
                                    ? AppColors.darkSurfaceLight
                                    : const Color(0xFFE2E8F0)),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              cat.emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              cat.name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? cat.color
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // 4. Ngày & Ghi chú
              Row(
                children: [
                  // Chọn ngày
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkBackground
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkSurfaceLight
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                AppDateUtils.formatRelativeDate(_selectedDate),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Ghi chú ngắn
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkBackground
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkSurfaceLight
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: TextField(
                        controller: _noteController,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Ghi chú (vd: Ăn trưa bún chả)',
                          hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                          border: InputBorder.none,
                          icon: Icon(
                            Icons.edit_note_rounded,
                            size: 20,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // 5. Nút Lưu Giao Dịch tràn đáy
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: primaryActiveColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  widget.editTransaction != null
                      ? 'Cập nhật giao dịch'
                      : 'Lưu giao dịch',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _typeIsIncome => _type == 'INCOME';
}
