import 'package:sqflite/sqflite.dart';
import '../core/constants/categories.dart';
import '../core/utils/formatters.dart';
import '../models/budget_models.dart';
import '../models/goal_model.dart';
import '../models/report_models.dart';
import '../models/wallet_model.dart';
import 'sqlite_database_service.dart';

/// Ví, ngân sách, mục tiêu tiết kiệm và báo cáo.
extension FinanceQueries on SQLiteDatabaseService {
  // ================= WALLETS ================= //

  Future<List<WalletModel>> getWalletsWithBalance() async {
    final db = await readyDatabase;
    final rows = await db.rawQuery('''
      SELECT w.id, w.name, w.type, w.initial_balance,
        w.initial_balance
        + COALESCE((SELECT SUM(amount) FROM transactions WHERE wallet_id = w.id AND type = 'income'), 0)
        - COALESCE((SELECT SUM(amount) FROM transactions WHERE wallet_id = w.id AND type = 'expense'), 0)
        + COALESCE((SELECT SUM(amount) FROM transactions WHERE to_wallet_id = w.id AND type = 'transfer'), 0)
        - COALESCE((SELECT SUM(amount) FROM transactions WHERE wallet_id = w.id AND type = 'transfer'), 0)
        AS balance
      FROM wallets w
      WHERE w.user_id = ? AND w.is_archived = 0
      ORDER BY w.rowid
    ''', [uid]);
    return rows
        .map((r) => WalletModel(
              id: r['id'] as String,
              name: r['name'] as String,
              type: r['type'] as String,
              initialBalance: (r['initial_balance'] as num).toInt(),
              balance: (r['balance'] as num).toInt(),
            ))
        .toList();
  }

  Future<void> addWallet({required String name, required String type, required int initialBalance}) async {
    final db = await readyDatabase;
    await db.insert('wallets', {
      'id': 'w_${uid}_${DateTime.now().microsecondsSinceEpoch}',
      'user_id': uid,
      'name': name.trim(),
      'type': type,
      'initial_balance': initialBalance,
    });
  }

  Future<void> setWalletInitialBalance(String walletId, int amount) async {
    final db = await readyDatabase;
    await db.update(
      'wallets',
      {'initial_balance': amount},
      where: 'id = ? AND user_id = ?',
      whereArgs: [walletId, uid],
    );
  }

  Future<bool> walletNameExists(String name) async {
    final db = await readyDatabase;
    final rows = await db.query(
      'wallets',
      columns: ['id'],
      where: 'user_id = ? AND LOWER(name) = ? AND is_archived = 0',
      whereArgs: [uid, name.trim().toLowerCase()],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // ================= BUDGETS ================= //

  String _budgetId(DateTime month) => 'budget_${uid}_${month.year}_${two(month.month)}';

  /// Tổng quan ngân sách. period: 0 = tuần, 1 = tháng, 2 = năm.
  /// Hạn mức luôn lưu theo tháng; tuần/năm được quy đổi (x 7/số ngày trong tháng, x 12).
  Future<BudgetOverview> getBudgetOverview({int period = 1, DateTime? ref}) async {
    final db = await readyDatabase;
    final now = ref ?? DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final daysInMonth = nextMonth.difference(monthStart).inDays;
    final range = periodRange(period, now);
    final factor = period == 0 ? 7 / daysInMonth : (period == 2 ? 12.0 : 1.0);

    final spentRows = await db.rawQuery('''
      SELECT kind, SUM(amount) AS total
      FROM transactions
      WHERE user_id = ? AND type = 'expense' AND occurred_on >= ? AND occurred_on < ?
      GROUP BY kind
    ''', [uid, dbDate(range.from), dbDate(range.to)]);
    final spentByLabel = <String, int>{
      for (final r in spentRows) (r['kind'] as String): (r['total'] as num).toInt(),
    };
    final totalSpent = spentByLabel.values.fold<int>(0, (a, b) => a + b);

    final budgetRows = await db.query(
      'budgets',
      where: 'user_id = ? AND month_start = ?',
      whereArgs: [uid, dbDate(monthStart)],
      limit: 1,
    );
    if (budgetRows.isEmpty) {
      return BudgetOverview(exists: false, totalLimit: 0, totalSpent: totalSpent, alertPct: 80, items: const []);
    }

    final budget = budgetRows.first;
    final budgetId = budget['id'] as String;
    final itemRows = await db.query(
      'budget_items',
      where: 'budget_id = ?',
      whereArgs: [budgetId],
      orderBy: 'rowid',
    );

    final items = <BudgetItemModel>[];
    for (final r in itemRows) {
      final code = r['category_code'] as String;
      final label = Categories.labelOf(code);
      items.add(BudgetItemModel(
        id: r['id'] as String,
        categoryCode: code,
        limit: ((r['limit_amount'] as num) * factor).round(),
        spent: spentByLabel[label] ?? 0,
        alertPct: (r['alert_threshold_pct'] as num).toInt(),
      ));
    }

    return BudgetOverview(
      exists: true,
      totalLimit: ((budget['total_limit'] as num) * factor).round(),
      totalSpent: totalSpent,
      alertPct: (budget['alert_threshold_pct'] as num).toInt(),
      items: items,
    );
  }

  Future<void> saveMonthBudget({required DateTime month, required int totalLimit, int alertPct = 80}) async {
    final db = await readyDatabase;
    final key = dbDate(DateTime(month.year, month.month, 1));
    final existing = await db.query(
      'budgets',
      columns: ['id'],
      where: 'user_id = ? AND month_start = ?',
      whereArgs: [uid, key],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert('budgets', {
        'id': _budgetId(month),
        'user_id': uid,
        'month_start': key,
        'total_limit': totalLimit,
        'alert_threshold_pct': alertPct,
      });
    } else {
      await db.update(
        'budgets',
        {'total_limit': totalLimit},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
  }

  Future<void> saveBudgetItem({
    required DateTime month,
    required String categoryCode,
    required int limit,
  }) async {
    final db = await readyDatabase;
    final key = dbDate(DateTime(month.year, month.month, 1));
    var rows = await db.query(
      'budgets',
      columns: ['id', 'total_limit'],
      where: 'user_id = ? AND month_start = ?',
      whereArgs: [uid, key],
      limit: 1,
    );
    if (rows.isEmpty) {
      await saveMonthBudget(month: month, totalLimit: limit);
      rows = await db.query(
        'budgets',
        columns: ['id', 'total_limit'],
        where: 'user_id = ? AND month_start = ?',
        whereArgs: [uid, key],
        limit: 1,
      );
    }
    final budgetId = rows.first['id'] as String;
    await db.insert(
      'budget_items',
      {
        'id': 'bi_${budgetId}_$categoryCode',
        'budget_id': budgetId,
        'category_code': categoryCode,
        'limit_amount': limit,
        'alert_threshold_pct': 80,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteBudgetItem(String itemId) async {
    final db = await readyDatabase;
    await db.delete('budget_items', where: 'id = ?', whereArgs: [itemId]);
  }

  /// Sao chép ngân sách tháng trước sang tháng [month]. Trả về false nếu tháng trước chưa có.
  Future<bool> copyPreviousMonthBudget(DateTime month) async {
    final db = await readyDatabase;
    final prev = DateTime(month.year, month.month - 1, 1);
    final prevRows = await db.query(
      'budgets',
      where: 'user_id = ? AND month_start = ?',
      whereArgs: [uid, dbDate(prev)],
      limit: 1,
    );
    if (prevRows.isEmpty) return false;

    await saveMonthBudget(
      month: month,
      totalLimit: (prevRows.first['total_limit'] as num).toInt(),
      alertPct: (prevRows.first['alert_threshold_pct'] as num).toInt(),
    );
    final items = await db.query('budget_items', where: 'budget_id = ?', whereArgs: [prevRows.first['id']]);
    for (final r in items) {
      await saveBudgetItem(
        month: month,
        categoryCode: r['category_code'] as String,
        limit: (r['limit_amount'] as num).toInt(),
      );
    }
    return true;
  }

  // ================= SAVINGS GOALS ================= //

  Future<List<SavingsGoalModel>> getSavingsGoals() async {
    final db = await readyDatabase;
    final rows = await db.rawQuery('''
      SELECT g.id, g.name, g.target_amount, g.deadline,
        COALESCE(SUM(CASE c.direction WHEN 'allocate' THEN c.amount WHEN 'release' THEN -c.amount ELSE 0 END), 0) AS saved
      FROM savings_goals g
      LEFT JOIN goal_contributions c ON c.goal_id = g.id
      WHERE g.user_id = ? AND g.is_archived = 0
      GROUP BY g.id
      ORDER BY g.rowid
    ''', [uid]);
    return rows
        .map((r) => SavingsGoalModel(
              id: r['id'] as String,
              name: r['name'] as String,
              target: (r['target_amount'] as num).toInt(),
              saved: (r['saved'] as num).toInt(),
              deadline: r['deadline'] == null ? null : DateTime.tryParse(r['deadline'] as String),
            ))
        .toList();
  }

  Future<void> addSavingsGoal({required String name, required int target, DateTime? deadline}) async {
    final db = await readyDatabase;
    await db.insert('savings_goals', {
      'id': 'goal_${DateTime.now().microsecondsSinceEpoch}',
      'user_id': uid,
      'name': name.trim(),
      'target_amount': target,
      'deadline': deadline == null ? null : dbDate(deadline),
    });
  }

  Future<void> addGoalContribution({
    required String goalId,
    required String walletName,
    required int amount,
    required bool isRelease,
  }) async {
    final db = await readyDatabase;
    final walletId = await resolveWalletId(walletName);
    await db.insert('goal_contributions', {
      'id': 'gc_${DateTime.now().microsecondsSinceEpoch}',
      'goal_id': goalId,
      'wallet_id': walletId,
      'direction': isRelease ? 'release' : 'allocate',
      'amount': amount,
      'occurred_on': dbDate(DateTime.now()),
    });
  }

  Future<void> archiveGoal(String goalId) async {
    final db = await readyDatabase;
    await db.update(
      'savings_goals',
      {'is_archived': 1},
      where: 'id = ? AND user_id = ?',
      whereArgs: [goalId, uid],
    );
  }

  // ================= REPORTS ================= //

  /// Chi tiêu theo tuần (7 ngày) / tháng (6 tháng) / năm (5 năm).
  Future<List<SeriesPoint>> getExpenseSeries(int period) async {
    final db = await readyDatabase;
    final now = DateTime.now();

    final keys = <String>[];
    final labels = <String>[];
    late final DateTime from;
    late final int keyLen;

    if (period == 0) {
      keyLen = 10;
      const names = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
      for (var i = 0; i < 7; i++) {
        final d = DateTime(now.year, now.month, now.day - (6 - i));
        keys.add(dbDate(d));
        labels.add(names[d.weekday - 1]);
      }
      from = DateTime(now.year, now.month, now.day - 6);
    } else if (period == 2) {
      keyLen = 4;
      for (var i = 0; i < 5; i++) {
        final y = now.year - (4 - i);
        keys.add(y.toString().padLeft(4, '0'));
        labels.add('$y');
      }
      from = DateTime(now.year - 4, 1, 1);
    } else {
      keyLen = 7;
      for (var i = 0; i < 6; i++) {
        final d = DateTime(now.year, now.month - (5 - i), 1);
        keys.add('${d.year.toString().padLeft(4, '0')}-${two(d.month)}');
        labels.add('T${d.month}');
      }
      from = DateTime(now.year, now.month - 5, 1);
    }

    final rows = await db.rawQuery('''
      SELECT substr(occurred_on, 1, $keyLen) AS bucket, SUM(amount) AS total
      FROM transactions
      WHERE user_id = ? AND type = 'expense' AND occurred_on >= ?
      GROUP BY bucket
    ''', [uid, dbDate(from)]);
    final totals = <String, int>{
      for (final r in rows) (r['bucket'] as String): (r['total'] as num).toInt(),
    };

    return [
      for (var i = 0; i < keys.length; i++)
        SeriesPoint(label: labels[i], value: totals[keys[i]] ?? 0, isCurrent: i == keys.length - 1),
    ];
  }

  Future<List<CategoryTotal>> getCategoryTotals(DateTime from, DateTime toExclusive) async {
    final db = await readyDatabase;
    final rows = await db.rawQuery('''
      SELECT kind, SUM(amount) AS total
      FROM transactions
      WHERE user_id = ? AND type = 'expense' AND occurred_on >= ? AND occurred_on < ?
      GROUP BY kind
      ORDER BY total DESC
    ''', [uid, dbDate(from), dbDate(toExclusive)]);
    return rows
        .map((r) => CategoryTotal(label: r['kind'] as String, total: (r['total'] as num).toInt()))
        .toList();
  }
}
