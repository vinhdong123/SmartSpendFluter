import 'package:material_ui/material_ui.dart';
import '../core/constants/categories.dart';

class BudgetItemModel {
  final String id;
  final String categoryCode;
  final int limit;
  final int spent;
  final int alertPct;

  const BudgetItemModel({
    required this.id,
    required this.categoryCode,
    required this.limit,
    required this.spent,
    required this.alertPct,
  });

  String get label => Categories.labelOf(categoryCode);
  IconData get icon => Categories.iconOf(label);
  int get percent => limit <= 0 ? (spent > 0 ? 100 : 0) : ((spent / limit) * 100).round();
  bool get isOver => spent > limit;
  bool get isWarning => percent >= alertPct;
}

class BudgetOverview {
  final bool exists;
  final int totalLimit;
  final int totalSpent;
  final int alertPct;
  final List<BudgetItemModel> items;

  const BudgetOverview({
    required this.exists,
    required this.totalLimit,
    required this.totalSpent,
    required this.alertPct,
    required this.items,
  });

  int get remaining => totalLimit - totalSpent;
  int get percent => totalLimit <= 0 ? 0 : ((totalSpent / totalLimit) * 100).round();

  /// Các cảnh báo hiển thị ở Trang chủ / Thông báo.
  List<String> get alerts {
    final result = <String>[];
    for (final item in items) {
      if (item.limit <= 0) continue;
      if (item.isOver) {
        result.add('${item.label} đã vượt ngân sách (${item.percent}%)');
      } else if (item.isWarning) {
        result.add('${item.label} đã dùng ${item.percent}% ngân sách tháng');
      }
    }
    if (exists && totalLimit > 0 && percent >= alertPct) {
      result.add(totalSpent > totalLimit
          ? 'Tổng chi tiêu đã vượt hạn mức tháng'
          : 'Tổng chi tiêu đã dùng $percent% hạn mức tháng');
    }
    return result;
  }
}
