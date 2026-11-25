import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CategoryInfo {
  final String label;
  final String code;
  final String iconKey;
  const CategoryInfo(this.label, this.code, this.iconKey);

  IconData get icon => CategoryIcons.byKey(iconKey);
}

/// Bộ biểu tượng người dùng có thể chọn cho danh mục.
abstract final class CategoryIcons {
  static const Map<String, IconData> all = {
    'food': Icons.restaurant_rounded,
    'car': Icons.directions_car_outlined,
    'bag': Icons.shopping_bag_outlined,
    'bolt': Icons.bolt_rounded,
    'game': Icons.sports_esports_outlined,
    'school': Icons.chat_bubble_outline_rounded,
    'heart': Icons.favorite_border_rounded,
    'money': Icons.attach_money_rounded,
    'pet': Icons.pets_rounded,
    'home': Icons.home_outlined,
    'phone': Icons.phone_android_rounded,
    'coffee': Icons.local_cafe_outlined,
    'flight': Icons.flight_outlined,
    'gift': Icons.card_giftcard_outlined,
    'work': Icons.work_outline_rounded,
    'trend': Icons.trending_up_rounded,
    'pay': Icons.payments_outlined,
    'in': Icons.south_west_rounded,
    'out': Icons.north_east_rounded,
    'more': Icons.more_horiz_rounded,
  };

  /// Các biểu tượng hiển thị trong màn hình chọn (không gồm biểu tượng hệ thống).
  static const List<String> pickable = [
    'food', 'car', 'bag', 'bolt', 'game', 'school', 'heart', 'money',
    'pet', 'home', 'phone', 'coffee', 'flight', 'gift', 'work', 'trend',
  ];

  static IconData byKey(String key) => all[key] ?? Icons.more_horiz_rounded;
}

/// Danh mục thu / chi. Danh sách mặc định có thể được người dùng thêm, sửa, xóa
/// (lưu theo từng tài khoản trong SharedPreferences).
abstract final class Categories {
  static const List<CategoryInfo> _defaultExpense = [
    CategoryInfo('Ăn uống', 'an_uong', 'food'),
    CategoryInfo('Di chuyển', 'di_chuyen', 'car'),
    CategoryInfo('Mua sắm', 'mua_sam', 'bag'),
    CategoryInfo('Hóa đơn', 'hoa_don', 'bolt'),
    CategoryInfo('Giải trí', 'giai_tri', 'game'),
    CategoryInfo('Học tập', 'hoc_tap', 'school'),
    CategoryInfo('Sức khỏe', 'suc_khoe', 'heart'),
    CategoryInfo('Khác', 'khac', 'more'),
  ];

  static const List<CategoryInfo> _defaultIncome = [
    CategoryInfo('Thu nhập', 'thu_nhap', 'money'),
    CategoryInfo('Lương', 'luong', 'pay'),
    CategoryInfo('Thưởng', 'thuong', 'gift'),
    CategoryInfo('Làm thêm', 'lam_them', 'work'),
    CategoryInfo('Đầu tư', 'dau_tu', 'trend'),
    CategoryInfo('Khác', 'khac', 'more'),
  ];

  /// Danh mục tự sinh khi ghi nhận khoản nợ.
  static const List<CategoryInfo> system = [
    CategoryInfo('Vay nợ', 'vay_no', 'in'),
    CategoryInfo('Cho vay', 'cho_vay', 'out'),
    CategoryInfo('Trả nợ', 'tra_no', 'out'),
    CategoryInfo('Thu nợ', 'thu_no', 'in'),
  ];

  static List<CategoryInfo> expense = List.of(_defaultExpense);
  static List<CategoryInfo> income = List.of(_defaultIncome);

  static String _key = 'categories_v1_default';

  /// Nạp danh mục của tài khoản [uid]. Gọi sau khi đăng nhập.
  static Future<void> load(String uid) async {
    _key = 'categories_v1_$uid';
    expense = List.of(_defaultExpense);
    income = List.of(_defaultIncome);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      List<CategoryInfo> parse(Object? list) => [
            for (final e in (list as List? ?? const []))
              CategoryInfo(
                (e as Map)['l'] as String,
                e['c'] as String,
                (e['i'] as String?) ?? 'more',
              ),
          ];
      final ex = parse(map['expense']);
      final inc = parse(map['income']);
      if (ex.isNotEmpty) expense = ex;
      if (inc.isNotEmpty) income = inc;
    } catch (_) {
      // Dữ liệu hỏng -> dùng mặc định.
    }
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, String>> enc(List<CategoryInfo> l) => [
          for (final c in l) {'l': c.label, 'c': c.code, 'i': c.iconKey},
        ];
    await prefs.setString(_key, jsonEncode({'expense': enc(expense), 'income': enc(income)}));
  }

  static List<CategoryInfo> get all => [...expense, ...income, ...system];

  static CategoryInfo? _find(bool Function(CategoryInfo) test) {
    for (final c in all) {
      if (test(c)) return c;
    }
    return null;
  }

  static String codeOf(String label) =>
      _find((c) => c.label.toLowerCase() == label.trim().toLowerCase())?.code ?? 'khac';

  static String labelOf(String code) => _find((c) => c.code == code)?.label ?? code;

  static IconData iconOf(String label) =>
      _find((c) => c.label.toLowerCase() == label.trim().toLowerCase())?.icon ?? Icons.more_horiz_rounded;

  /// Tất cả nhãn danh mục (không trùng) dùng cho bộ lọc.
  static List<String> get allLabels {
    final seen = <String>{};
    return [for (final c in all) if (seen.add(c.label)) c.label];
  }

  static bool labelExists(String label, {String? exceptCode}) {
    final l = label.trim().toLowerCase();
    return all.any((c) => c.label.toLowerCase() == l && c.code != exceptCode);
  }

  static Future<CategoryInfo> add({required String label, required bool isIncome, required String iconKey}) async {
    final info = CategoryInfo(label.trim(), 'c_${DateTime.now().microsecondsSinceEpoch}', iconKey);
    final list = isIncome ? income : expense;
    // Chèn trước mục "Khác" để "Khác" luôn nằm cuối.
    final idx = list.indexWhere((c) => c.code == 'khac');
    if (idx < 0) {
      list.add(info);
    } else {
      list.insert(idx, info);
    }
    await _save();
    return info;
  }

  /// Đổi tên / biểu tượng. Trả về nhãn cũ.
  static Future<String> update({required String code, required String label, required String iconKey}) async {
    var old = label;
    for (final list in [expense, income]) {
      for (var i = 0; i < list.length; i++) {
        if (list[i].code == code) {
          old = list[i].label;
          list[i] = CategoryInfo(label.trim(), code, iconKey);
        }
      }
    }
    await _save();
    return old;
  }

  static Future<void> remove(String code) async {
    expense.removeWhere((c) => c.code == code);
    income.removeWhere((c) => c.code == code);
    await _save();
  }
}
