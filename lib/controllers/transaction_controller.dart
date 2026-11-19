import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../repositories/transaction_repository.dart';
import '../services/finance_queries.dart';
import '../services/sqlite_database_service.dart';

class TransactionController {
  final TransactionRepository _repository = TransactionRepository.instance;
  final SQLiteDatabaseService _sqlite = SQLiteDatabaseService.instance;

  Future<List<TransactionModel>> fetchTransactions() => _repository.getTransactions();

  Future<List<WalletModel>> fetchWallets() => _sqlite.getWalletsWithBalance();

  Future<void> addTransaction({
    required String title,
    required double amount,
    required bool isExpense,
    required String category,
    required String wallet,
    required DateTime date,
    String? note,
  }) async {
    final newTransaction = TransactionModel(
      id: 'tx_${DateTime.now().microsecondsSinceEpoch}',
      title: title.trim().isEmpty ? category : title.trim(),
      amount: amount,
      isExpense: isExpense,
      category: category,
      wallet: wallet,
      date: date,
      note: note,
    );
    await _repository.addTransaction(newTransaction);
  }

  Future<void> updateTransaction({
    required String id,
    required String title,
    required double amount,
    required bool isExpense,
    required String category,
    required String wallet,
    required DateTime date,
    String? note,
  }) async {
    await _repository.updateTransaction(TransactionModel(
      id: id,
      title: title.trim().isEmpty ? category : title.trim(),
      amount: amount,
      isExpense: isExpense,
      category: category,
      wallet: wallet,
      date: date,
      note: note,
    ));
  }

  Future<void> deleteTransaction(String id) => _repository.deleteTransaction(id);

  List<TransactionModel> filterTransactions({
    required List<TransactionModel> transactions,
    required String searchQuery,
    String? categoryFilter,
    String? walletFilter,
    DateTime? month,
  }) {
    final q = searchQuery.trim().toLowerCase();
    return transactions.where((t) {
      final matchesQuery = q.isEmpty ||
          t.title.toLowerCase().contains(q) ||
          t.category.toLowerCase().contains(q) ||
          (t.note?.toLowerCase().contains(q) ?? false);
      final matchesCategory = categoryFilter == null || categoryFilter == 'Tất cả' || t.category == categoryFilter;
      final matchesWallet = walletFilter == null || t.wallet == walletFilter;
      final matchesMonth = month == null || (t.date.year == month.year && t.date.month == month.month);
      return matchesQuery && matchesCategory && matchesWallet && matchesMonth;
    }).toList();
  }
}
