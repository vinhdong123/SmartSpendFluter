import '../services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../services/sqlite_database_service.dart';

class TransactionRepository {
  TransactionRepository._();
  static final TransactionRepository instance = TransactionRepository._();

  final SQLiteDatabaseService _sqlite = SQLiteDatabaseService.instance;

  /// Dữ liệu mẫu chỉ dành cho tài khoản demo (ngày tính theo hôm nay).
  List<TransactionModel> _demoTransactions() {
    final now = DateTime.now();
    DateTime at(int daysAgo, int h, int m) => DateTime(now.year, now.month, now.day - daysAgo, h, m);
    return [
      TransactionModel(id: 'tx_demo_1', title: 'Ăn trưa cơm tấm', amount: 45000, isExpense: true, category: 'Ăn uống', wallet: 'Tiền mặt', date: at(0, 12, 10), note: 'Ăn trưa cơm tấm'),
      TransactionModel(id: 'tx_demo_2', title: 'Cà phê', amount: 32000, isExpense: true, category: 'Ăn uống', wallet: 'Tiền mặt', date: at(0, 8, 30), note: 'Cà phê sáng'),
      TransactionModel(id: 'tx_demo_3', title: 'Grab đi học', amount: 68000, isExpense: true, category: 'Di chuyển', wallet: 'Ví MoMo', date: at(0, 7, 15), note: 'Grab đi học'),
      TransactionModel(id: 'tx_demo_4', title: 'Lương làm thêm', amount: 8000000, isExpense: false, category: 'Thu nhập', wallet: 'Ngân hàng', date: at(1, 15, 0), note: 'Lương làm thêm'),
      TransactionModel(id: 'tx_demo_5', title: 'Tiền điện', amount: 320000, isExpense: true, category: 'Hóa đơn', wallet: 'Ngân hàng', date: at(1, 10, 30), note: 'Hóa đơn tiền điện'),
    ];
  }

  /// Chỉ nạp dữ liệu mẫu đúng một lần cho tài khoản demo.
  Future<void> ensureDemoData() async {
    if (!_sqlite.isDemoUser) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'demo_seeded_${_sqlite.uid}';
    if (prefs.getBool(key) ?? false) return;
    for (final tx in _demoTransactions()) {
      await _sqlite.insertTransaction(tx);
    }
    await prefs.setBool(key, true);
  }

  Future<List<TransactionModel>> getTransactions({int? limit}) async {
    await ensureDemoData();
    return _sqlite.getAllTransactions(limit: limit);
  }

  Future<void> addTransaction(TransactionModel transaction) => markSynced(_sqlite.insertTransaction(transaction));

  Future<void> updateTransaction(TransactionModel transaction) => markSynced(_sqlite.updateTransaction(transaction));

  Future<void> deleteTransaction(String id) => markSynced(_sqlite.deleteTransaction(id));

  double calculateTotalIncome(List<TransactionModel> list) {
    return list.where((t) => !t.isExpense).fold(0.0, (sum, item) => sum + item.amount);
  }

  double calculateTotalExpense(List<TransactionModel> list) {
    return list.where((t) => t.isExpense).fold(0.0, (sum, item) => sum + item.amount);
  }
}
