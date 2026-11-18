import '../models/transaction_model.dart';
import '../repositories/transaction_repository.dart';

class TransactionController {
  final TransactionRepository _repository = TransactionRepository.instance;

  Future<List<TransactionModel>> fetchTransactions() async {
    return await _repository.getTransactions();
  }

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
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
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

  List<TransactionModel> filterTransactions({
    required List<TransactionModel> transactions,
    required String searchQuery,
    String? categoryFilter,
  }) {
    return transactions.where((t) {
      final matchesQuery = searchQuery.isEmpty ||
          t.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          t.category.toLowerCase().contains(searchQuery.toLowerCase()) ||
          (t.note?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false);

      final matchesCategory = categoryFilter == null ||
          categoryFilter == 'Tất cả' ||
          t.category == categoryFilter;

      return matchesQuery && matchesCategory;
    }).toList();
  }
}
