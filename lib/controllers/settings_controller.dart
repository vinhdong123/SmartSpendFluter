import '../core/constants/categories.dart';
import '../models/bill_model.dart';
import '../models/recurring_model.dart';
import '../services/extra_queries.dart';
import '../services/sqlite_database_service.dart';
import '../services/sync_service.dart';

class CategoryController {
  final SQLiteDatabaseService _sqlite = SQLiteDatabaseService.instance;

  Future<void> add(String label, bool isIncome, String iconKey) async {
    await Categories.add(label: label, isIncome: isIncome, iconKey: iconKey);
  }

  Future<void> update(CategoryInfo c, String label, String iconKey) async {
    final old = await Categories.update(code: c.code, label: label, iconKey: iconKey);
    if (old != label.trim()) {
      await markSynced(_sqlite.applyCategoryRename(code: c.code, oldLabel: old, newLabel: label.trim()));
    }
  }

  Future<void> delete(CategoryInfo c) async {
    await markSynced(_sqlite.applyCategoryDelete(c.code));
    await Categories.remove(c.code);
  }
}

class RecurringController {
  final SQLiteDatabaseService _sqlite = SQLiteDatabaseService.instance;

  Future<List<RecurringModel>> fetch() => _sqlite.getRecurring();

  Future<void> save({
    String? id,
    required bool isExpense,
    required String category,
    required String wallet,
    required int amount,
    required String frequency,
    required DateTime startOn,
    String note = '',
  }) async {
    await _sqlite.saveRecurring(
      id: id,
      isExpense: isExpense,
      category: category,
      walletName: wallet,
      amount: amount,
      frequency: frequency,
      startOn: startOn,
      note: note,
    );
    await _sqlite.processRecurring();
  }

  Future<void> setActive(String id, bool active) => _sqlite.setRecurringActive(id, active);

  Future<void> delete(String id) => _sqlite.deleteRecurring(id);
}

class BillController {
  final SQLiteDatabaseService _sqlite = SQLiteDatabaseService.instance;

  Future<List<BillModel>> fetch() => _sqlite.getBills();

  Future<void> save({String? id, required String title, required int amount, required DateTime dueOn, required bool repeatMonthly}) =>
      _sqlite.saveBill(id: id, title: title, amount: amount, dueOn: dueOn, repeatMonthly: repeatMonthly);

  Future<void> delete(String id) => _sqlite.deleteBill(id);

  Future<void> pay(BillModel bill, String wallet) => _sqlite.payBill(bill, wallet);
}
