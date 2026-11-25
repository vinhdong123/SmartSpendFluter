import '../core/utils/formatters.dart';
import '../models/report_models.dart';
import '../models/transaction_model.dart';
import '../services/sqlite_database_service.dart';

class ReportData {
  final List<SeriesPoint> series;
  final List<CategoryTotal> categories;
  final int income;
  final int expense;
  final List<TransactionModel> transactions;

  const ReportData({
    required this.series,
    required this.categories,
    required this.income,
    required this.expense,
    required this.transactions,
  });

  int get totalCategory => categories.fold<int>(0, (sum, c) => sum + c.total);
}

class ReportController {
  final SQLiteDatabaseService _sqlite = SQLiteDatabaseService.instance;

  static const List<String> periodNames = ['Tuần', 'Tháng', 'Năm'];

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _inRange(TransactionModel t, DateTime from, DateTime to) {
    final d = _day(t.date);
    return !d.isBefore(from) && d.isBefore(to);
  }

  Future<List<TransactionModel>> _scoped(ReportFilter f) async {
    final all = await _sqlite.getAllTransactions();
    return f.wallet == null ? all : all.where((t) => t.wallet == f.wallet).toList();
  }

  Future<ReportData> load(ReportFilter f) async {
    final all = await _scoped(f);
    final b = f.bounds();
    final inRange = all.where((t) => _inRange(t, b.from, b.to)).toList();

    var income = 0;
    var expense = 0;
    final byCategory = <String, int>{};
    for (final t in inRange) {
      final v = t.amount.round();
      if (t.isExpense) {
        expense += v;
      } else {
        income += v;
      }
      final counted = f.type == 2 ? !t.isExpense : t.isExpense;
      if (counted) byCategory[t.category] = (byCategory[t.category] ?? 0) + v;
    }
    final categories = [
      for (final e in byCategory.entries) CategoryTotal(label: e.key, total: e.value),
    ]..sort((a, c) => c.total.compareTo(a.total));

    final shown = f.type == 0
        ? inRange
        : inRange.where((t) => f.type == 1 ? t.isExpense : !t.isExpense).toList();

    return ReportData(
      series: _series(all, f.chartPeriod, income: f.type == 2),
      categories: categories,
      income: income,
      expense: expense,
      transactions: shown,
    );
  }

  /// Chi tiêu (hoặc thu nhập) theo ngày (7 ngày) / tháng (6 tháng) / năm (5 năm).
  List<SeriesPoint> _series(List<TransactionModel> all, int period, {required bool income}) {
    final now = DateTime.now();
    final keys = <String>[];
    final labels = <String>[];
    late final int keyLen;
    if (period == 0) {
      keyLen = 10;
      const names = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
      for (var i = 0; i < 7; i++) {
        final d = DateTime(now.year, now.month, now.day - (6 - i));
        keys.add(dbDate(d));
        labels.add(names[d.weekday - 1]);
      }
    } else if (period == 2) {
      keyLen = 4;
      for (var i = 0; i < 5; i++) {
        final y = now.year - (4 - i);
        keys.add(y.toString().padLeft(4, '0'));
        labels.add('$y');
      }
    } else {
      keyLen = 7;
      for (var i = 0; i < 6; i++) {
        final d = DateTime(now.year, now.month - (5 - i), 1);
        keys.add('${d.year.toString().padLeft(4, '0')}-${two(d.month)}');
        labels.add('T${d.month}');
      }
    }
    final totals = <String, int>{};
    for (final t in all) {
      if (t.isExpense == income) continue;
      final key = dbDate(t.date).substring(0, keyLen);
      totals[key] = (totals[key] ?? 0) + t.amount.round();
    }
    return [
      for (var i = 0; i < keys.length; i++)
        SeriesPoint(label: labels[i], value: totals[keys[i]] ?? 0, isCurrent: i == keys.length - 1),
    ];
  }

  /// So sánh chi tiêu kỳ này với kỳ trước. mode: 0 = tháng, 1 = quý, 2 = năm.
  Future<CompareResult> compare(int mode, {String? wallet}) async {
    final all = await _scoped(ReportFilter(wallet: wallet));
    final now = DateTime.now();
    late DateTime curFrom, curTo, prevFrom, prevTo;
    late String curLabel, prevLabel;
    if (mode == 2) {
      curFrom = DateTime(now.year, 1, 1);
      curTo = DateTime(now.year + 1, 1, 1);
      prevFrom = DateTime(now.year - 1, 1, 1);
      prevTo = curFrom;
      curLabel = 'Năm ${now.year}';
      prevLabel = 'Năm ${now.year - 1}';
    } else if (mode == 1) {
      final startMonth = ((now.month - 1) ~/ 3) * 3 + 1;
      curFrom = DateTime(now.year, startMonth, 1);
      curTo = DateTime(now.year, startMonth + 3, 1);
      prevFrom = DateTime(now.year, startMonth - 3, 1);
      prevTo = curFrom;
      curLabel = 'Quý ${((curFrom.month - 1) ~/ 3) + 1}/${curFrom.year}';
      prevLabel = 'Quý ${((prevFrom.month - 1) ~/ 3) + 1}/${prevFrom.year}';
    } else {
      curFrom = DateTime(now.year, now.month, 1);
      curTo = DateTime(now.year, now.month + 1, 1);
      prevFrom = DateTime(now.year, now.month - 1, 1);
      prevTo = curFrom;
      curLabel = 'Tháng ${curFrom.month}';
      prevLabel = 'Tháng ${prevFrom.month}';
    }

    final cur = <String, int>{};
    final prev = <String, int>{};
    for (final t in all) {
      if (!t.isExpense) continue;
      final v = t.amount.round();
      if (_inRange(t, curFrom, curTo)) cur[t.category] = (cur[t.category] ?? 0) + v;
      if (_inRange(t, prevFrom, prevTo)) prev[t.category] = (prev[t.category] ?? 0) + v;
    }
    final labels = {...cur.keys, ...prev.keys}.toList();
    final deltas = [
      for (final l in labels) CategoryDelta(label: l, current: cur[l] ?? 0, previous: prev[l] ?? 0),
    ]..sort((a, b) => b.current.compareTo(a.current));

    return CompareResult(
      currentLabel: curLabel,
      previousLabel: prevLabel,
      current: cur.values.fold<int>(0, (a, b) => a + b),
      previous: prev.values.fold<int>(0, (a, b) => a + b),
      deltas: deltas,
    );
  }

  /// Danh sách 12 tháng gần nhất để chọn kỳ xuất báo cáo.
  List<DateTime> recentMonths() {
    final now = DateTime.now();
    return [for (var i = 0; i < 12; i++) DateTime(now.year, now.month - i, 1)];
  }
}
