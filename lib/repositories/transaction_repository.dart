import '../models/transaction_model.dart';
import '../services/sqlite_database_service.dart';

class TransactionRepository {
  TransactionRepository._();
  static final TransactionRepository instance = TransactionRepository._();

  final SQLiteDatabaseService _sqlite = SQLiteDatabaseService.instance;

  final List<TransactionModel> _defaultSampleTransactions = [
    TransactionModel(
      id: 'tx_1',
      title: 'Ăn trưa cơm tấm',
      amount: 45000,
      isExpense: true,
      category: 'Ăn uống',
      wallet: 'Tiền mặt',
      date: DateTime(2026, 11, 4, 12, 10),
      note: 'Ăn trưa cơm tấm',
    ),
    TransactionModel(
      id: 'tx_2',
      title: 'Cà phê',
      amount: 32000,
      isExpense: true,
      category: 'Ăn uống',
      wallet: 'Tiền mặt',
      date: DateTime(2026, 11, 4, 8, 30),
      note: 'Cà phê sáng',
    ),
    TransactionModel(
      id: 'tx_3',
      title: 'Grab đi học',
      amount: 68000,
      isExpense: true,
      category: 'Di chuyển',
      wallet: 'Ví MoMo',
      date: DateTime(2026, 11, 4, 7, 15),
      note: 'Grab đi học',
    ),
    TransactionModel(
      id: 'tx_4',
      title: 'Lương làm thêm',
      amount: 8000000,
      isExpense: false,
      category: 'Thu nhập',
      wallet: 'Ngân hàng',
      date: DateTime(2026, 11, 3, 15, 0),
      note: 'Lương tháng 11',
    ),
    TransactionModel(
      id: 'tx_5',
      title: 'Tiền điện',
      amount: 320000,
      isExpense: true,
      category: 'Hóa đơn',
      wallet: 'Ngân hàng',
      date: DateTime(2026, 11, 3, 10, 30),
      note: 'Hóa đơn tiền điện',
    ),
  ];

  /// Retrieve all transactions from SQLite database
  Future<List<TransactionModel>> getTransactions() async {
    final list = await _sqlite.getAllTransactions();
    if (list.isEmpty) {
      // Populate initial sample transactions if database is empty
      for (final tx in _defaultSampleTransactions) {
        await _sqlite.insertTransaction(tx);
      }
      return await _sqlite.getAllTransactions();
    }
    return list;
  }

  /// Add new transaction to SQLite database
  Future<void> addTransaction(TransactionModel transaction) async {
    await _sqlite.insertTransaction(transaction);
  }

  /// Delete transaction from SQLite database
  Future<void> deleteTransaction(String id) async {
    await _sqlite.deleteTransaction(id);
  }

  double calculateTotalIncome(List<TransactionModel> list) {
    return list
        .where((t) => !t.isExpense)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double calculateTotalExpense(List<TransactionModel> list) {
    return list
        .where((t) => t.isExpense)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double calculateBalance(List<TransactionModel> list) {
    return 12450000.0 + calculateTotalIncome(list) - calculateTotalExpense(list);
  }
}
