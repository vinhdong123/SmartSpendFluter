import '../services/sync_service.dart';
import '../models/debt_model.dart';
import '../models/group_models.dart';
import '../models/wallet_model.dart';
import '../services/finance_queries.dart';
import '../services/social_queries.dart';
import '../services/sqlite_database_service.dart';

class GroupDebtController {
  final SQLiteDatabaseService _sqlite = SQLiteDatabaseService.instance;

  Future<List<GroupDetail>> fetchGroups() => _sqlite.getGroups();
  Future<GroupDetail?> fetchGroup(String id) => _sqlite.getGroupDetail(id);
  Future<List<DebtModel>> fetchDebts() => _sqlite.getDebts();
  Future<List<WalletModel>> fetchWallets() => _sqlite.getWalletsWithBalance();
  Future<List<DebtPaymentModel>> fetchPayments(String debtId) => _sqlite.getDebtPayments(debtId);

  Future<String> createGroup(String name, List<String> members, [String? description]) =>
      _sqlite.createGroup(name: name, memberNames: members, description: description);

  Future<void> addMember(String groupId, String name) => _sqlite.addGroupMember(groupId, name);

  Future<void> addGroupExpense({
    required String groupId,
    required String description,
    required int amount,
    required String paidBy,
    required List<String> participants,
    required DateTime date,
    Map<String, int>? shares,
  }) =>
      _sqlite.addGroupExpense(
        shares: shares,
        groupId: groupId,
        description: description,
        amount: amount,
        paidByMemberId: paidBy,
        participantIds: participants,
        date: date,
      );

  Future<void> deleteGroupExpense(String id) => _sqlite.deleteGroupExpense(id);

  Future<void> settle(String groupId, SettlementSuggestion s) => _sqlite.recordGroupSettlement(
        groupId: groupId,
        fromMemberId: s.fromId,
        toMemberId: s.toId,
        amount: s.amount,
      );

  Future<void> addDebt({
    required String counterparty,
    required bool isBorrowed,
    required int amount,
    DateTime? dueOn,
    String? note,
    String? walletName,
  }) =>
      markSynced(_sqlite.addDebt(
        counterparty: counterparty,
        isBorrowed: isBorrowed,
        amount: amount,
        openedOn: DateTime.now(),
        dueOn: dueOn,
        note: note,
        walletName: walletName,
      ));

  Future<void> payDebt(DebtModel debt, int amount, String walletName, [DateTime? date]) =>
      markSynced(_sqlite.recordDebtPayment(debt: debt, amount: amount, walletName: walletName, date: date));

  Future<void> archiveDebt(String id) => markSynced(_sqlite.archiveDebt(id));

  /// Kéo dữ liệu nhóm mới nhất từ Firestore. Trả về (lỗi, có thay đổi).
  Future<({String? error, bool changed})> syncGroups() => SyncService.instance.pullGroups();

  /// Thêm người dùng SmartSpend khác (theo email) vào nhóm.
  Future<String> addMemberByEmail(String groupId, String email) =>
      SyncService.instance.addUserToGroup(groupId, email);

  bool get canShareGroups => SyncService.instance.isActive;
}
