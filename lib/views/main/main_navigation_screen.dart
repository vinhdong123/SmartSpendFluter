import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/categories.dart';
import '../../models/user_model.dart';
import '../home/home_screen.dart';
import '../history/history_screen.dart';
import '../budget/budget_screen.dart';
import '../group_debt/group_debt_screen.dart';
import '../report/report_screen.dart';
import '../transaction/add_transaction_screen.dart';
import '../../services/extra_queries.dart';
import '../../services/sqlite_database_service.dart';
import '../../services/sync_service.dart';

class MainNavigationScreen extends StatefulWidget {
  final UserModel user;

  const MainNavigationScreen({super.key, required this.user});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  Key _dataKey = UniqueKey();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SQLiteDatabaseService.instance.setCurrentUser(widget.user);
    SyncService.instance.revision.addListener(_onSynced);
    _bootstrap();
  }

  /// Nạp danh mục của người dùng và tạo các giao dịch định kỳ đã đến hạn.
  Future<void> _bootstrap() async {
    await Categories.load(widget.user.uid);
    await _processRecurring(refresh: false);
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _processRecurring({bool refresh = true}) async {
    try {
      final created = await SQLiteDatabaseService.instance.processRecurring();
      if (created > 0 && refresh && mounted) _refreshAll();
    } catch (_) {
      // Không chặn ứng dụng nếu việc tạo giao dịch định kỳ lỗi.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _ready) _processRecurring();
  }

  Future<void> _openAddTransaction() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddTransactionScreen(), fullscreenDialog: true),
    );
    if (result == true) _refreshAll();
  }

  void _refreshAll() => setState(() => _dataKey = UniqueKey());

  void _onSynced() {
    if (mounted) _refreshAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SyncService.instance.revision.removeListener(_onSynced);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    final List<Widget> pages = [
      HomeScreen(
        key: _dataKey,
        user: widget.user,
        onOpenAddTransaction: _openAddTransaction,
        onOpenHistory: () => setState(() => _currentIndex = 1),
        onOpenTab: (i) => setState(() => _currentIndex = i),
        onDataChanged: _refreshAll,
      ),
      HistoryScreen(key: _dataKey, onChanged: _refreshAll),
      BudgetScreen(key: _dataKey, onChanged: _refreshAll),
      GroupDebtScreen(key: _dataKey),
      ReportScreen(key: _dataKey),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      // Nút "+" nổi chỉ có ở Trang chủ và Lịch sử (theo luồng thiết kế).
      floatingActionButton: _currentIndex <= 1
          ? FloatingActionButton(
              onPressed: _openAddTransaction,
              backgroundColor: AppColors.primary,
              elevation: 3,
              shape: const CircleBorder(),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: 'Trang chủ'),
            BottomNavigationBarItem(icon: Icon(Icons.format_list_bulleted_rounded), label: 'Lịch sử'),
            BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_outlined),
                activeIcon: Icon(Icons.account_balance_wallet_rounded),
                label: 'Ngân sách'),
            BottomNavigationBarItem(
                icon: Icon(Icons.people_outline_rounded), activeIcon: Icon(Icons.people_rounded), label: 'Nhóm & Nợ'),
            BottomNavigationBarItem(
                icon: Icon(Icons.pie_chart_outline_rounded), activeIcon: Icon(Icons.pie_chart_rounded), label: 'Báo cáo'),
          ],
        ),
      ),
    );
  }
}
