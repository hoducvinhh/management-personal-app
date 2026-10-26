import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_expense_tracker/core/constants/default_categories.dart';
import 'package:personal_expense_tracker/core/database/app_database.dart';
import 'package:personal_expense_tracker/data/models/transaction_model.dart';
import 'package:personal_expense_tracker/data/repositories/budget_repository.dart';
import 'package:personal_expense_tracker/data/repositories/category_repository.dart';
import 'package:personal_expense_tracker/data/repositories/transaction_repository.dart';
import 'package:personal_expense_tracker/presentation/providers/budget_provider.dart';
import 'package:personal_expense_tracker/presentation/providers/categories_provider.dart';
import 'package:personal_expense_tracker/presentation/providers/transactions_provider.dart';
import 'package:personal_expense_tracker/presentation/screens/budget/widgets/set_budget_dialog.dart';
import 'package:personal_expense_tracker/presentation/screens/main_screen.dart';
import 'package:personal_expense_tracker/presentation/screens/transaction_form/quick_transaction_sheet.dart';
import 'package:personal_expense_tracker/presentation/widgets/category/add_category_dialog.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MockAppDbWrapper implements AppDatabase {
  final Database _db;
  _MockAppDbWrapper(this._db);

  @override
  Future<Database> get database async => _db;

  @override
  Future<void> close() async => await _db.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late CategoryRepository catRepo;
  late TransactionRepository txRepo;
  late BudgetRepository budgetRepo;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon_code TEXT NOT NULL,
        color_hex TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category_id TEXT,
        date TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        category_id TEXT,
        month_key TEXT NOT NULL,
        limit_amount REAL NOT NULL
      )
    ''');

    // Seed default categories
    final batch = db.batch();
    for (final c in DefaultCategories.all) {
      batch.insert('categories', {
        'id': c.id,
        'name': c.name,
        'type': c.type,
        'icon_code': c.iconCode,
        'color_hex': c.colorHex,
        'is_default': c.isDefault ? 1 : 0,
      });
    }
    await batch.commit();

    final dbWrapper = _MockAppDbWrapper(db);
    catRepo = CategoryRepository(dbWrapper);
    txRepo = TransactionRepository(dbWrapper);
    budgetRepo = BudgetRepository(dbWrapper);
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp(Widget child) {
    return ProviderScope(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(catRepo),
        transactionRepositoryProvider.overrideWithValue(txRepo),
        budgetRepositoryProvider.overrideWithValue(budgetRepo),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('A. TÍNH NĂNG GHI CHÉP GIAO DỊCH TỰ DO (QuickTransactionSheet)', () {
    testWidgets('Ghi chép chi tiêu tự do: Nhập số tiền + ghi mục đích làm gì, KHÔNG cần gán danh mục', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => QuickTransactionSheet.show(ctx),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Thêm giao dịch mới'), findsOneWidget);
      expect(find.text('Không phân loại'), findsOneWidget);

      // Type amount: 80000
      final amountFinder = find.byType(TextField).first;
      await tester.enterText(amountFinder, '80000');
      await tester.pumpAndSettle();

      // Tap quick add chip '+50k' -> should become 130.000
      final chip50k = find.text('+50k');
      expect(chip50k, findsOneWidget);
      await tester.tap(chip50k);
      await tester.pumpAndSettle();

      // Type note: "Cà phê gặp gỡ đối tác"
      final noteFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText?.contains('Chi tiêu làm gì') == true,
      );
      expect(noteFinder, findsOneWidget);
      await tester.enterText(noteFinder, 'Cà phê gặp gỡ đối tác');
      await tester.pumpAndSettle();

      // Save transaction WITHOUT picking any category
      final saveBtn = find.text('Lưu giao dịch');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify in DB: transaction saved with categoryId == null and exact amount
      final allTx = await txRepo.getTransactions();
      expect(allTx.length, 1);
      final saved = allTx.first;
      expect(saved.amount, 130000.0);
      expect(saved.note, 'Cà phê gặp gỡ đối tác');
      expect(saved.categoryId, isNull);
      expect(saved.hasCategory, isFalse);
    });

    testWidgets('Gán danh mục tùy ý và hủy gán (toggle off) danh mục thành công', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => QuickTransactionSheet.show(ctx),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Enter amount
      await tester.enterText(find.byType(TextField).first, '45000');
      await tester.pumpAndSettle();

      // Find 'Ăn uống' category tile and tap to select
      final foodTile = find.text('Ăn uống');
      expect(foodTile, findsOneWidget);
      await tester.tap(foodTile);
      await tester.pumpAndSettle();

      // Button "Bỏ gán danh mục" should appear
      final clearBtn = find.text('Bỏ gán danh mục');
      expect(clearBtn, findsOneWidget);

      // Tap "Bỏ gán danh mục" to toggle off
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      // Enter note
      final noteFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText?.contains('Chi tiêu làm gì') == true,
      );
      await tester.enterText(noteFinder, 'Bánh giò nóng');
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.text('Lưu giao dịch'));
      await tester.pumpAndSettle();

      final allTx = await txRepo.getTransactions();
      expect(allTx.length, 1);
      expect(allTx.first.categoryId, isNull);
      expect(allTx.first.note, 'Bánh giò nóng');
    });

    testWidgets('Chuyển đổi Khoản thu: đổi giao diện và nạp danh mục nguồn thu', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => QuickTransactionSheet.show(ctx),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Tap 'Khoản thu'
      final incomeSegment = find.text('Khoản thu');
      await tester.tap(incomeSegment);
      await tester.pumpAndSettle();

      // Check income categories (Tiền lương)
      expect(find.text('Tiền lương'), findsOneWidget);

      // Enter amount
      await tester.enterText(find.byType(TextField).first, '12000000');
      await tester.pumpAndSettle();

      // Select 'Tiền lương'
      await tester.tap(find.text('Tiền lương'));
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.text('Lưu giao dịch'));
      await tester.pumpAndSettle();

      final allTx = await txRepo.getTransactions();
      expect(allTx.length, 1);
      expect(allTx.first.type, 'INCOME');
      expect(allTx.first.amount, 12000000.0);
      expect(allTx.first.categoryId, 'cat_inc_salary');
    });
  });

  group('B. TÍNH NĂNG ĐIỀU HƯỚNG 4 TAB CHÍNH (MainScreen Navigation)', () {
    testWidgets('Chuyển đổi mượt mà giữa các tab Tổng quan, Lịch sử, Ngân sách, Thống kê', (tester) async {
      await tester.pumpWidget(buildTestApp(const MainScreen()));
      await tester.pumpAndSettle();

      // Initial tab: Tổng quan
      expect(find.text('Tổng quan'), findsOneWidget);
      expect(find.text('Quản lý chi tiêu'), findsOneWidget);

      // Tap 'Lịch sử' tab
      await tester.tap(find.text('Lịch sử'));
      await tester.pumpAndSettle();
      expect(find.text('Lịch sử giao dịch'), findsOneWidget);
      expect(find.text('Tìm kiếm theo ghi chú, danh mục, số tiền...'), findsOneWidget);

      // Tap 'Ngân sách' tab
      await tester.tap(find.text('Ngân sách'));
      await tester.pumpAndSettle();
      expect(find.text('Quản lý ngân sách'), findsOneWidget);

      // Tap 'Thống kê' tab
      await tester.tap(find.text('Thống kê'));
      await tester.pumpAndSettle();
      expect(find.text('Thống kê tài chính'), findsOneWidget);

      // Tap center FAB to open QuickTransactionSheet
      final addIcon = find.byIcon(Icons.add_rounded);
      expect(addIcon, findsOneWidget);
      await tester.tap(addIcon);
      await tester.pumpAndSettle();

      expect(find.text('Thêm giao dịch mới'), findsOneWidget);
    });
  });

  group('C. TÍNH NĂNG TẠO DANH MỤC & ĐẶT NGÂN SÁCH (Dialogs)', () {
    testWidgets('Tạo danh mục tùy biến mới bằng AddCategoryDialog', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => AddCategoryDialog.show(ctx, initialType: 'EXPENSE'),
                child: const Text('Open Add Cat'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Add Cat'));
      await tester.pumpAndSettle();

      expect(find.text('Tạo danh mục mới'), findsOneWidget);

      // Enter category name
      final nameInput = find.byType(TextField);
      await tester.enterText(nameInput, 'Nuôi thú cưng');
      await tester.pumpAndSettle();

      // Tap Save
      final saveBtn = find.text('Lưu danh mục');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify category in DB
      final categories = await catRepo.getCategories(type: 'EXPENSE');
      expect(categories.any((c) => c.name == 'Nuôi thú cưng'), isTrue);
    });

    testWidgets('Thiết lập hạn mức ngân sách tổng tháng qua SetBudgetDialog', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => SetBudgetDialog.show(
                  ctx,
                  monthKey: '2026-10',
                ),
                child: const Text('Open Budget Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Budget Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Đặt hạn mức ngân sách'), findsOneWidget);

      // Enter limit amount: 15.000.000 ₫
      final amountInput = find.byType(TextField);
      await tester.enterText(amountInput, '15000000');
      await tester.pumpAndSettle();

      // Tap Save
      final saveBtn = find.text('Lưu hạn mức');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify budget in DB
      final budget = await budgetRepo.getOverallBudget('2026-10');
      expect(budget, isNotNull);
      expect(budget!.limitAmount, 15000000.0);
      expect(budget.isOverall, isTrue);
    });
  });

  group('D. TÍNH NĂNG TÌM KIẾM & BỘ LỌC NÂNG CAO (Search & Filters)', () {
    test('Tìm kiếm không phân biệt hoa thường và hỗ trợ tìm theo số tiền', () async {
      final now = DateTime.now();

      await txRepo.insertTransaction(TransactionModel(
        id: 'tx_pet',
        amount: 250000,
        type: 'EXPENSE',
        categoryId: null,
        date: now,
        note: 'Mua thức ăn cho mèo Royal Canin',
        createdAt: now,
      ));

      await txRepo.insertTransaction(TransactionModel(
        id: 'tx_gym',
        amount: 500000,
        type: 'EXPENSE',
        categoryId: null,
        date: now,
        note: 'Thẻ tập Gym California',
        createdAt: now,
      ));

      // 1. Search by keyword "mèo"
      final res1 = await txRepo.getTransactions(searchQuery: 'mèo');
      expect(res1.length, 1);
      expect(res1.first.id, 'tx_pet');

      // 2. Search by amount "500000"
      final res2 = await txRepo.getTransactions(searchQuery: '500000');
      expect(res2.length, 1);
      expect(res2.first.id, 'tx_gym');

      // 3. Filter by UNCATEGORIZED
      final res3 = await txRepo.getTransactions(categoryId: 'UNCATEGORIZED');
      expect(res3.length, 2);
    });
  });
}
