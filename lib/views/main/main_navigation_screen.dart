import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../home/home_screen.dart';
import '../history/history_screen.dart';
import '../budget/budget_screen.dart';
import '../group_debt/group_debt_screen.dart';
import '../report/report_screen.dart';
import '../transaction/add_transaction_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final UserModel user;

  const MainNavigationScreen({super.key, required this.user});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  late Key _homeKey;
  late Key _historyKey;

  @override
  void initState() {
    super.initState();
    _homeKey = UniqueKey();
    _historyKey = UniqueKey();
  }

  void _openAddTransactionModal() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const AddTransactionScreen(),
        fullscreenDialog: true,
      ),
    );

    if (result == true) {
      setState(() {
        _homeKey = UniqueKey();
        _historyKey = UniqueKey();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeScreen(
        key: _homeKey,
        user: widget.user,
        onOpenAddTransaction: _openAddTransactionModal,
      ),
      HistoryScreen(key: _historyKey),
      const BudgetScreen(),
      const GroupDebtScreen(),
      const ReportScreen(),
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
