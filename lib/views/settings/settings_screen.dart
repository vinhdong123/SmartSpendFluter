import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../models/user_model.dart';
import '../../services/sync_service.dart';
import '../auth/login_screen.dart';
import '../wallet/wallets_screen.dart';
import '../widgets/common_widgets.dart';
import '../widgets/ui_kit.dart';
import 'backup_sync_screen.dart';
import 'bill_reminders_screen.dart';
import 'categories_screen.dart';
import 'change_password_screen.dart';
import 'preferences_screen.dart';
import 'recurring_screen.dart';

/// Cài đặt. Pop(true) nếu có dữ liệu thay đổi cần làm mới.
class SettingsScreen extends StatefulWidget {
  final UserModel user;
  const SettingsScreen({super.key, required this.user});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _changed = false;

  Future<void> _push(Widget page) async {
    final r = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => page));
    if (r == true) _changed = true;
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    final ok = await confirmDialog(
      context,
      title: 'Đăng xuất',
      message: 'Bạn có chắc muốn đăng xuất khỏi SmartSpend?',
      confirmLabel: 'Đăng xuất',
      destructive: true,
    );
    if (!ok || !mounted) return;
    SyncService.instance.stop();
    await AuthController().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  Widget _item(IconData icon, String title, Widget page) => ListRow(
        onTap: () => _push(page),
        leading: IconBadge(icon: icon, size: 48),
        title: title,
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: SubPage(
        title: 'Cài đặt',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlineCard(
              child: Row(
                children: [
                  const IconBadge(icon: Icons.person_outline_rounded, size: 60),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.user.fullName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        Text(widget.user.email,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SectionLabel('Quản lý dữ liệu'),
            ListCard(
              children: [
                _item(Icons.account_balance_wallet_outlined, 'Quản lý ví', const WalletsScreen()),
                _item(Icons.sell_outlined, 'Quản lý danh mục', const CategoriesScreen()),
                _item(Icons.autorenew_rounded, 'Giao dịch định kỳ', const RecurringScreen()),
                _item(Icons.notifications_none_rounded, 'Nhắc nhở hóa đơn', const BillRemindersScreen()),
              ],
            ),
            const SectionLabel('Ứng dụng'),
            ListCard(
              children: [
                _item(Icons.cloud_outlined, 'Sao lưu & đồng bộ', const BackupSyncScreen()),
                _item(Icons.language_rounded, 'Tiền tệ & ngôn ngữ', const PreferencesScreen()),
                _item(Icons.lock_outline_rounded, 'Đổi mật khẩu', ChangePasswordScreen(email: widget.user.email)),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.expense50,
                  foregroundColor: AppColors.expense,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
