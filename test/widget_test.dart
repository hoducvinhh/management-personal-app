import 'package:flutter_test/flutter_test.dart';
import 'package:personal_expense_tracker/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PersonalExpenseTrackerApp());
    expect(find.text('Quản lý chi tiêu'), findsOneWidget);
  });
}
