import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smart_spend/controllers/budget_controller.dart';
import 'package:smart_spend/controllers/group_debt_controller.dart';
import 'package:smart_spend/controllers/report_controller.dart';
import 'package:smart_spend/controllers/settings_controller.dart';
import 'package:smart_spend/controllers/transaction_controller.dart';
import 'package:smart_spend/controllers/wallet_goal_controller.dart';
import 'package:smart_spend/models/recurring_model.dart';
import 'package:smart_spend/models/report_models.dart';
import 'package:smart_spend/models/tx_filter.dart';
import 'package:smart_spend/models/user_model.dart';
import 'package:smart_spend/repositories/auth_repository.dart';
import 'package:smart_spend/services/export_service.dart';
import 'package:smart_spend/services/extra_queries.dart';
import 'package:smart_spend/services/sqlite_database_service.dart';
import 'package:smart_spend/views/group_debt/add_group_expense_screen.dart';
import 'package:smart_spend/views/transaction/add_transaction_screen.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final sqlite = SQLiteDatabaseService.instance;
  final transactions = TransactionController();
  final wallets = WalletController();
  const cash = 'Tiền mặt';
  const food = 'Ăn uống';
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  const password = '12345678';
  final firstDay = DateTime(2024, 2, 1);
  late Directory temp;
  var fixtureNumber = 0;

  setUpAll(() async {
    sqfliteFfiInit();
    sqflite.databaseFactory = createDatabaseFactoryFfi(noIsolate: true);
    temp = await Directory.systemTemp.createTemp('smart_spend_test_');
    await sqflite.databaseFactory.setDatabasesPath(temp.path);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProvider,
      (call) async => switch (call.method) {
        'getApplicationDocumentsDirectory' ||
        'getTemporaryDirectory' => temp.path,
        _ => throw MissingPluginException(call.method),
      },
    );
  });

  tearDownAll(() async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(pathProvider, null);
    await (await sqlite.database).close();
    await temp.delete(recursive: true);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final uid = 'test_user_${++fixtureNumber}';
    sqlite.setCurrentUser(
      UserModel(
        uid: uid,
        fullName: 'Người dùng kiểm thử',
        email: '$uid@example.com',
        createdAt: firstDay,
      ),
    );
    await sqlite.readyDatabase;
  });

  Future<int> cashBalance() async =>
      (await wallets.fetchWallets()).singleWhere((w) => w.name == cash).balance;

  Future<String> addExpense(
    int amount,
    DateTime date, {
    String wallet = cash,
    String? note,
    String? receiptPath,
  }) => transactions.addTransaction(
    title: '',
    amount: amount.toDouble(),
    isExpense: true,
    category: food,
    wallet: wallet,
    date: date,
    note: note,
    receiptPath: receiptPath,
  );

  test('Đăng ký cục bộ, từ chối email trùng và đăng nhập lại', () async {
    final auth = AuthRepository.instance;
    const email = 'local@example.com';
    final user = await auth.register(
      fullName: ' An ',
      email: ' LOCAL@example.com ',
      password: password,
    );
    expect(user.fullName, 'An');
    expect(user.email, email);
    expect((await auth.getSavedSession())?.uid, user.uid);
    await expectLater(
      auth.register(fullName: 'Bình', email: email, password: password),
      throwsA(isA<AuthException>()),
    );

    await auth.logout();
    expect(await auth.getSavedSession(), isNull);
    await expectLater(
      auth.login(email: email, password: '87654321'),
      throwsA(isA<AuthException>()),
    );
    expect(await auth.getSavedSession(), isNull);
    expect((await auth.login(email: email, password: password)).uid, user.uid);
  });

  test('Thêm, sửa và xóa khoản chi 1 đồng cập nhật số dư ví', () async {
    await wallets.addWallet('Ví kiểm thử', 'cash', 100);
    expect(await wallets.nameExists(' ví KIỂM THỬ '), isTrue);
    Future<int> balance() async => (await wallets.fetchWallets())
        .singleWhere((w) => w.name == 'Ví kiểm thử')
        .balance;

    final id = await addExpense(1, firstDay, wallet: 'Ví kiểm thử');
    expect(await balance(), 99);
    expect((await transactions.fetchTransactions()).single.title, food);
    await transactions.updateTransaction(
      id: id,
      title: 'Ăn sáng',
      amount: 2,
      isExpense: true,
      category: food,
      wallet: 'Ví kiểm thử',
      date: firstDay,
    );
    expect(await balance(), 98);
    expect((await transactions.fetchTransactions()).single.title, 'Ăn sáng');
    await transactions.deleteTransaction(id);
    expect(await balance(), 100);
    expect(await transactions.fetchTransactions(), isEmpty);
  });

  test(
    'Ngân sách dưới ngưỡng, chạm ngưỡng, đúng hạn mức và vượt hạn mức',
    () async {
      final budget = BudgetController();
      final today = DateTime.now();
      await budget.saveTotalLimit(100);
      await budget.saveCategoryLimit(food, 100, alertPct: 80);
      for (final (amount, total, warning, over) in [
        (79, 79, false, false),
        (1, 80, true, false),
        (1, 81, true, false),
        (19, 100, true, false),
        (1, 101, true, true),
      ]) {
        await addExpense(amount, today);
        final overview = await budget.fetchOverview(1);
        final item = overview.items.single;
        expect(overview.totalSpent, total);
        expect(overview.remaining, 100 - total);
        expect(item.isWarning, warning, reason: 'Đã chi $total đồng');
        expect(item.isOver, over, reason: 'Đã chi $total đồng');
        final alert = await budget.alertAfterExpense(food, today);
        if (warning) {
          expect(alert, contains(over ? 'vượt ngân sách' : 'đã dùng $total%'));
        } else {
          expect(alert, isNull);
        }
      }
    },
  );

  test(
    'Chia đều có phần dư, từ chối tổng sai và ghi nhận thanh toán nhóm',
    () async {
      final groups = GroupDebtController();
      final id = await groups.createGroup('Chuyến đi', ['An', 'Bình']);
      final group = (await groups.fetchGroup(id))!;
      final payer = group.me!.id;
      final others = group.members
          .where((member) => !member.isMe)
          .map((member) => member.id)
          .toList();
      Future<void> split(List<String> members, {Map<String, int>? shares}) =>
          groups.addGroupExpense(
            groupId: id,
            description: 'Ăn trưa',
            amount: 100,
            paidBy: payer,
            participants: members,
            date: firstDay,
            shares: shares,
          );

      await expectLater(split([]), throwsArgumentError);
      await expectLater(
        split([payer], shares: {payer: 99}),
        throwsArgumentError,
      );
      await expectLater(
        split([payer], shares: {payer: 101}),
        throwsArgumentError,
      );
      expect((await groups.fetchGroup(id))!.expenses, isEmpty);
      await split([payer, ...others]);
      final balance = (await groups.fetchGroup(id))!;
      expect(balance.totalExpense, 100);
      expect(balance.balances, {payer: 66, for (final id in others) id: -33});
      for (final suggestion in balance.suggestions) {
        await groups.settle(id, suggestion);
      }
      expect((await groups.fetchGroup(id))!.suggestions, isEmpty);
      await split([], shares: {payer: 60, others.first: 40});
      expect((await groups.fetchGroup(id))!.balances[others.first], -40);
    },
  );

  test(
    'Trả nợ từ chối 0 và vượt 1 đồng, trả hết cập nhật lịch sử và số dư',
    () async {
      final debts = GroupDebtController();
      await debts.addDebt(
        counterparty: 'An',
        isBorrowed: true,
        amount: 100,
        walletName: cash,
      );
      final debt = (await debts.fetchDebts()).single;
      expect(await cashBalance(), 100);
      await expectLater(debts.payDebt(debt, 0, cash), throwsArgumentError);
      await expectLater(debts.payDebt(debt, 101, cash), throwsArgumentError);
      expect(await debts.fetchPayments(debt.id), isEmpty);
      expect(await cashBalance(), 100);

      await debts.payDebt(debt, 100, cash);
      expect((await debts.fetchDebts()).single.isSettled, isTrue);
      expect((await debts.fetchPayments(debt.id)).single.amount, 100);
      expect(await cashBalance(), 0);
    },
  );

  test(
    'Lịch sử và báo cáo gồm cả hai ngày biên và lọc theo ví, loại',
    () async {
      final lastDay = DateTime(2024, 2, 29, 23, 59);
      final firstId = await addExpense(10, firstDay, note: 'Cà phê');
      final lastId = await addExpense(20, lastDay, note: 'Cà phê tối');
      await addExpense(900, DateTime(2024, 1, 31));
      await addExpense(900, DateTime(2024, 3, 1));
      await addExpense(900, firstDay, wallet: 'Ngân hàng', note: 'Cà phê');
      await transactions.addTransaction(
        title: 'Lương',
        amount: 100,
        isExpense: false,
        category: 'Lương',
        wallet: cash,
        date: firstDay,
      );

      final all = await transactions.fetchTransactions();
      final history = transactions.filterTransactions(
        all,
        TxFilter(
          query: ' CÀ PHÊ ',
          from: firstDay,
          to: lastDay,
          wallet: cash,
          category: food,
          type: 1,
        ),
      );
      expect(history.map((t) => t.id), unorderedEquals([firstId, lastId]));
      expect(
        transactions.filterTransactions(
          all,
          const TxFilter(query: 'không tìm thấy'),
        ),
        isEmpty,
      );

      final report = await ReportController().load(
        ReportFilter(
          range: ReportRange.custom,
          customFrom: firstDay,
          customTo: lastDay,
          wallet: cash,
          type: 1,
        ),
      );
      expect(
        report.transactions.map((t) => t.id),
        unorderedEquals([firstId, lastId]),
      );
      expect(report.income, 100);
      expect(report.expense, 30);
      expect(report.categories.single.label, food);
      expect(report.categories.single.total, 30);

      Future<File> export({required bool pdf}) => ExportService.instance.build(
        pdf: pdf,
        periodLabel: 'Tháng 2',
        income: report.income,
        expense: report.expense,
        categories: report.categories,
        transactions: report.transactions,
        persist: false,
      );
      final workbook = Excel.decodeBytes(
        await (await export(pdf: false)).readAsBytes(),
      );
      expect(workbook['Tổng quan'].rows[3][1]?.value, IntCellValue(30));
      final details = workbook['Giao dịch'].rows.skip(1);
      expect(
        details.map((row) => row[4]?.value),
        unorderedEquals([IntCellValue(10), IntCellValue(20)]),
      );
      final pdf = await (await export(pdf: true)).readAsBytes();
      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    },
  );

  test('Góp đúng mục tiêu tiết kiệm và rút một phần', () async {
    final goals = GoalController();
    await goals.addGoal('Quỹ khẩn cấp', 100, null);
    final goal = (await goals.fetchGoals()).single;
    expect(goal.saved, 0);
    await goals.contribute(goal.id, cash, 100, false);
    expect((await goals.fetchGoals()).single.isDone, isTrue);
    await goals.contribute(goal.id, cash, 1, true);
    final updated = (await goals.fetchGoals()).single;
    expect(updated.saved, 99);
    expect(updated.isDone, isFalse);
  });

  test('Thanh toán hóa đơn một lần và dời lịch lặp qua cuối tháng', () async {
    final bills = BillController();
    await bills.save(
      title: 'Điện',
      amount: 40,
      dueOn: firstDay,
      repeatMonthly: false,
    );
    await bills.pay((await bills.fetch()).single, cash);
    expect(await bills.fetch(), isEmpty);
    expect(await cashBalance(), -40);

    await bills.save(
      title: 'Mạng',
      amount: 60,
      dueOn: DateTime(2024, 1, 31),
      repeatMonthly: true,
    );
    await bills.pay((await bills.fetch()).single, cash);
    expect((await bills.fetch()).single.dueOn, DateTime(2024, 2, 29));
    expect(await cashBalance(), -100);
    expect(
      (await transactions.fetchTransactions()).map((t) => t.amount),
      unorderedEquals([40, 60]),
    );
  });

  test('Định kỳ tạo các kỳ đến hạn một lần và bỏ qua lịch đã tắt', () async {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    await sqlite.saveRecurring(
      isExpense: true,
      category: food,
      walletName: cash,
      amount: 10,
      frequency: 'daily',
      startOn: yesterday,
    );
    expect(await sqlite.processRecurring(), 2);
    expect(await sqlite.processRecurring(), 0);
    expect((await sqlite.getRecurring()).single.nextOn, tomorrow);
    await sqlite.saveRecurring(
      isExpense: true,
      category: food,
      walletName: cash,
      amount: 100,
      frequency: 'daily',
      startOn: yesterday,
      note: 'Tạm dừng',
    );
    final paused = (await sqlite.getRecurring()).singleWhere(
      (rule) => rule.note == 'Tạm dừng',
    );
    await sqlite.setRecurringActive(paused.id, false);
    expect(await sqlite.processRecurring(), 0);
    expect(await cashBalance(), -20);
  });

  test('Định kỳ ngày 31 trở về ngày 31 sau tháng Hai', () {
    final anchor = DateTime(2024, 1, 31);
    final february = RecurringModel.advance(anchor, 'monthly', anchor);
    expect(february, DateTime(2024, 2, 29));
    expect(
      RecurringModel.advance(february, 'monthly', anchor),
      DateTime(2024, 3, 31),
    );
  });

  test('Đính kèm hóa đơn sao chép dữ liệu ảnh và xóa cùng giao dịch', () async {
    final source = await File('${temp.path}/receipt.png')
        .writeAsBytes([1, 2, 3]);
    final id = await addExpense(10, firstDay, receiptPath: source.path);
    final attachment = File((await transactions.receiptOf(id))!);
    expect(attachment.path, isNot(source.path));
    expect(await attachment.readAsBytes(), await source.readAsBytes());
    await transactions.deleteTransaction(id);
    expect(await transactions.receiptOf(id), isNull);
    expect(await attachment.exists(), isFalse);
    expect(await source.exists(), isTrue);
  });

  Future<void> openForm(WidgetTester tester, Widget form) async {
    await tester.binding.setSurfaceSize(const Size(480, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: const Scaffold(),
          initialRoute: '/form',
          routes: {'/form': (_) => form},
        ),
      );
      await wallets.fetchWallets();
    });
    await tester.pumpAndSettle();
  }

  Future<void> saveForm(WidgetTester tester, Finder form, Finder save) async {
    final route = ModalRoute.of(tester.element(form))!;
    await tester.runAsync(() async {
      await tester.tap(save);
      expect(await route.popped.timeout(const Duration(seconds: 5)), isTrue);
    });
    await tester.pumpAndSettle();
  }

  testWidgets('Form giao dịch từ chối trống và 0, lưu khoản chi 1 đồng', (
    tester,
  ) async {
    await openForm(tester, const AddTransactionScreen());
    final save = find.text('Lưu giao dịch');
    final amount = find.byType(TextField).first;
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Nhập số tiền lớn hơn 0'), findsOneWidget);

    await tester.enterText(amount, '0');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Nhập số tiền lớn hơn 0'), findsOneWidget);
    expect(await tester.runAsync(transactions.fetchTransactions), isEmpty);

    await tester.enterText(amount, '1');
    await saveForm(tester, find.byType(AddTransactionScreen), save);
    expect(find.byType(AddTransactionScreen), findsNothing);
    final saved = await tester.runAsync(transactions.fetchTransactions);
    expect(saved!.single.amount, 1);
    expect(await tester.runAsync(cashBalance), -1);
  });

  testWidgets('Form chia 100% lưu phần dư đúng một đồng', (tester) async {
    final groups = GroupDebtController();
    final group = (await tester.runAsync(() async {
      final id = await groups.createGroup('Chuyến đi', ['An']);
      return groups.fetchGroup(id);
    }))!;
    final payer = group.me!.id;
    final other = group.members.singleWhere((member) => !member.isMe).id;
    await openForm(tester, AddGroupExpenseScreen(group: group));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '101');
    await tester.enterText(fields.at(1), 'Ăn trưa');
    await tester.tap(find.text('Theo %'));
    await tester.pumpAndSettle();
    await tester.enterText(fields.at(2), '50');
    await tester.enterText(fields.at(3), '50');
    await saveForm(
      tester,
      find.byType(AddGroupExpenseScreen),
      find.text('Lưu chi phí'),
    );

    expect(find.byType(AddGroupExpenseScreen), findsNothing);
    final updated = (await tester.runAsync(() => groups.fetchGroup(group.id)))!;
    expect(updated.totalExpense, 101);
    expect(updated.balances, {payer: 50, other: -50});
  });
}
