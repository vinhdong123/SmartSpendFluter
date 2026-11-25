import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/app_settings.dart';
import '../core/utils/formatters.dart';
import '../models/budget_models.dart';
import '../models/notification_item.dart';
import '../services/extra_queries.dart';
import '../services/finance_queries.dart';
import '../services/social_queries.dart';
import '../services/sqlite_database_service.dart';

/// Thông báo được tính trực tiếp từ dữ liệu: ngân sách, hóa đơn, nợ, mục tiêu.
class NotificationController {
  final SQLiteDatabaseService _sqlite = SQLiteDatabaseService.instance;

  String _dismissKey() => 'dismissed_alerts_${_sqlite.uid}';

  String _monthTag(String code) {
    final n = DateTime.now();
    return '${n.year}${two(n.month)}:$code';
  }

  Future<Set<String>> _dismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_dismissKey()) ?? const <String>[]).toSet();
  }

  /// Bỏ qua cảnh báo vượt ngân sách của danh mục trong tháng này.
  Future<void> dismissBudget(BudgetItemModel item) async {
    final prefs = await SharedPreferences.getInstance();
    final set = await _dismissed();
    set.add(_monthTag(item.categoryCode));
    await prefs.setStringList(_dismissKey(), set.toList());
  }

  Future<List<NotificationItem>> load() async {
    final out = <NotificationItem>[];
    final dismissed = await _dismissed();

    final budget = await _sqlite.getBudgetOverview(period: 1);
    final over = <NotificationItem>[];
    final warn = <NotificationItem>[];
    for (final item in budget.items) {
      if (item.limit <= 0 || dismissed.contains(_monthTag(item.categoryCode))) continue;
      if (item.isOver) {
        over.add(NotificationItem(
          kind: NotifKind.budgetOver,
          title: '${item.label} đã vượt hạn mức',
          subtitle: 'Đã chi ${formatVND(item.spent)} / ${formatVND(item.limit)} (${item.percent}%)',
          icon: Icons.warning_amber_rounded,
          budget: item,
        ));
      } else if (item.isWarning) {
        warn.add(NotificationItem(
          kind: NotifKind.budgetWarning,
          title: '${item.label} đã dùng ${item.percent}%',
          subtitle: 'Cảnh báo ngân sách',
          icon: Icons.warning_amber_rounded,
          budget: item,
        ));
      }
    }
    out
      ..addAll(over)
      ..addAll(warn);
    if (budget.exists && budget.totalLimit > 0 && budget.percent >= budget.alertPct) {
      out.add(NotificationItem(
        kind: NotifKind.budgetTotal,
        title: budget.totalSpent > budget.totalLimit
            ? 'Tổng chi tiêu đã vượt hạn mức tháng'
            : 'Tổng chi tiêu đã dùng ${budget.percent}% hạn mức tháng',
        subtitle: 'Đã chi ${formatVND(budget.totalSpent)} / ${formatVND(budget.totalLimit)}',
        icon: Icons.account_balance_wallet_outlined,
      ));
    }

    final bills = await _sqlite.getBills();
    for (final b in bills) {
      if (b.daysLeft <= AppSettings.billRemindDays) {
        out.add(NotificationItem(
          kind: NotifKind.bill,
          title: b.isOverdue ? 'Hóa đơn ${b.title.toLowerCase()} đã quá hạn' : 'Hóa đơn ${b.title.toLowerCase()} sắp đến hạn',
          subtitle: b.countdownLabel,
          icon: Icons.bolt_rounded,
          bill: b,
        ));
      }
    }

    final debts = await _sqlite.getDebts();
    for (final d in debts) {
      if (!d.isOverdue && !d.isDueSoon) continue;
      final who = d.counterparty;
      out.add(NotificationItem(
        kind: NotifKind.debt,
        title: d.isOverdue
            ? (d.isBorrowed ? 'Khoản nợ $who đã quá hạn' : '$who đã quá hạn trả bạn')
            : (d.isBorrowed ? 'Sắp đến hạn trả $who' : '$who sắp đến hạn trả bạn'),
        subtitle: 'Còn ${formatVND(d.remaining)} · Hạn ${formatDayMonth(d.dueOn!)}',
        icon: Icons.handshake_outlined,
        debt: d,
      ));
    }

    final goals = await _sqlite.getSavingsGoals();
    for (final g in goals) {
      if (g.saved <= 0) continue;
      out.add(NotificationItem(
        kind: NotifKind.goal,
        title: g.isDone ? 'Mục tiêu ${g.name} đã hoàn thành' : 'Mục tiêu ${g.name} đạt ${g.percent}%',
        subtitle: '${formatVND(g.saved)} / ${formatVND(g.target)}',
        icon: Icons.track_changes_outlined,
        goal: g,
      ));
    }
    return out;
  }
}
