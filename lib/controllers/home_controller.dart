import '../models/goal_model.dart';
import '../models/notification_item.dart';
import '../models/transaction_model.dart';
import '../repositories/transaction_repository.dart';
import '../core/utils/formatters.dart';
import '../services/finance_queries.dart';
import '../services/sqlite_database_service.dart';
import 'notification_controller.dart';

class HomeData {
  final int balance;
  final int monthIncome;
  final int monthExpense;
  final List<TransactionModel> recent;
  final List<NotificationItem> alerts;
  final SavingsGoalModel? goal;

  const HomeData({
    required this.balance,
    required this.monthIncome,
    required this.monthExpense,
    required this.recent,
    required this.alerts,
    required this.goal,
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

    final notifications = await NotificationController().load();
    final goals = await _sqlite.getSavingsGoals();
    SavingsGoalModel? goal;
    for (final g in goals) {
      if (!g.isDone) {
        goal = g;
        break;
      }
    }
    goal ??= goals.isEmpty ? null : goals.first;

    return HomeData(
      balance: balance,
      monthIncome: totals.income,
      monthExpense: totals.expense,
      recent: recent,
      alerts: notifications.where((n) => n.isAlert).toList(),
      goal: goal,
    );
  }
}
