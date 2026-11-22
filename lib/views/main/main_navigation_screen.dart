import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../home/home_screen.dart';
import '../history/history_screen.dart';
import '../budget/budget_screen.dart';
import '../group_debt/group_debt_screen.dart';
import '../report/report_screen.dart';
import '../transaction/add_transaction_screen.dart';
import '../../services/sqlite_database_service.dart';
import '../../services/sync_service.dart';

class MainNavigationScreen extends StatefulWidget {
  final UserModel user;

  const MainNavigationScreen({super.key, required this.user});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  Key _dataKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    SQLiteDatabaseService.instance.setCurrentUser(widget.user);
    SyncService.instance.revision.addListener(_onSynced);
  }

  void _openAddTransactionModal() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const AddTransactionScreen(),
        fullscreenDialog: true,
      ),
    );

    if (result == true) {
      _refreshAll();
    }
  }

  void _refreshAll() => setState(() => _dataKey = UniqueKey());

  void _onSynced() {
    if (mounted) _refreshAll();
  }

  @override
  void dispose() {
    SyncService.instance.revision.removeListener(_onSynced);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeScreen(
        key: _dataKey,
        user: widget.user,
        onOpenAddTransaction: _openAddTransactionModal,
        onOpenHistory: () => setState(() => _currentIndex = 1),
      ),
      HistoryScreen(key: _dataKey, onChanged: () => _dataKey = UniqueKey()),
      BudgetScreen(key: _dataKey),
      GroupDebtScreen(key: _dataKey),
      ReportScreen(key: _dataKey),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTransactionModal,
        backgroundColor: AppColors.primaryTeal,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primaryTeal,
          unselectedItemColor: AppColors.textSecondary,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Trang chủ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.format_list_bulleted_rounded),
              activeIcon: Icon(Icons.format_list_bulleted_rounded),
              label: 'Lịch sử',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Ngân sách',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline_rounded),
              activeIcon: Icon(Icons.people_rounded),
              label: 'Nhóm & Nợ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart_outline_rounded),
              activeIcon: Icon(Icons.pie_chart_rounded),
              label: 'Báo cáo',
            ),
          ],
        ),
      ),
    );
  }
}
