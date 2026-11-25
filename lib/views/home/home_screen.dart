import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/home_controller.dart';
import '../../models/notification_item.dart';
import '../../models/user_model.dart';
import '../budget/budget_alert_screen.dart';
import '../goals/savings_goals_screen.dart';
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';
import '../transaction/scan_receipt_screen.dart';
import '../transaction/add_transaction_screen.dart';
import '../transaction/transaction_detail_screen.dart';
import '../widgets/common_widgets.dart';
import '../widgets/ui_kit.dart';

class HomeScreen extends StatefulWidget {
  final UserModel user;
  final VoidCallback onOpenAddTransaction;
  final VoidCallback onOpenHistory;
  final ValueChanged<int> onOpenTab;
  final VoidCallback onDataChanged;

  const HomeScreen({
    super.key,
    required this.user,
    required this.onOpenAddTransaction,
    required this.onOpenHistory,
    required this.onOpenTab,
    required this.onDataChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HomeController _controller = HomeController();
  HomeData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _controller.load();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  Future<void> _push(Widget page) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => page));
    if (changed == true) {
      widget.onDataChanged();
    } else {
      _load();
    }
  }

  Future<void> _scan() async {
    final path = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const ScanReceiptScreen()));
    if (path == null || !mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddTransactionScreen(initialReceiptPath: path), fullscreenDialog: true),
    );
    if (saved == true) widget.onDataChanged();
  }

  void _openAlert(NotificationItem n) => _push(alertPageFor(n));

  String get _firstName {
    final parts = widget.user.fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.last.isEmpty ? 'bạn' : parts.last;
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading || data == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  children: [
                    _header(data),
                    const SizedBox(height: 16),
                    _balanceCard(data),
                    if (data.alerts.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _alertBanner(data.alerts.first),
                    ],
                    const SizedBox(height: 18),
                    _quickActions(),
                    if (data.goal != null) ...[
                      const SizedBox(height: 18),
                      _goalCard(data),
                    ],
                    SectionTitle(
                      'Giao dịch gần đây',
                      trailing: GestureDetector(
                        onTap: widget.onOpenHistory,
                        child: const Text('Xem tất cả',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                      ),
                    ),
                    if (data.recent.isEmpty)
                      const OutlineCard(
                        child: EmptyState(icon: Icons.receipt_long_outlined, message: 'Chưa có giao dịch nào'),
                      )
                    else
                      ListCard(
                        children: [
                          for (final t in data.recent)
                            TxRow(tx: t, onTap: () => _push(TransactionDetailScreen(transaction: t))),
                        ],
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _header(HomeData data) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Xin chào,', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              Text(_firstName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ],
          ),
        ),
        SquareIconButton(
          icon: Icons.notifications_none_rounded,
          dot: data.alerts.isNotEmpty,
          onTap: () => _push(const NotificationsScreen()),
        ),
        const SizedBox(width: 10),
        SquareIconButton(
          icon: Icons.tune_rounded,
          onTap: () => _push(SettingsScreen(user: widget.user)),
        ),
      ],
    );
  }

  Widget _balanceCard(HomeData data) {
    Widget chip(IconData icon, String label, int value) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                IconBadge(icon: icon, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(formatVND(value),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tổng số dư', style: TextStyle(fontSize: 14, color: Color(0xCCFFFFFF))),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(formatVND(data.balance),
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              chip(Icons.trending_up_rounded, 'Thu nhập', data.monthIncome),
              const SizedBox(width: 10),
              chip(Icons.account_balance_wallet_outlined, 'Chi tiêu', data.monthExpense),
            ],
          ),
        ],
      ),
    );
  }

  Widget _alertBanner(NotificationItem n) {
    final over = n.kind == NotifKind.budgetOver;
    String sub = n.subtitle;
    if (n.budget != null && !over) {
      sub = 'Còn ${formatVND((n.budget!.limit - n.budget!.spent).clamp(0, 1 << 40))} cho tháng này';
    }
    return InfoBanner(
      icon: Icons.warning_amber_rounded,
      tone: over ? BannerTone.danger : BannerTone.warning,
      title: n.title,
      subtitle: sub,
      onTap: () => _openAlert(n),
    );
  }

  Widget _quickActions() {
    Widget item(IconData icon, String label, VoidCallback onTap, {bool savings = false}) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                IconBadge(
                  icon: icon,
                  size: 56,
                  color: savings ? AppColors.savings600 : AppColors.primary,
                  background: savings ? AppColors.savings50 : AppColors.primary100,
                ),
                const SizedBox(height: 8),
                Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ],
            ),
          ),
        );
    return Row(
      children: [
        item(Icons.add_rounded, 'Thêm', widget.onOpenAddTransaction),
        item(Icons.photo_camera_outlined, 'Chụp hóa đơn', _scan),
        item(Icons.track_changes_rounded, 'Xem mục tiêu', () => _push(const SavingsGoalsScreen()), savings: true),
        item(Icons.pie_chart_outline_rounded, 'Báo cáo', () => widget.onOpenTab(4)),
      ],
    );
  }

  Widget _goalCard(HomeData data) {
    final g = data.goal!;
    return OutlineCard(
      color: AppColors.savings50,
      onTap: () => _push(const SavingsGoalsScreen()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.track_changes_rounded, color: AppColors.savings600, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(g.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
              Text('${g.percent}%',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.savings600)),
            ],
          ),
          const SizedBox(height: 12),
          AppProgressBar(value: g.ratio, color: AppColors.savings600, background: AppColors.primary100),
          const SizedBox(height: 8),
          Text('${formatVND(g.saved)} / ${formatVND(g.target)}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
