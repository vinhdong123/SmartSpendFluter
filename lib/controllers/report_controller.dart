import '../core/utils/formatters.dart';
import '../models/report_models.dart';
import '../models/transaction_model.dart';
import '../services/finance_queries.dart';
import '../services/sqlite_database_service.dart';

class ReportData {
  final List<SeriesPoint> series;
  final List<CategoryTotal> categories;
  final int income;
  final int expense;

  const ReportData({
    required this.series,
    required this.categories,
    required this.income,
    required this.expense,
  });

  int get totalCategoryExpense => categories.fold<int>(0, (sum, c) => sum + c.total);
}

class ReportController {
  final SQLiteDatabaseService _sqlite = SQLiteDatabaseService.instance;

  static const List<String> periodNames = ['Tuần', 'Tháng', 'Năm'];

  Future<ReportData> load(int period) async {
    final range = periodRange(period);
    final series = await _sqlite.getExpenseSeries(period);
    final categories = await _sqlite.getCategoryTotals(range.from, range.to);
    final totals = await _sqlite.getPeriodTotals(range.from, range.to);
    return ReportData(series: series, categories: categories, income: totals.income, expense: totals.expense);
  }

  /// Báo cáo dạng CSV (mở được bằng Excel / Google Sheets).
  Future<String> buildCsv(int period) async {
    final range = periodRange(period);
    final list = await _sqlite.getAllTransactions(from: range.from, toExclusive: range.to);
    String esc(String v) => '"${v.replaceAll('"', '""')}"';
    final buffer = StringBuffer('Ngày,Loại,Danh mục,Ví,Số tiền,Ghi chú\n');
    for (final TransactionModel t in list) {
      buffer.writeln([
        formatDate(t.date),
        t.isExpense ? 'Chi tiêu' : 'Thu nhập',
        esc(t.category),
        esc(t.wallet),
        t.amount.round(),
        esc(t.note ?? t.title),
      ].join(','));
    }
    return buffer.toString();
  }
}
