import 'package:flutter_test/flutter_test.dart';
import 'package:personal_expense_tracker/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PersonalExpenseTrackerApp());
  });
}
