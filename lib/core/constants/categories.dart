import 'package:material_ui/material_ui.dart';

class CategoryInfo {
  final String label;
  final String code;
  final IconData icon;
  const CategoryInfo(this.label, this.code, this.icon);
}

abstract final class Categories {
  static const List<CategoryInfo> expense = [
    CategoryInfo('Ăn uống', 'an_uong', Icons.local_cafe_outlined),
    CategoryInfo('Di chuyển', 'di_chuyen', Icons.directions_car_outlined),
    CategoryInfo('Mua sắm', 'mua_sam', Icons.shopping_bag_outlined),
    CategoryInfo('Hóa đơn', 'hoa_don', Icons.bolt_outlined),
    CategoryInfo('Giải trí', 'giai_tri', Icons.sports_esports_outlined),
    CategoryInfo('Học tập', 'hoc_tap', Icons.school_outlined),
    CategoryInfo('Sức khỏe', 'suc_khoe', Icons.favorite_border_rounded),
    CategoryInfo('Khác', 'khac', Icons.more_horiz_rounded),
  ];

  static const List<CategoryInfo> income = [
    CategoryInfo('Thu nhập', 'thu_nhap', Icons.attach_money_rounded),
    CategoryInfo('Lương', 'luong', Icons.payments_outlined),
    CategoryInfo('Thưởng', 'thuong', Icons.card_giftcard_outlined),
    CategoryInfo('Làm thêm', 'lam_them', Icons.work_outline_rounded),
    CategoryInfo('Đầu tư', 'dau_tu', Icons.trending_up_rounded),
    CategoryInfo('Khác', 'khac', Icons.more_horiz_rounded),
  ];

  /// Danh mục tự sinh khi ghi nhận khoản nợ.
  static const List<CategoryInfo> system = [
    CategoryInfo('Vay nợ', 'vay_no', Icons.south_west_rounded),
    CategoryInfo('Cho vay', 'cho_vay', Icons.north_east_rounded),
    CategoryInfo('Trả nợ', 'tra_no', Icons.north_east_rounded),
    CategoryInfo('Thu nợ', 'thu_no', Icons.south_west_rounded),
  ];

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
}
