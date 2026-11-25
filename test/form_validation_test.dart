import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smart_spend/controllers/auth_controller.dart';
import 'package:smart_spend/core/utils/formatters.dart';
import 'package:smart_spend/models/group_models.dart';
import 'package:smart_spend/views/auth/login_screen.dart';
import 'package:smart_spend/views/group_debt/add_group_expense_screen.dart';

void main() {
  test('Đăng ký kiểm tra trường trống, dữ liệu sai và giới hạn độ dài', () {
    final auth = AuthController();
    expect(auth.validateFullName('  '), isNotNull);
    expect(auth.validateFullName('A'), isNotNull);
    expect(auth.validateFullName(' An '), isNull);
    expect(auth.validateEmail(''), isNotNull);
    expect(auth.validateEmail('an.example.com'), isNotNull);
    expect(auth.validateEmail(' an@example.com '), isNull);
    expect(auth.validatePassword(''), isNotNull);
    expect(auth.validatePassword('1234567'), isNotNull);
    expect(auth.validatePassword('12345678'), isNull);
    expect(auth.validateConfirmPassword('', '12345678'), isNotNull);
    expect(auth.validateConfirmPassword('12345679', '12345678'), isNotNull);
    expect(auth.validateConfirmPassword('12345678', '12345678'), isNull);
  });

  testWidgets('Đăng nhập hiển thị lỗi khi nhập trống hoặc sai định dạng', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    final login = find.text('Đăng nhập');
    await tester.tap(login);
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập email'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'an.example.com');
    await tester.enterText(fields.at(1), '1234567');
    await tester.tap(login);
    await tester.pumpAndSettle();
    expect(find.textContaining('Email không hợp lệ'), findsOneWidget);
    expect(find.text('Tối thiểu 8 ký tự'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  test('Ô số tiền xử lý trống, chữ, 0, 1 và giới hạn 13 chữ số', () {
    final formatter = ThousandsSeparatorFormatter();
    TextEditingValue input(
      String text, {
      TextEditingValue previous = TextEditingValue.empty,
    }) => formatter.formatEditUpdate(previous, TextEditingValue(text: text));

    expect(parseAmount(input('').text), 0);
    expect(input('abc').text, isEmpty);
    expect(parseAmount(input('0').text), 0);
    expect(parseAmount(input('1').text), 1);
    final limit = input('9999999999999');
    expect(limit.text, '9.999.999.999.999');
    expect(parseAmount(limit.text), 9999999999999);
    expect(input('99999999999999', previous: limit), limit);
  });

  const group = GroupDetail(
    id: 'test-group',
    name: 'Chuyến đi',
    members: [
      GroupMemberModel(id: 'a', name: 'An', isMe: true),
      GroupMemberModel(id: 'b', name: 'Bình', isMe: false),
    ],
    expenses: [],
    balances: {},
    suggestions: [],
  );

  for (final percent in [49, 51]) {
    testWidgets('Form chia tiền từ chối tổng ${50 + percent}%', (tester) async {
      await tester.binding.setSurfaceSize(const Size(480, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: AddGroupExpenseScreen(group: group)),
      );
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '101');
      await tester.enterText(fields.at(1), 'Ăn trưa');
      await tester.tap(find.text('Theo %'));
      await tester.pumpAndSettle();
      await tester.enterText(fields.at(2), '50');
      await tester.enterText(fields.at(3), '$percent');
      await tester.tap(find.text('Lưu chi phí'));
      await tester.pumpAndSettle();
      expect(
        find.text('Tổng phần trăm là ${50 + percent}%, cần đúng 100%'),
        findsOneWidget,
      );
    });
  }
}
