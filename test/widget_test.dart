import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_spend/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Hiển thị màn hình Splash và chuyển sang Đăng nhập', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartSpendApp());

    expect(find.text('SmartSpend'), findsOneWidget);
    expect(find.textContaining('Quản lý chi tiêu thông minh'), findsOneWidget);
    expect(find.text('Bắt đầu'), findsOneWidget);

    await tester.tap(find.text('Bắt đầu'));
    await tester.pumpAndSettle();

    expect(find.text('Chào mừng trở lại'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsWidgets);
  });
}
