import 'package:material_ui/material_ui.dart';
import 'bill_model.dart';
import 'budget_models.dart';
import 'debt_model.dart';
import 'goal_model.dart';

enum NotifKind { budgetOver, budgetWarning, budgetTotal, bill, debt, goal }

class NotificationItem {
  final NotifKind kind;
  final String title;
  final String subtitle;
  final IconData icon;
  final BudgetItemModel? budget;
  final BillModel? bill;
  final DebtModel? debt;
  final SavingsGoalModel? goal;

  const NotificationItem({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.budget,
    this.bill,
    this.debt,
    this.goal,
  });

  /// Cảnh báo cần chú ý ngay (hiện ở banner Trang chủ), không tính mục tiêu.
  bool get isAlert => kind != NotifKind.goal;
}
