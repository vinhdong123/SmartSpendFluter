import '../core/utils/formatters.dart';
import '../models/transaction_model.dart';
import '../models/tx_filter.dart';
import '../models/wallet_model.dart';
import '../repositories/transaction_repository.dart';
import '../services/extra_queries.dart';
import '../services/finance_queries.dart';
import '../services/sqlite_database_service.dart';

class TransactionController {
  final TransactionRepository _repository = TransactionRepository.instance;
  final SQLiteDatabaseService _sqlite = SQLiteDatabaseService.instance;

  Future<List<TransactionModel>> fetchTransactions() => _repository.getTransactions();

  Future<List<WalletModel>> fetchWallets() => _sqlite.getWalletsWithBalance();

  Future<String?> receiptOf(String id) => _sqlite.getReceiptPath(id);

  /// Trả về id giao dịch vừa tạo.
  Future<String> addTransaction({
    required String title,
    required double amount,
    required bool isExpense,
    required String category,
    required String wallet,
    required DateTime date,
    String? note,
    String? receiptPath,
  }) async {
    final id = 'tx_${DateTime.now().microsecondsSinceEpoch}';
    await _repository.addTransaction(TransactionModel(
      id: id,
      title: title.trim().isEmpty ? category : title.trim(),
      amount: amount,
      isExpense: isExpense,
      category: category,
      wallet: wallet,
      date: date,
      note: note,
    ));
    if (receiptPath != null) await _sqlite.setReceipt(id, receiptPath);
    return id;
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
    String? receiptPath,
    bool removeReceipt = false,
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
    if (receiptPath != null) {
      await _sqlite.setReceipt(id, receiptPath);
    } else if (removeReceipt) {
      await _sqlite.removeReceipt(id);
    }
  }

  Future<void> deleteTransaction(String id) async {
    await _sqlite.removeReceipt(id);
    await _repository.deleteTransaction(id);
  }

  List<TransactionModel> filterTransactions(List<TransactionModel> list, TxFilter f) {
    final q = f.query.trim().toLowerCase();
    return list.where((t) {
      if (q.isNotEmpty &&
          !(t.title.toLowerCase().contains(q) ||
              t.category.toLowerCase().contains(q) ||
              (t.note?.toLowerCase().contains(q) ?? false))) {
        return false;
      }
      if (f.category != null && t.category != f.category) return false;
      if (f.wallet != null && t.wallet != f.wallet) return false;
      if (f.type == 1 && !t.isExpense) return false;
      if (f.type == 2 && t.isExpense) return false;
      if (f.hasRange) {
        final d = DateTime(t.date.year, t.date.month, t.date.day);
        final from = DateTime(f.from!.year, f.from!.month, f.from!.day);
        final to = DateTime(f.to!.year, f.to!.month, f.to!.day);
        if (d.isBefore(from) || d.isAfter(to)) return false;
      }
      return true;
    }).toList();
  }

  static String dayHeader(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
    if (diff == 0) return 'Hôm nay';
    if (diff == 1) return 'Hôm qua';
    return d.year == now.year ? formatDayMonth(d) : formatDate(d);
  }
}
