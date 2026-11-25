import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_settings.dart';
import '../widgets/common_widgets.dart';
import '../widgets/ui_kit.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  late bool _usd = AppSettings.useUsd;
  String _lang = AppSettings.language;

  Future<void> _save() async {
    await AppSettings.setCurrency(_usd);
    await AppSettings.setLanguage(_lang);
    if (!mounted) return;
    showSnack(context, 'Đã lưu tùy chọn');
    Navigator.of(context).pop(true);
  }

  Widget _option(String title, bool selected, VoidCallback? onTap, {IconData icon = Icons.attach_money_rounded, String? note}) {
    return ListRow(
      onTap: onTap,
      leading: IconBadge(icon: icon, size: 48),
      title: title,
      subtitle: note,
      trailing: selected
          ? const Text('Đang dùng', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary))
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: 'Tiền tệ & ngôn ngữ',
      bottom: BottomPrimary(text: 'Lưu', onPressed: _save),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Tiền tệ'),
          ListCard(
            children: [
              _option('VND – Đồng Việt Nam', !_usd, () => setState(() => _usd = false)),
              _option('USD – Đô la Mỹ', _usd, () => setState(() => _usd = true),
                  note: 'Hiển thị theo tỷ giá tham khảo 1 USD = ${AppSettings.usdRate.round()}đ'),
            ],
          ),
          const SectionLabel('Ngôn ngữ'),
          ListCard(
            children: [
              _option('Tiếng Việt', _lang == 'vi', () => setState(() => _lang = 'vi'), icon: Icons.language_rounded),
              _option('English', _lang == 'en', null, icon: Icons.language_rounded, note: 'Sắp có – hiện ứng dụng chỉ có Tiếng Việt'),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Số tiền bạn nhập luôn tính bằng VND. USD chỉ dùng để hiển thị quy đổi.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
