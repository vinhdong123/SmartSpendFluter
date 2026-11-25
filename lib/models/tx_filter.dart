import '../core/utils/formatters.dart';

/// Bộ lọc danh sách giao dịch (màn hình Lịch sử).
class TxFilter {
  final String query;
  final DateTime? from; // bao gồm
  final DateTime? to; // bao gồm
  final String? wallet;
  final String? category;
  final int type; // 0: tất cả, 1: chi tiêu, 2: thu nhập

  const TxFilter({
    this.query = '',
    this.from,
    this.to,
    this.wallet,
    this.category,
    this.type = 0,
  });

  static TxFilter thisMonth() {
    final now = DateTime.now();
    return TxFilter(from: DateTime(now.year, now.month, 1), to: DateTime(now.year, now.month + 1, 0));
  }

  TxFilter copyWith({
    String? query,
    DateTime? from,
    DateTime? to,
    bool clearRange = false,
    String? wallet,
    bool clearWallet = false,
    String? category,
    bool clearCategory = false,
    int? type,
  }) {
    return TxFilter(
      query: query ?? this.query,
      from: clearRange ? null : (from ?? this.from),
      to: clearRange ? null : (to ?? this.to),
      wallet: clearWallet ? null : (wallet ?? this.wallet),
      category: clearCategory ? null : (category ?? this.category),
      type: type ?? this.type,
    );
  }

  bool get hasRange => from != null && to != null;

  bool get isMonthRange {
    if (!hasRange) return false;
    return from!.day == 1 && to!.day == DateTime(from!.year, from!.month + 1, 0).day && from!.month == to!.month && from!.year == to!.year;
  }

  /// "Tháng 11" hoặc "01/11 – 15/11" hoặc "Tất cả thời gian".
  String get rangeLabel {
    if (!hasRange) return 'Tất cả thời gian';
    if (isMonthRange) return 'Tháng ${from!.month}';
    if (isSameDay(from!, to!)) return formatDayMonth(from!);
    return '${formatDayMonth(from!)} – ${formatDayMonth(to!)}';
  }

  bool get hasExtra => query.trim().isNotEmpty || wallet != null || category != null;
}
