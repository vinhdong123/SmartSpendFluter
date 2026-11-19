import 'package:flutter/services.dart';

/// 1234567 -> "1.234.567"
String formatNumber(num value) {
  final v = value.round().abs();
  return v.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
}

/// 1234567 -> "1.234.567đ" (số âm có dấu '-')
String formatVND(num value) {
  final sign = value < 0 ? '-' : '';
  return '$sign${formatNumber(value)}đ';
}

/// 2800000 -> "2,8tr", 45000 -> "45k"
String compactVND(num value) {
  final v = value.abs();
  if (v >= 1000000) {
    final s = (v / 1000000).toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', ',');
    return '${s}tr';
  }
  if (v >= 1000) {
    return '${(v / 1000).round()}k';
  }
  return v.round().toString();
}

String two(int n) => n.toString().padLeft(2, '0');

/// yyyy-MM-dd (định dạng lưu trong SQLite)
String dbDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';

/// dd/MM
String formatDayMonth(DateTime d) => '${two(d.day)}/${two(d.month)}';

/// dd/MM/yyyy
String formatDate(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "Hôm nay · 18/11", "Hôm qua · 17/11", "05/11", "05/11/2025"
String friendlyDate(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hôm nay · ${formatDayMonth(d)}';
  if (diff == 1) return 'Hôm qua · ${formatDayMonth(d)}';
  return d.year == now.year ? formatDayMonth(d) : formatDate(d);
}

/// Khoảng thời gian [from, to) cho tab Tuần(0) / Tháng(1) / Năm(2).
({DateTime from, DateTime to}) periodRange(int period, [DateTime? ref]) {
  final now = ref ?? DateTime.now();
  switch (period) {
    case 0:
      final from = DateTime(now.year, now.month, now.day - (now.weekday - 1));
      return (from: from, to: DateTime(from.year, from.month, from.day + 7));
    case 2:
      return (from: DateTime(now.year, 1, 1), to: DateTime(now.year + 1, 1, 1));
    default:
      return (from: DateTime(now.year, now.month, 1), to: DateTime(now.year, now.month + 1, 1));
  }
}

/// "1.234.567" -> 1234567
int parseAmount(String text) => int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

/// Tự thêm dấu chấm ngăn cách hàng nghìn khi nhập số tiền.
class ThousandsSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    if (digits.length > 13) return oldValue;
    final formatted = formatNumber(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
