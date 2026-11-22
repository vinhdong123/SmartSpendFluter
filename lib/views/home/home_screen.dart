import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/home_controller.dart';
import '../../models/transaction_model.dart';
import '../../models/user_model.dart';
import '../../services/sync_service.dart';
import '../auth/login_screen.dart';
import '../goals/savings_goals_screen.dart';
import '../wallet/wallets_screen.dart';
import '../widgets/common_widgets.dart';

class HomeScreen extends StatefulWidget {
  final UserModel user;
  final VoidCallback? onOpenAddTransaction;
  final VoidCallback? onOpenHistory;

  const HomeScreen({
    super.key,
    required this.user,
    this.onOpenAddTransaction,
    this.onOpenHistory,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HomeController _controller = HomeController();

  HomeData? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await _controller.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showSnack(context, 'Không tải được dữ liệu: $e', isError: true);
    }
  }

  void _openGoals() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SavingsGoalsScreen())).then((_) => _loadData());
  }

  void _showNotifications() {
    final alerts = _data?.alerts ?? const <String>[];
    showAppSheet<void>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHeader('Thông báo'),
          if (alerts.isEmpty)
            const EmptyState(
              icon: Icons.notifications_none_rounded,
              message: 'Chưa có cảnh báo nào.\nNgân sách và khoản nợ của bạn đang ổn.',
            )
          else
            for (final a in alerts)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined, color: Color(0xFFD97706), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        a,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  void _showSettings() {
    showAppSheet<void>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHeader('Tài khoản'),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.lightMint,
                child: Text(
                  widget.user.initials,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryTeal),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.fullName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      widget.user.email,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primaryTeal),
            title: const Text('Ví của tôi'),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
            onTap: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletsScreen())).then((_) => _loadData());
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.track_changes_outlined, color: AppColors.primaryTeal),
            title: const Text('Mục tiêu tiết kiệm'),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
            onTap: () {
              Navigator.of(ctx).pop();
              _openGoals();
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cloud_sync_outlined, color: AppColors.primaryTeal),
            title: const Text('Đồng bộ Firebase'),
            subtitle: ValueListenableBuilder<String>(
              valueListenable: SyncService.instance.status,
              builder: (_, value, __) => Text(value, style: const TextStyle(fontSize: 12)),
            ),
            onTap: () async {
              Navigator.of(ctx).pop();
              showSnack(context, 'Đang đồng bộ...');
              final error = await SyncService.instance.syncNow();
              if (!mounted) return;
              showSnack(context, error ?? 'Đồng bộ thành công', isError: error != null);
              _loadData();
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            title: const Text('Đăng xuất', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.of(ctx).pop();
              _logout();
            },
          ),
        ],
      ),
    );
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
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final now = DateTime.now();
    final alerts = data?.alerts ?? const <String>[];

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primaryTeal,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Xin chào, ${widget.user.fullName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tháng ${now.month}, ${now.year}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.tune_rounded, color: AppColors.textPrimary),
                          onPressed: _showSettings,
                        ),
                        Stack(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary),
                              onPressed: _showNotifications,
                            ),
                            if (alerts.isNotEmpty)
                              Positioned(
                                right: 10,
                                top: 10,
                                child: Container(
                                  width: 9,
                                  height: 9,
                                  decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Dark Teal Total Balance Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryTeal.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tổng số dư',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        formatVND(data?.balance ?? 0),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _buildSummaryColumn('Thu nhập tháng này', data?.monthIncome ?? 0)),
                          Expanded(child: _buildSummaryColumn('Chi tiêu tháng này', data?.monthExpense ?? 0)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Budget / debt alert banner
                if (alerts.isNotEmpty) ...[
                  InkWell(
                    onTap: _showNotifications,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFDE68A), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_active_outlined, color: Color(0xFFD97706), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              alerts.length > 1 ? '${alerts.first} (+${alerts.length - 1} cảnh báo)' : alerts.first,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Quick Actions (3 cards)
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionCard(
                        icon: Icons.add_circle_outline_rounded,
                        label: 'Thêm nhanh',
                        onTap: widget.onOpenAddTransaction,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickActionCard(
                        icon: Icons.receipt_long_outlined,
                        label: 'Quét hóa đơn',
                        onTap: () => showSnack(context, 'Quét hóa đơn cần tích hợp camera / OCR — sẽ bổ sung ở phiên bản sau.'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickActionCard(
                        icon: Icons.track_changes_outlined,
                        label: 'Mục tiêu',
                        onTap: _openGoals,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Recent Transactions Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Giao dịch gần đây',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (widget.onOpenHistory != null)
                      TextButton(
                        onPressed: widget.onOpenHistory,
                        child: const Text(
                          'Xem tất cả',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryTeal),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(child: CircularProgressIndicator(color: AppColors.primaryTeal)),
                        )
                      : (data == null || data.recent.isEmpty)
                          ? EmptyState(
                              icon: Icons.receipt_long_outlined,
                              message: 'Chưa có giao dịch nào.\nGhi lại khoản thu chi đầu tiên của bạn!',
                              actionLabel: 'Thêm giao dịch',
                              onAction: widget.onOpenAddTransaction,
                            )
                          : Column(
                              children: [
                                for (int i = 0; i < data.recent.length; i++) ...[
                                  _buildTransactionTile(data.recent[i]),
                                  if (i < data.recent.length - 1)
                                    const Divider(height: 1, indent: 64, color: AppColors.border),
                                ],
                              ],
                            ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryColumn(String label, int value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.75)),
        ),
        const SizedBox(height: 4),
        Text(
          formatVND(value),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.lightMint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primaryTeal, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(TransactionModel tx) {
    final amountColor = tx.isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final time = '${two(tx.date.hour)}:${two(tx.date.minute)}';
    final when = isSameDay(tx.date, DateTime.now()) ? time : '${formatDayMonth(tx.date)} · $time';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.lightMint,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(tx.categoryIcon, color: AppColors.primaryTeal, size: 22),
      ),
      title: Text(
        tx.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      ),
      subtitle: Text(
        '${tx.category} · $when',
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
      trailing: Text(
        tx.formattedAmount,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: amountColor),
      ),
    );
  }
}
