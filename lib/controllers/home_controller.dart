import '../core/utils/formatters.dart';
import '../models/transaction_model.dart';
import '../repositories/transaction_repository.dart';
import '../services/finance_queries.dart';
import '../services/social_queries.dart';
import '../services/sqlite_database_service.dart';

class HomeData {
  final int balance;
  final int monthIncome;
  final int monthExpense;
  final List<TransactionModel> recent;
  final List<String> alerts;

  const HomeData({
    required this.balance,
    required this.monthIncome,
    required this.monthExpense,
    required this.recent,
    required this.alerts,
  });
}

class HomeController {
  final SQLiteDatabaseService _sqlite = SQLiteDatabaseService.instance;

  Future<HomeData> load() async {
    await TransactionRepository.instance.ensureDemoData();

    final wallets = await _sqlite.getWalletsWithBalance();
    final balance = wallets.fold<int>(0, (sum, w) => sum + w.balance);

    final range = periodRange(1);
    final totals = await _sqlite.getPeriodTotals(range.from, range.to);
    final recent = await _sqlite.getAllTransactions(limit: 5);

    final alerts = <String>[];
    final budget = await _sqlite.getBudgetOverview(period: 1);
    alerts.addAll(budget.alerts);

    final debts = await _sqlite.getDebts();
    for (final d in debts) {
      if (d.isOverdue) {
        alerts.add(d.isBorrowed
            ? 'Khoản nợ ${d.counterparty} đã quá hạn (${formatDayMonth(d.dueOn!)})'
            : '${d.counterparty} đã quá hạn trả bạn (${formatDayMonth(d.dueOn!)})');
      } else if (d.isDueSoon) {
        alerts.add(d.isBorrowed
            ? 'Sắp đến hạn trả ${d.counterparty} (${formatDayMonth(d.dueOn!)})'
            : '${d.counterparty} sắp đến hạn trả bạn (${formatDayMonth(d.dueOn!)})');
      }
    }

    return HomeData(
      balance: balance,
      monthIncome: totals.income,
      monthExpense: totals.expense,
      recent: recent,
      alerts: alerts,
    );
  }
}
