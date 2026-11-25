import 'package:material_ui/material_ui.dart';

/// Bảng màu lấy từ mockup: SmartSpend/Colors.
abstract final class AppColors {
  // Brand
  static const Color primary = Color(0xFF0F766E);
  static const Color primary100 = Color(0xFFDFF3ED);
  static const Color primary50 = Color(0xFFF0F9F6);
  static const Color accent = Color(0xFFD99A24);

  // Giao dịch
  static const Color income = Color(0xFF187552);
  static const Color expense = Color(0xFFB54747);
  static const Color income50 = Color(0xFFE7F5ED);
  static const Color expense50 = Color(0xFFFCEDEE);

  // Cảnh báo / tiết kiệm
  static const Color warning50 = Color(0xFFFFF4D6);
  static const Color warning700 = Color(0xFF946200);
  static const Color savings600 = Color(0xFF2463A6);
  static const Color savings50 = Color(0xFFEAF2FF);

  // Nền & chữ
  static const Color bg = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF17312D);
  static const Color textSecondary = Color(0xFF526B66); // text/muted
  static const Color textHint = Color(0xFF8FA39E);
  static const Color border = Color(0xFFDCE8E3);

  // Tên cũ (giữ để code cũ vẫn biên dịch)
  static const Color primaryTeal = primary;
  static const Color darkTeal = Color(0xFF0B5F58);
  static const Color lightMint = primary100;
  static const Color mintContainer = primary100;
  static const Color backgroundLight = bg;
  static const Color surfaceLight = bg;
  static const Color borderFocused = primary;
  static const Color error = expense;
  static const Color success = income;
}
