import '../core/utils/formatters.dart';

class RecurringModel {
  final String id;
  final bool isExpense;
  final String category;
  final String wallet;
  final int amount;
  final String frequency; // daily | weekly | monthly | yearly
  final DateTime startOn;
  final DateTime nextOn;
  final String note;
  final bool active;

  const RecurringModel({
    required this.id,
    required this.isExpense,
    required this.category,
    required this.wallet,
    required this.amount,
    required this.frequency,
    required this.startOn,
    required this.nextOn,
    required this.note,
    required this.active,
  });

  String get title => note.trim().isEmpty ? category : note.trim();

  String get formattedAmount => '${isExpense ? '-' : '+'}${formatVND(amount)}';

  /// "Hàng tháng · ngày 5"
  String get scheduleLabel {
    switch (frequency) {
      case 'daily':
        return 'Hàng ngày';
      case 'weekly':
        return 'Hàng tuần · ${weekdayName(startOn.weekday)}';
      case 'yearly':
        return 'Hàng năm · ${formatDayMonth(startOn)}';
      default:
        return 'Hàng tháng · ngày ${startOn.day}';
    }
  }

  static const Map<String, String> frequencyLabels = {
    'daily': 'Hàng ngày',
    'weekly': 'Hàng tuần',
    'monthly': 'Hàng tháng',
    'yearly': 'Hàng năm',
  };

  static String weekdayName(int weekday) {
    const names = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
    return names[(weekday - 1).clamp(0, 6)];
  }

  /// Ngày phát sinh kế tiếp sau [from].
  static DateTime advance(DateTime from, String frequency, DateTime anchor) {
    switch (frequency) {
      case 'daily':
        return DateTime(from.year, from.month, from.day + 1);
      case 'weekly':
        return DateTime(from.year, from.month, from.day + 7);
      case 'yearly':
        return _clamped(from.year + 1, anchor.month, anchor.day);
      default:
        return _clamped(from.year, from.month + 1, anchor.day);
    }
  }

  static DateTime _clamped(int year, int month, int day) {
    final first = DateTime(year, month, 1);
    final last = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(first.year, first.month, day > last ? last : day);
  }
}
