import '../core/constants/categories.dart';
import '../core/utils/formatters.dart';
import '../models/budget_models.dart';
import '../services/finance_queries.dart';
import '../services/sqlite_database_service.dart';

class BudgetController {
  final SQLiteDatabaseService _sqlite = SQLiteDatabaseService.instance;

  Future<BudgetOverview> fetchOverview(int period) => _sqlite.getBudgetOverview(period: period);

  Future<void> saveTotalLimit(int amount) =>
      _sqlite.saveMonthBudget(month: DateTime.now(), totalLimit: amount);

  Future<void> saveCategoryLimit(String categoryLabel, int amount) => _sqlite.saveBudgetItem(
        month: DateTime.now(),
        categoryCode: Categories.codeOf(categoryLabel),
        limit: amount,
      );

  Future<void> deleteCategoryLimit(String itemId) => _sqlite.deleteBudgetItem(itemId);

  Future<bool> copyFromPreviousMonth() => _sqlite.copyPreviousMonthBudget(DateTime.now());

  /// Thông báo cảnh báo sau khi ghi một khoản chi (null nếu chưa chạm ngưỡng).
  Future<String?> alertAfterExpense(String categoryLabel, DateTime date) async {
    final now = DateTime.now();
    if (date.year != now.year || date.month != now.month) return null;
    final overview = await _sqlite.getBudgetOverview(period: 1);
    if (!overview.exists) return null;
    for (final item in overview.items) {
      if (item.label == categoryLabel && item.limit > 0 && item.isWarning) {
        return item.isOver
            ? '${item.label} đã vượt ngân sách: ${formatVND(item.spent)} / ${formatVND(item.limit)}'
            : '${item.label} đã dùng ${item.percent}% ngân sách tháng';
      }
    }
    return null;
  }
}
