import 'package:shared_preferences/shared_preferences.dart';

/// Tùy chọn ứng dụng lưu trên máy (không phụ thuộc tài khoản).
abstract final class AppSettings {
  static bool useUsd = false;
  static String language = 'vi';
  static bool autoSync = true;
  static bool wifiOnly = false;
  static int billRemindDays = 3;

  /// Tỷ giá tham khảo dùng để hiển thị khi chọn USD.
  static const double usdRate = 25000;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    useUsd = (p.getString('pref_currency') ?? 'VND') == 'USD';
    language = p.getString('pref_language') ?? 'vi';
    autoSync = p.getBool('pref_auto_sync') ?? true;
    wifiOnly = p.getBool('pref_wifi_only') ?? false;
    billRemindDays = p.getInt('pref_bill_remind_days') ?? 3;
  }

  static Future<void> setCurrency(bool usd) async {
    useUsd = usd;
    final p = await SharedPreferences.getInstance();
    await p.setString('pref_currency', usd ? 'USD' : 'VND');
  }

  static Future<void> setLanguage(String code) async {
    language = code;
    final p = await SharedPreferences.getInstance();
    await p.setString('pref_language', code);
  }

  static Future<void> setAutoSync(bool v) async {
    autoSync = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool('pref_auto_sync', v);
  }

  static Future<void> setWifiOnly(bool v) async {
    wifiOnly = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool('pref_wifi_only', v);
  }

  static Future<void> setBillRemindDays(int v) async {
    billRemindDays = v;
    final p = await SharedPreferences.getInstance();
    await p.setInt('pref_bill_remind_days', v);
  }
}
