import '../core/constants/categories.dart';
import '../core/utils/formatters.dart';
import '../models/budget_models.dart';
import '../models/transaction_model.dart';
import '../services/finance_queries.dart';
import '../services/sqlite_database_service.dart';
import '../services/sync_service.dart';

class BudgetController {
  final SQLiteDatabaseService _sqlite = SQLiteDatabaseService.instance;

  Future<BudgetOverview> fetchOverview(int period) => _sqlite.getBudgetOverview(period: period);

  Future<void> saveTotalLimit(int amount) =>
      markSynced(_sqlite.saveMonthBudget(month: DateTime.now(), totalLimit: amount));

  /// Hạn mức nhập theo kỳ (0 tuần / 1 tháng / 2 năm) -> hạn mức tháng lưu trong DB.
  int toMonthly(int period, int amount) {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month + 1, 0).day;
    if (period == 0) return (amount * days / 7).round();
    if (period == 2) return (amount / 12).round();
    return amount;
  }

  /// Hạn mức tháng -> hạn mức theo kỳ để hiển thị khi sửa.
  int fromMonthly(int period, int monthly) {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month + 1, 0).day;
    if (period == 0) return (monthly * 7 / days).round();
    if (period == 2) return monthly * 12;
    return monthly;
  }

  Future<void> saveCategoryLimit(String categoryLabel, int monthlyAmount, {int alertPct = 80}) =>
      markSynced(_sqlite.saveBudgetItem(
        month: DateTime.now(),
        categoryCode: Categories.codeOf(categoryLabel),
        limit: monthlyAmount,
        alertPct: alertPct,
      ));

  Future<void> deleteCategoryLimit(String itemId) => markSynced(_sqlite.deleteBudgetItem(itemId));

  Future<bool> copyFromPreviousMonth() => markSynced(_sqlite.copyPreviousMonthBudget(DateTime.now()));

  /// Giao dịch chi của một danh mục trong tháng này (lớn nhất trước).
  Future<List<TransactionModel>> monthTransactions(String categoryLabel, {bool largestFirst = false}) async {
    final now = DateTime.now();
    final list = await _sqlite.getAllTransactions(
      from: DateTime(now.year, now.month, 1),
      toExclusive: DateTime(now.year, now.month + 1, 1),
    );
    final result = list.where((t) => t.isExpense && t.category == categoryLabel).toList();
    if (largestFirst) result.sort((a, b) => b.amount.compareTo(a.amount));
    return result;
  }

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
