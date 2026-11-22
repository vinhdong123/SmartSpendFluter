import '../services/sync_service.dart';
import '../models/goal_model.dart';
import '../models/wallet_model.dart';
import '../services/finance_queries.dart';
import '../services/sqlite_database_service.dart';

class WalletController {
  final SQLiteDatabaseService _sqlite = SQLiteDatabaseService.instance;

  Future<List<WalletModel>> fetchWallets() => _sqlite.getWalletsWithBalance();

  Future<bool> nameExists(String name) => _sqlite.walletNameExists(name);

  Future<void> addWallet(String name, String type, int initial) =>
      markSynced(_sqlite.addWallet(name: name, type: type, initialBalance: initial));

  Future<void> setInitialBalance(String id, int amount) => markSynced(_sqlite.setWalletInitialBalance(id, amount));
}

class GoalController {
  final SQLiteDatabaseService _sqlite = SQLiteDatabaseService.instance;

  Future<List<SavingsGoalModel>> fetchGoals() => _sqlite.getSavingsGoals();
  Future<List<WalletModel>> fetchWallets() => _sqlite.getWalletsWithBalance();

  Future<void> addGoal(String name, int target, DateTime? deadline) =>
      markSynced(_sqlite.addSavingsGoal(name: name, target: target, deadline: deadline));

  Future<void> contribute(String goalId, String walletName, int amount, bool isRelease) => markSynced(
      _sqlite.addGoalContribution(goalId: goalId, walletName: walletName, amount: amount, isRelease: isRelease));

  Future<void> archive(String goalId) => markSynced(_sqlite.archiveGoal(goalId));
}
