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

    HapticFeedback.lightImpact();
    final actions = ref.read(transactionActionsProvider);
    final rawNote = _noteController.text.trim();
    // Use user-specified note ("làm gì"). If empty and no category selected, fallback to friendly text
    final noteToSave = rawNote.isNotEmpty
        ? rawNote
        : (_selectedCategoryId == null
            ? (_type == 'INCOME' ? 'Khoản thu' : 'Khoản chi')
            : null);

    if (widget.editTransaction != null) {
      final updated = widget.editTransaction!.copyWith(
        amount: _amount,
        type: _type,
        categoryId: _selectedCategoryId,
        clearCategory: _selectedCategoryId == null,
        date: _selectedDate,
        note: noteToSave,
      );
      await actions.updateTransaction(updated);
    } else {
      final newTx = TransactionModel(
        id: _uuid.v4(),
        amount: _amount,
        type: _type,
        categoryId: _selectedCategoryId,
        date: _selectedDate,
        note: noteToSave,
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

              // 3. Nội dung chi tiêu ("Làm gì") - Không bắt buộc phân loại, ghi rõ mục đích là đủ
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkSurfaceLight
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      color: primaryActiveColor,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _noteController,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: isIncome
                              ? 'Nguồn thu từ đâu? (vd: Tiền lương, Thưởng...)'
                              : 'Chi tiêu làm gì? (vd: Cà phê sáng, Đổ xăng...)',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 4. Chọn ngày giao dịch
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Ngày: ${AppDateUtils.formatRelativeDate(_selectedDate)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down_rounded,
                              size: 18, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedCategoryId != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedCategoryId = null;
                        });
                      },
                      icon: const Icon(Icons.close_rounded,
                          size: 14, color: Colors.grey),
                      label: const Text(
                        'Bỏ gán danh mục',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // 5. Gán Danh Mục (Tùy chọn - khi nào muốn gán thì gán)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Gán danh mục',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(Tùy chọn)',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
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
                  // +1 for 'Không phân loại', +1 for 'Tạo mới'
                  itemCount: categories.length + 2,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  itemBuilder: (ctx, index) {
                    // Tile 0: "Không phân loại"
                    if (index == 0) {
                      final isUncategorized = _selectedCategoryId == null;
                      return InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedCategoryId = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isUncategorized
                                ? const Color(0xFF64748B).withValues(alpha: 0.18)
                                : (isDark
                                    ? AppColors.darkBackground
                                    : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isUncategorized
                                  ? const Color(0xFF64748B)
                                  : (isDark
                                      ? AppColors.darkSurfaceLight
                                      : const Color(0xFFE2E8F0)),
                              width: isUncategorized ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('📝', style: TextStyle(fontSize: 24)),
                              const SizedBox(height: 4),
                              Text(
                                'Không phân loại',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isUncategorized
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isUncategorized
                                      ? (isDark ? Colors.white : const Color(0xFF334155))
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Last Tile: "Thêm mới"
                    if (index == categories.length + 1) {
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

                    // Existing categories (1 to categories.length)
                    final cat = categories[index - 1];
                    final isSelected = cat.id == _selectedCategoryId;
                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          // Tapping selected category again will deselect it (toggle off)
                          if (_selectedCategoryId == cat.id) {
                            _selectedCategoryId = null;
                          } else {
                            _selectedCategoryId = cat.id;
                          }
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
              const SizedBox(height: 22),

              // 6. Nút Lưu Giao Dịch tràn đáy
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
