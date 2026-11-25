import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_settings.dart';
import '../../services/sync_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/custom_button.dart';
import '../widgets/ui_kit.dart';

class BackupSyncScreen extends StatefulWidget {
  const BackupSyncScreen({super.key});

  @override
  State<BackupSyncScreen> createState() => _BackupSyncScreenState();
}

class _BackupSyncScreenState extends State<BackupSyncScreen> {
  final SyncService _sync = SyncService.instance;
  bool _busy = false;
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    _refreshPending();
  }

  Future<void> _refreshPending() async {
    final p = await _sync.hasPendingChanges();
    if (mounted) setState(() => _pending = p);
  }

  Future<void> _backupNow() async {
    setState(() => _busy = true);
    final error = await _sync.syncNow();
    await _refreshPending();
    if (!mounted) return;
    setState(() => _busy = false);
    showSnack(context, error ?? 'Đã sao lưu lên đám mây', isError: error != null);
  }

  Future<void> _restore() async {
    final ok = await confirmDialog(
      context,
      title: 'Khôi phục từ đám mây?',
      message: 'Dữ liệu cá nhân trên máy sẽ được thay bằng bản đã sao lưu. Thay đổi chưa sao lưu có thể bị mất.',
      confirmLabel: 'Khôi phục',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final error = await _sync.restoreFromCloud();
    await _refreshPending();
    if (!mounted) return;
    setState(() => _busy = false);
    showSnack(context, error ?? 'Đã khôi phục dữ liệu từ đám mây', isError: error != null);
    if (error == null) Navigator.of(context).pop(true);
  }

  Widget _toggle(String title, String? subtitle, bool value, ValueChanged<bool> onChanged) {
    return OutlineCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: value,
        activeThumbColor: AppColors.primary,
        onChanged: onChanged,
        title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: subtitle == null ? null : Text(subtitle, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _sync.isActive;
    return SubPage(
      title: 'Sao lưu & đồng bộ',
      child: ValueListenableBuilder<String>(
        valueListenable: _sync.status,
        builder: (context, status, _) {
          final hasError = status.startsWith('Lỗi');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoBanner(
                icon: active ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                tone: !active ? BannerTone.warning : (hasError ? BannerTone.danger : BannerTone.success),
                title: !active ? 'Chưa bật đồng bộ' : (hasError ? 'Đồng bộ gặp lỗi' : (_pending ? 'Có thay đổi chưa sao lưu' : 'Đã đồng bộ')),
                subtitle: !active ? 'Đăng nhập bằng tài khoản Firebase (có mạng) để sao lưu' : status,
              ),
              const SizedBox(height: 12),
              _toggle('Đồng bộ tự động', 'Khi có kết nối mạng', AppSettings.autoSync, (v) async {
                await AppSettings.setAutoSync(v);
                if (mounted) setState(() {});
              }),
              const SizedBox(height: 12),
              _toggle('Chỉ đồng bộ khi dùng Wi-Fi', null, AppSettings.wifiOnly, (v) async {
                await AppSettings.setWifiOnly(v);
                if (mounted) setState(() {});
              }),
              const SizedBox(height: 16),
              PrimaryButton(text: 'Sao lưu ngay', onPressed: active && !_busy ? _backupNow : null, isLoading: _busy),
              const SizedBox(height: 10),
              TonalButton(text: 'Khôi phục từ đám mây', icon: Icons.download_rounded, onPressed: active && !_busy ? _restore : null),
              const SizedBox(height: 14),
              const Text(
                'Dữ liệu luôn lưu trên máy trước (SQLite). Đồng bộ lên Firebase khi có mạng.',
                style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
              ),
            ],
          );
        },
      ),
    );
  }
}
