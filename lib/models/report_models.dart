import '../core/utils/formatters.dart';

class SeriesPoint {
  final String label;
  final int value;
  final bool isCurrent;

  const SeriesPoint({required this.label, required this.value, required this.isCurrent});
}

class CategoryTotal {
  final String label;
  final int total;

  const CategoryTotal({required this.label, required this.total});
}

enum ReportRange { week, month, quarter, year, custom }

/// Bộ lọc báo cáo: khoảng thời gian, ví, loại giao dịch.
class ReportFilter {
  final ReportRange range;
  final DateTime? customFrom;
  final DateTime? customTo; // bao gồm
  final String? wallet;
  final int type; // 0: tất cả, 1: chi tiêu, 2: thu nhập

  const ReportFilter({
    this.range = ReportRange.month,
    this.customFrom,
    this.customTo,
    this.wallet,
    this.type = 0,
  });

  ReportFilter copyWith({
    ReportRange? range,
    DateTime? customFrom,
    DateTime? customTo,
    String? wallet,
    bool clearWallet = false,
    int? type,
  }) {
    return ReportFilter(
      range: range ?? this.range,
      customFrom: customFrom ?? this.customFrom,
      customTo: customTo ?? this.customTo,
      wallet: clearWallet ? null : (wallet ?? this.wallet),
      type: type ?? this.type,
    );
  }

  /// 0: tuần, 1: tháng, 2: năm — độ chi tiết của biểu đồ.
  int get chartPeriod => range == ReportRange.week ? 0 : (range == ReportRange.year ? 2 : 1);

  /// Chỉ số tab Tuần/Tháng/Năm tương ứng (-1 nếu là quý / tùy chọn).
  int get tabIndex {
    switch (range) {
      case ReportRange.week:
        return 0;
      case ReportRange.month:
        return 1;
      case ReportRange.year:
        return 2;
      default:
        return -1;
    }
  }

  /// Khoảng [from, to) theo ngày.
  ({DateTime from, DateTime to}) bounds([DateTime? ref]) {
    final now = ref ?? DateTime.now();
    switch (range) {
      case ReportRange.week:
        final from = DateTime(now.year, now.month, now.day - (now.weekday - 1));
        return (from: from, to: DateTime(from.year, from.month, from.day + 7));
      case ReportRange.quarter:
        final startMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        return (from: DateTime(now.year, startMonth, 1), to: DateTime(now.year, startMonth + 3, 1));
      case ReportRange.year:
        return (from: DateTime(now.year, 1, 1), to: DateTime(now.year + 1, 1, 1));
      case ReportRange.custom:
        final a = customFrom ?? DateTime(now.year, now.month, 1);
        final b = customTo ?? now;
        final from = DateTime(a.year, a.month, a.day);
        final to = DateTime(b.year, b.month, b.day + 1);
        return to.isAfter(from) ? (from: from, to: to) : (from: from, to: DateTime(from.year, from.month, from.day + 1));
      case ReportRange.month:
        return (from: DateTime(now.year, now.month, 1), to: DateTime(now.year, now.month + 1, 1));
    }
  }

  String get rangeLabel {
    final b = bounds();
    switch (range) {
      case ReportRange.week:
        return 'Tuần này';
      case ReportRange.month:
        return 'Tháng ${b.from.month}/${b.from.year}';
      case ReportRange.quarter:
        return 'Quý ${((b.from.month - 1) ~/ 3) + 1}/${b.from.year}';
      case ReportRange.year:
        return 'Năm ${b.from.year}';
      case ReportRange.custom:
        final last = DateTime(b.to.year, b.to.month, b.to.day - 1);
        return '${formatDate(b.from)} – ${formatDate(last)}';
    }
  }

  String get typeLabel => type == 1 ? 'Chi tiêu' : (type == 2 ? 'Thu nhập' : 'Tất cả');

  bool get isFiltered => wallet != null || type != 0;
}

class CategoryDelta {
  final String label;
  final int current;
  final int previous;

  const CategoryDelta({required this.label, required this.current, required this.previous});

  /// Phần trăm thay đổi; null nếu kỳ trước bằng 0 (không so sánh được).
  double? get percent => previous <= 0 ? null : ((current - previous) / previous) * 100;
}

class CompareResult {
  final String currentLabel;
  final String previousLabel;
  final int current;
  final int previous;
  final List<CategoryDelta> deltas;

  const CompareResult({
    required this.currentLabel,
    required this.previousLabel,
    required this.current,
    required this.previous,
    required this.deltas,
  });

  int get difference => current - previous;
  double? get percent => previous <= 0 ? null : (difference / previous) * 100;
}
