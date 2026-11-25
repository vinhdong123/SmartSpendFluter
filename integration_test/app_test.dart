import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:smart_spend/app.dart';
import 'package:smart_spend/controllers/budget_controller.dart';
import 'package:smart_spend/controllers/group_debt_controller.dart';
import 'package:smart_spend/controllers/settings_controller.dart';
import 'package:smart_spend/controllers/transaction_controller.dart';
import 'package:smart_spend/controllers/wallet_goal_controller.dart';
import 'package:smart_spend/core/theme/app_theme.dart';
import 'package:smart_spend/core/utils/formatters.dart';
import 'package:smart_spend/models/user_model.dart';
import 'package:smart_spend/services/extra_queries.dart';
import 'package:smart_spend/services/firebase_auth_service.dart';
import 'package:smart_spend/services/sqlite_database_service.dart';
import 'package:smart_spend/views/auth/login_screen.dart';
import 'package:smart_spend/views/auth/register_screen.dart';
import 'package:smart_spend/views/goals/savings_goals_screen.dart';
import 'package:smart_spend/views/group_debt/group_detail_screen.dart';
import 'package:smart_spend/views/group_debt/pay_debt_screen.dart';
import 'package:smart_spend/views/history/history_screen.dart';
import 'package:smart_spend/views/main/main_navigation_screen.dart';
import 'package:smart_spend/views/report/report_screen.dart';
import 'package:smart_spend/views/settings/bill_reminders_screen.dart';
import 'package:smart_spend/views/splash/splash_screen.dart';
import 'package:smart_spend/views/transaction/add_transaction_screen.dart';
import 'package:smart_spend/views/transaction/transaction_detail_screen.dart';
import 'package:smart_spend/views/widgets/ui_kit.dart';

const cash = 'Tiền mặt';
const food = 'Ăn uống';
const password = '12345678';
const submitTransaction = 'Lưu giao dịch';
final transactions = TransactionController();
final groups = GroupDebtController();
final sqlite = SQLiteDatabaseService.instance;

class TestFileDirectories extends PathProviderPlatform {
  TestFileDirectories(this.path);

  final String path;

  @override
  Future<String> getTemporaryPath() async => path;

  @override
  Future<String> getApplicationDocumentsPath() async => path;
}

Finder get fields => find.byType(TextField);

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, String label) =>
    tap(tester, find.text(label));

Future<void> dismissMessage(WidgetTester tester) async {
  tester
      .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
      .removeCurrentSnackBar();
  await tester.pumpAndSettle();
}

String messages(WidgetTester tester) => tester
    .widgetList<SnackBar>(find.byType(SnackBar))
    .map((bar) => (bar.content as Text).data)
    .join('\n');

Future<void> enter(WidgetTester tester, int index, String value) async {
  final field = fields.at(index);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

Future<void> showScreen(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: AppTheme.lightTheme,
      home: const Scaffold(),
      initialRoute: '/screen',
      routes: {'/screen': (_) => screen},
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> confirm(WidgetTester tester, String label) => tap(
  tester,
  find.descendant(
    of: find.byType(Dialog),
    matching: find.widgetWithText(ElevatedButton, label),
  ),
);

Future<void> fillRegister(WidgetTester tester, String email) async {
  await enter(tester, 0, 'An');
  await enter(tester, 1, email);
  await enter(tester, 2, password);
  await enter(tester, 3, password);
}

Future<void> submitRegister(WidgetTester tester) =>
    tap(tester, find.text('Tạo tài khoản').last);

Future<void> addExpense(WidgetTester tester, int amount, {String? note}) async {
  await tap(tester, find.byType(FloatingActionButton));
  await enter(tester, 0, '$amount');
  if (note != null) await enter(tester, 1, note);
  await press(tester, submitTransaction);
}

Future<void> openHistory(WidgetTester tester) => tap(
  tester,
  find.descendant(
    of: find.byType(BottomNavigationBar),
    matching: find.text('Lịch sử'),
  ),
);

Future<void> openGroupExpense(
  WidgetTester tester,
  String id,
  String amount,
) async {
  await showScreen(tester, GroupDetailScreen(groupId: id));
  await press(tester, 'Thêm chi phí nhóm');
  await enter(tester, 0, amount);
  await enter(tester, 1, 'Ăn trưa');
}

Future<void> seedTransaction(
  String title,
  double amount,
  DateTime date, {
  String wallet = cash,
  bool expense = true,
}) async {
  await transactions.addTransaction(
    title: title,
    amount: amount,
    isExpense: expense,
    category: expense ? food : 'Lương',
    wallet: wallet,
    date: date,
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final originalPaths = PathProviderPlatform.instance;
  late Directory temp;
  late UserModel user;
  var userNumber = 0;

  setUpAll(() async {
    expect(FirebaseAuthService.instance.isFirebaseAvailable, isFalse);
    final cache = await getTemporaryDirectory();
    temp = await cache.createTemp('smartspend_ui_');
    PathProviderPlatform.instance = TestFileDirectories(temp.path);
    await databaseFactory.setDatabasesPath(temp.path);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final uid = 'ui_test_${++userNumber}';
    user = UserModel(
      uid: uid,
      fullName: 'Người dùng kiểm thử',
      email: '$uid@example.com',
      createdAt: DateTime.now(),
    );
    sqlite.setCurrentUser(user);
    await sqlite.readyDatabase;
  });

  tearDownAll(() async {
    await (await sqlite.database).close();
    PathProviderPlatform.instance = originalPaths;
    await temp.delete(recursive: true);
  });

  testWidgets('AUTO-01 Mở app và chuyển sang Đăng nhập', (tester) async {
    await tester.pumpWidget(const SmartSpendApp());
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsOneWidget);
    await press(tester, 'Bắt đầu');
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('AUTO-02 Kiểm tra dữ liệu trống, sai và biên trên form đăng ký', (
    tester,
  ) async {
    await showScreen(tester, const RegisterScreen());
    await submitRegister(tester);
    expect(find.text('Vui lòng nhập họ và tên'), findsOneWidget);
    expect(find.text('Vui lòng nhập email'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
    expect(find.text('Vui lòng nhập lại mật khẩu'), findsOneWidget);
    await enter(tester, 0, 'A');
    await enter(tester, 1, 'an.example.com');
    await enter(tester, 2, '1234567');
    await enter(tester, 3, '1234569');
    await submitRegister(tester);
    expect(find.text('Họ và tên quá ngắn'), findsOneWidget);
    expect(find.textContaining('Email không hợp lệ'), findsOneWidget);
    expect(find.text('Tối thiểu 8 ký tự'), findsWidgets);
    expect(find.text('Mật khẩu nhập lại không khớp'), findsOneWidget);
    await fillRegister(tester, 'boundary@example.com');
    await submitRegister(tester);
    expect(find.byType(MainNavigationScreen), findsOneWidget);
  });

  testWidgets(
    'AUTO-03 Form đăng nhập báo lỗi khi nhập trống hoặc sai định dạng',
    (tester) async {
      await showScreen(tester, const LoginScreen());
      await press(tester, 'Đăng nhập');
      expect(find.text('Vui lòng nhập email'), findsOneWidget);
      expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
      await enter(tester, 0, 'an.example.com');
      await enter(tester, 1, '1234567');
      await press(tester, 'Đăng nhập');
      expect(find.textContaining('Email không hợp lệ'), findsOneWidget);
      expect(find.text('Tối thiểu 8 ký tự'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
    },
  );

  testWidgets('AUTO-04 Ô số tiền lọc chữ và giữ giới hạn 13 chữ số', (
    tester,
  ) async {
    await showScreen(tester, const AddTransactionScreen());
    String amount() => tester.widget<TextField>(fields.first).controller!.text;
    for (final (input, shown) in [
      ('', ''),
      ('abc', ''),
      ('0', '0'),
      ('1', '1'),
      ('9999999999999', '9.999.999.999.999'),
      ('99999999999999', '9.999.999.999.999'),
    ]) {
      await enter(tester, 0, input);
      expect(amount(), shown);
    }
  });

  for (final (id, percent) in [('AUTO-05', 49), ('AUTO-06', 51)]) {
    testWidgets('$id Form chia tiền từ chối tổng ${50 + percent}%', (
      tester,
    ) async {
      final group = await groups.createGroup('Chuyến đi', ['Bình']);
      await openGroupExpense(tester, group, '101');
      await press(tester, 'Theo %');
      await enter(tester, 2, '50');
      await enter(tester, 3, '$percent');
      await press(tester, 'Lưu chi phí');
      expect(
        find.text('Tổng phần trăm là ${50 + percent}%, cần đúng 100%'),
        findsOneWidget,
      );
      expect((await groups.fetchGroup(group))!.expenses, isEmpty);
    });
  }

  testWidgets(
    'AUTO-07 Đăng ký, từ chối email trùng, đăng xuất và đăng nhập lại',
    (tester) async {
      const email = 'account@example.com';
      await showScreen(tester, const RegisterScreen());
      await fillRegister(tester, email);
      await submitRegister(tester);
      expect(
        await sqlite.getUserByEmailAndPassword(email, password),
        isNotNull,
      );
      await tap(tester, find.byIcon(Icons.tune_rounded));
      await press(tester, 'Đăng xuất');
      await confirm(tester, 'Đăng xuất');
      expect(find.byType(LoginScreen), findsOneWidget);
      await press(tester, 'Chưa có tài khoản? Đăng ký');
      await fillRegister(tester, email);
      await submitRegister(tester);
      expect(
        find.text('Email này đã được đăng ký trên thiết bị.'),
        findsOneWidget,
      );
      await dismissMessage(tester);
      await tap(tester, find.byIcon(Icons.chevron_left_rounded));
      await enter(tester, 0, email);
      await enter(tester, 1, '87654321');
      await press(tester, 'Đăng nhập');
      expect(find.text('Email hoặc mật khẩu không chính xác.'), findsOneWidget);
      await showScreen(tester, const LoginScreen());
      await enter(tester, 0, email);
      await enter(tester, 1, password);
      expect(tester.widget<TextField>(fields.first).controller!.text, email);
      expect(
        tester.widget<TextField>(fields.last).controller!.text == password,
        isTrue,
      );
      await press(tester, 'Đăng nhập');
      final home = find.byType(MainNavigationScreen);
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (home.evaluate().isEmpty &&
          messages(tester).isEmpty &&
          DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(home, findsOneWidget, reason: messages(tester));
    },
  );

  testWidgets('AUTO-08 Thêm, sửa, xóa giao dịch và xem số dư', (tester) async {
    final wallets = WalletController();
    final wallet = (await wallets.fetchWallets()).singleWhere(
      (w) => w.name == cash,
    );
    await wallets.setInitialBalance(wallet.id, 100);
    await showScreen(tester, MainNavigationScreen(user: user));
    await addExpense(tester, 1, note: 'Ăn sáng');
    expect(find.text('99đ'), findsOneWidget);
    await openHistory(tester);
    await press(tester, 'Ăn sáng');
    await press(tester, 'Sửa');
    await enter(tester, 0, '2');
    await press(tester, 'Lưu thay đổi');
    expect(find.text('-2đ'), findsOneWidget);
    await press(tester, 'Trang chủ');
    expect(find.text('98đ'), findsOneWidget);
    await openHistory(tester);
    await press(tester, 'Ăn sáng');
    await press(tester, 'Xóa');
    await confirm(tester, 'Xóa');
    expect(find.text('Chưa có giao dịch nào'), findsOneWidget);
    await press(tester, 'Trang chủ');
    expect(find.text('100đ'), findsOneWidget);
  });

  testWidgets(
    'AUTO-09 Cảnh báo ngân sách tại các mốc 79, 80, 81, 100 và 101 đồng',
    (tester) async {
      final budget = BudgetController();
      await budget.saveTotalLimit(100);
      await budget.saveCategoryLimit(food, 100, alertPct: 80);
      await showScreen(tester, MainNavigationScreen(user: user));
      for (final (delta, total) in [
        (79, 79),
        (1, 80),
        (1, 81),
        (19, 100),
        (1, 101),
      ]) {
        await addExpense(tester, delta);
        await dismissMessage(tester);
        await tap(tester, find.byIcon(Icons.notifications_none_rounded));
        if (total < 80) {
          expect(find.textContaining('Ăn uống đã'), findsNothing);
        } else {
          expect(
            find.text(
              total > 100
                  ? 'Ăn uống đã vượt hạn mức'
                  : 'Ăn uống đã dùng $total%',
            ),
            findsOneWidget,
          );
        }
        await tap(tester, find.byIcon(Icons.chevron_left_rounded));
      }
    },
  );

  testWidgets('AUTO-10 Chia đều 100 đồng, chặn tổng sai và tất toán nhóm', (
    tester,
  ) async {
    final id = await groups.createGroup('Chuyến đi', ['An', 'Bình']);
    await openGroupExpense(tester, id, '100');
    expect(find.text('34đ'), findsOneWidget);
    expect(find.text('33đ'), findsNWidgets(2));
    await press(tester, 'Theo số tiền');
    for (final amount in [99, 101]) {
      await enter(tester, 2, '$amount');
      await press(tester, 'Lưu chi phí');
      expect(
        find.text('Tổng chia ${formatVND(amount)} chưa bằng 100đ'),
        findsOneWidget,
      );
      await dismissMessage(tester);
    }
    await press(tester, 'Chia đều');
    await press(tester, 'Lưu chi phí');
    await press(tester, 'Xem chi tiết & cân đối công nợ');
    await press(tester, 'Ghi nhận thanh toán');
    await tap(tester, find.textContaining('→').hitTestable().last);
    await confirm(tester, 'Ghi nhận');
    await dismissMessage(tester);
    await press(tester, 'Ghi nhận thanh toán');
    await confirm(tester, 'Ghi nhận');
    expect(find.text('Không còn khoản nào cần thanh toán.'), findsOneWidget);
  });

  testWidgets(
    'AUTO-11 Trả nợ từ chối 0 và 101 đồng, tất toán khi trả 100 đồng',
    (tester) async {
      await groups.addDebt(
        counterparty: 'An',
        isBorrowed: true,
        amount: 100,
        walletName: cash,
      );
      await showScreen(
        tester,
        PayDebtScreen(debt: (await groups.fetchDebts()).single),
      );
      for (final (input, error) in [
        ('0', 'Nhập số tiền lớn hơn 0'),
        ('101', 'Tối đa 100đ'),
      ]) {
        await enter(tester, 0, input);
        await press(tester, 'Ghi nhận thanh toán');
        expect(find.text(error), findsOneWidget);
      }
      await enter(tester, 0, '100');
      await press(tester, 'Ghi nhận thanh toán');
      expect(find.text('Đã tất toán'), findsOneWidget);
      expect(find.text('Lần 1'), findsOneWidget);
      expect((await WalletController().fetchWallets()).first.balance, 0);
    },
  );

  testWidgets('AUTO-12 Lọc lịch sử và báo cáo rồi xuất Excel, PDF', (
    tester,
  ) async {
    const share = MethodChannel('dev.fluttercommunity.plus/share');
    final exported = <File>[];
    final shareMethods = <String>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(share, (
      call,
    ) async {
      shareMethods.add(call.method);
      final paths = (call.arguments as Map)['paths'] as List;
      exported.add(File(paths.single as String));
      return 'dev.fluttercommunity.plus/share/success';
    });
    addTearDown(() async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(share, null);
      for (final file in exported) {
        if (await file.exists()) await file.delete();
      }
    });

    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    final last = DateTime(now.year, now.month + 1, 0, 23, 59);
    await seedTransaction('Cà phê đầu kỳ', 10, first);
    await seedTransaction('Cà phê cuối kỳ', 20, last);
    await seedTransaction(
      'Cà phê ngoài kỳ',
      900,
      DateTime(now.year, now.month, 0),
    );
    await seedTransaction('Cà phê ví khác', 900, first, wallet: 'Ngân hàng');
    await seedTransaction('Lương', 100, first, expense: false);

    await showScreen(tester, const HistoryScreen());
    await tap(tester, find.byIcon(Icons.search_rounded));
    await enter(tester, 0, 'cà phê');
    await press(tester, cash);
    await press(tester, 'Áp dụng bộ lọc');
    await press(tester, 'Chi tiêu');
    expect(find.text('Cà phê đầu kỳ'), findsOneWidget);
    expect(find.text('Cà phê cuối kỳ'), findsOneWidget);
    expect(find.text('Cà phê ngoài kỳ'), findsNothing);
    expect(find.text('Cà phê ví khác'), findsNothing);
    expect(find.text('Lương'), findsNothing);

    await showScreen(tester, const ReportScreen());
    await tap(tester, find.byIcon(Icons.filter_alt_outlined));
    await press(tester, cash);
    await press(tester, 'Chi tiêu');
    await press(tester, 'Áp dụng');
    expect(find.text('30đ'), findsWidgets);
    await tap(
      tester,
      find.widgetWithIcon(SquareIconButton, Icons.file_download_outlined),
    );
    await press(tester, 'Excel (.xlsx)');
    await press(tester, 'Chia sẻ qua ứng dụng khác');
    expect(exported, hasLength(1), reason: messages(tester));
    final workbook = Excel.decodeBytes(await exported.single.readAsBytes());
    expect(workbook['Tổng quan'].rows[3][1]?.value, IntCellValue(30));
    expect(
      workbook['Giao dịch'].rows.skip(1).map((row) => row[4]?.value),
      unorderedEquals([IntCellValue(10), IntCellValue(20)]),
    );
    await press(tester, 'PDF');
    await press(tester, 'Chia sẻ qua ứng dụng khác');
    expect(exported, hasLength(2));
    expect(shareMethods, ['shareFiles', 'shareFiles']);
    expect(
      String.fromCharCodes((await exported.last.readAsBytes()).take(5)),
      '%PDF-',
    );
  });

  testWidgets('AUTO-13 Tạo mục tiêu, nạp đủ 100 đồng và rút 1 đồng', (
    tester,
  ) async {
    await showScreen(tester, const SavingsGoalsScreen());
    await press(tester, 'Tạo mục tiêu');
    await enter(tester, 0, 'Quỹ khẩn cấp');
    await enter(tester, 1, '100');
    await press(tester, 'Lưu mục tiêu');
    await press(tester, 'Quỹ khẩn cấp');
    await enter(tester, 0, '100');
    await press(tester, 'Nạp tiền');
    expect(find.text('100%'), findsOneWidget);
    await dismissMessage(tester);
    await press(tester, 'Quỹ khẩn cấp');
    await press(tester, 'Rút ra');
    await enter(tester, 0, '1');
    await press(tester, 'Rút tiền');
    expect(find.text('99%'), findsOneWidget);
  });

  testWidgets('AUTO-14 Thanh toán hóa đơn một lần và dời hạn hóa đơn lặp', (
    tester,
  ) async {
    final bills = BillController();
    await bills.save(
      title: 'Tiền điện',
      amount: 40,
      dueOn: DateTime(2024, 2, 1),
      repeatMonthly: false,
    );
    await bills.save(
      title: 'Tiền mạng',
      amount: 60,
      dueOn: DateTime(2024, 1, 31),
      repeatMonthly: true,
    );
    await showScreen(tester, const BillRemindersScreen());
    await press(tester, 'Tiền điện');
    await press(tester, 'Đánh dấu đã thanh toán');
    await press(tester, cash);
    expect(find.text('Tiền điện'), findsNothing);
    await press(tester, 'Tiền mạng');
    await press(tester, 'Đánh dấu đã thanh toán');
    await press(tester, cash);
    expect(find.textContaining('29/02/2024'), findsOneWidget);
    expect((await WalletController().fetchWallets()).first.balance, -100);
  });

  testWidgets(
    'AUTO-15 Mở app xử lý hai kỳ đến hạn, bỏ lịch tắt và giữ số giao dịch khi mở lại',
    (tester) async {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      for (final title in ['Lịch đang bật', 'Lịch đã tắt']) {
        await sqlite.saveRecurring(
          isExpense: true,
          category: food,
          walletName: cash,
          amount: 10,
          frequency: 'daily',
          startOn: yesterday,
          note: title,
        );
      }
      final paused = (await sqlite.getRecurring()).singleWhere(
        (item) => item.note == 'Lịch đã tắt',
      );
      await sqlite.setRecurringActive(paused.id, false);
      for (var open = 0; open < 2; open++) {
        await showScreen(tester, MainNavigationScreen(user: user));
        expect(find.text('Lịch đang bật'), findsWidgets);
        expect(find.text('Lịch đã tắt'), findsNothing);
        expect((await transactions.fetchTransactions()).map((tx) => tx.title), [
          'Lịch đang bật',
          'Lịch đang bật',
        ]);
      }
      await tap(tester, find.byIcon(Icons.tune_rounded));
      await press(tester, 'Giao dịch định kỳ');
      expect(find.text('Lịch đã tắt'), findsOneWidget);
      expect(
        tester
            .widgetList<Switch>(find.byType(Switch))
            .map((switchWidget) => switchWidget.value),
        unorderedEquals([true, false]),
      );
    },
  );

  testWidgets('AUTO-16 Hiển thị giao dịch định kỳ ngày 29/02 và 31/03', (
    tester,
  ) async {
    await sqlite.saveRecurring(
      isExpense: true,
      category: food,
      walletName: cash,
      amount: 10,
      frequency: 'monthly',
      startOn: DateTime(2024, 1, 31),
      note: 'Định kỳ ngày 31',
    );
    await showScreen(tester, MainNavigationScreen(user: user));
    final all = await transactions.fetchTransactions();
    for (final date in [DateTime(2024, 2, 29), DateTime(2024, 3, 31)]) {
      final transaction = all.singleWhere((tx) => isSameDay(tx.date, date));
      await showScreen(
        tester,
        TransactionDetailScreen(transaction: transaction),
      );
      expect(find.text('Định kỳ ngày 31'), findsWidgets);
      expect(find.textContaining(formatDate(date)), findsOneWidget);
    }
  });

  testWidgets('AUTO-17 Xem ảnh đã đính kèm và xóa ảnh cùng giao dịch', (
    tester,
  ) async {
    final source = File('${temp.path}/receipt.png');
    await source.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGP8//8/AwMDEwMDAwMDAwAkBgMB/DXemwAAAABJRU5ErkJggg==',
      ),
    );
    await showScreen(
      tester,
      AddTransactionScreen(initialReceiptPath: source.path),
    );
    expect(find.text('Đã đính kèm ảnh hóa đơn'), findsOneWidget);
    await enter(tester, 0, '10');
    await press(tester, submitTransaction);
    final transaction = (await transactions.fetchTransactions()).single;
    final copy = File((await transactions.receiptOf(transaction.id))!);
    addTearDown(() async {
      if (await copy.exists()) await copy.delete();
    });
    await showScreen(tester, TransactionDetailScreen(transaction: transaction));
    expect(find.byType(Image), findsOneWidget);
    await press(tester, 'Xóa');
    await confirm(tester, 'Xóa');
    expect(await copy.exists(), isFalse);
    expect(await source.exists(), isTrue);
    expect(await transactions.fetchTransactions(), isEmpty);
  });

  testWidgets('AUTO-18 Form giao dịch từ chối trống, 0 và lưu đúng 1 đồng', (
    tester,
  ) async {
    await showScreen(tester, MainNavigationScreen(user: user));
    await tap(tester, find.byType(FloatingActionButton));
    for (final input in ['', '0']) {
      await enter(tester, 0, input);
      await press(tester, submitTransaction);
      expect(find.text('Nhập số tiền lớn hơn 0'), findsOneWidget);
      expect(await transactions.fetchTransactions(), isEmpty);
    }
    await enter(tester, 0, '1');
    await press(tester, submitTransaction);
    expect(find.text('-1đ'), findsWidgets);
    expect((await transactions.fetchTransactions()).single.amount, 1);
  });

  testWidgets('AUTO-19 Chia 101 đồng theo tỷ lệ 50% + 50%', (tester) async {
    final id = await groups.createGroup('Chuyến đi', ['Bình']);
    await openGroupExpense(tester, id, '101');
    await press(tester, 'Theo %');
    await enter(tester, 2, '50');
    await enter(tester, 3, '50');
    await press(tester, 'Lưu chi phí');
    expect(find.text('Ăn trưa'), findsOneWidget);
    expect(find.text('Bạn sẽ nhận lại 50đ'), findsOneWidget);
    expect((await groups.fetchGroup(id))!.totalExpense, 101);
  });
}
