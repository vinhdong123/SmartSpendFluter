import '../core/utils/formatters.dart';

class BillModel {
  final String id;
  final String title;
  final int amount;
  final DateTime dueOn;
  final bool repeatMonthly;
  final bool paid;

  const BillModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueOn,
    required this.repeatMonthly,
    required this.paid,
  });

  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(dueOn.year, dueOn.month, dueOn.day).difference(today).inDays;
  }

  bool get isOverdue => !paid && daysLeft < 0;

  String get dueLabel => 'Đến hạn ${formatDate(dueOn)}';

  String get countdownLabel {
    final d = daysLeft;
    if (d < 0) return 'Quá hạn ${-d} ngày · ${formatDayMonth(dueOn)}';
    if (d == 0) return 'Đến hạn hôm nay · ${formatDayMonth(dueOn)}';
    return 'Còn $d ngày · ${formatDayMonth(dueOn)}';
  }
}
