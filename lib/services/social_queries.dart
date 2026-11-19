import 'package:sqflite/sqflite.dart';
import '../core/utils/formatters.dart';
import '../models/debt_model.dart';
import '../models/group_models.dart';
import 'sqlite_database_service.dart';

/// Nhóm chi tiêu chung và sổ nợ.
extension SocialQueries on SQLiteDatabaseService {
  // ================= GROUPS ================= //

  Future<void> _insertContactMember(DatabaseExecutor txn, String groupId, String name, int seq) async {
    final stamp = '${DateTime.now().microsecondsSinceEpoch}_$seq';
    final contactId = 'contact_$stamp';
    // Thành viên không có tài khoản -> tạo "người liên hệ" cục bộ để thỏa ràng buộc khóa ngoại.
    await txn.insert('users', {
      'id': contactId,
      'email': '$contactId@contacts.smartspend.local',
      'display_name': name.trim(),
      'password_hash': '*',
    });
    await txn.insert('group_members', {
      'id': 'gm_$stamp',
      'group_id': groupId,
      'user_id': contactId,
      'display_name': name.trim(),
    });
  }

  Future<String> createGroup({required String name, required List<String> memberNames}) async {
    final db = await readyDatabase;
    final groupId = 'group_${DateTime.now().microsecondsSinceEpoch}';
    await db.transaction((txn) async {
      await txn.insert('expense_groups', {'id': groupId, 'owner_id': uid, 'name': name.trim()});
      await txn.insert('group_members', {
        'id': 'gm_${groupId}_me',
        'group_id': groupId,
        'user_id': uid,
        'display_name': 'Bạn',
      });
      var seq = 0;
      for (final m in memberNames) {
        if (m.trim().isEmpty) continue;
        await _insertContactMember(txn, groupId, m, seq++);
      }
    });
    return groupId;
  }

  Future<void> addGroupMember(String groupId, String name) async {
    final db = await readyDatabase;
    await db.transaction((txn) async {
      await _insertContactMember(txn, groupId, name, 0);
    });
  }

  Future<List<GroupDetail>> getGroups() async {
    final db = await readyDatabase;
    final rows = await db.rawQuery('''
      SELECT g.id
      FROM expense_groups g
      JOIN group_members m ON m.group_id = g.id AND m.user_id = ? AND m.left_at IS NULL
      ORDER BY g.rowid DESC
    ''', [uid]);
    final result = <GroupDetail>[];
    for (final r in rows) {
      final detail = await getGroupDetail(r['id'] as String);
      if (detail != null) result.add(detail);
    }
    return result;
  }

  Future<GroupDetail?> getGroupDetail(String groupId) async {
    final db = await readyDatabase;
    final groupRows = await db.query('expense_groups', where: 'id = ?', whereArgs: [groupId], limit: 1);
    if (groupRows.isEmpty) return null;

    final memberRows = await db.query(
      'group_members',
      where: 'group_id = ? AND left_at IS NULL',
      whereArgs: [groupId],
      orderBy: 'rowid',
    );
    final members = [
      for (final m in memberRows)
        GroupMemberModel(
          id: m['id'] as String,
          name: m['display_name'] as String,
          isMe: m['user_id'] == uid,
        ),
    ];

    final expenseRows = await db.query(
      'group_expenses',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'occurred_on DESC, rowid DESC',
    );
    final expenses = [
      for (final e in expenseRows)
        GroupExpenseModel(
          id: e['id'] as String,
          description: e['description'] as String,
          amount: (e['amount'] as num).toInt(),
          date: DateTime.tryParse(e['occurred_on'] as String) ?? DateTime.now(),
          paidByMemberId: e['paid_by_member_id'] as String,
        ),
    ];

    Future<Map<String, int>> sumBy(String sql) async {
      final rows = await db.rawQuery(sql, [groupId]);
      return {for (final r in rows) (r['k'] as String): (r['total'] as num).toInt()};
    }

    final paid = await sumBy(
        'SELECT paid_by_member_id AS k, SUM(amount) AS total FROM group_expenses WHERE group_id = ? GROUP BY paid_by_member_id');
    final owed = await sumBy('''
        SELECT s.member_id AS k, SUM(s.share_amount) AS total
        FROM group_expense_shares s JOIN group_expenses e ON e.id = s.expense_id
        WHERE e.group_id = ? GROUP BY s.member_id''');
    final settledOut = await sumBy(
        'SELECT from_member_id AS k, SUM(amount) AS total FROM group_settlements WHERE group_id = ? GROUP BY from_member_id');
    final settledIn = await sumBy(
        'SELECT to_member_id AS k, SUM(amount) AS total FROM group_settlements WHERE group_id = ? GROUP BY to_member_id');

    final balances = <String, int>{
      for (final m in members)
        m.id: (paid[m.id] ?? 0) - (owed[m.id] ?? 0) + (settledOut[m.id] ?? 0) - (settledIn[m.id] ?? 0),
    };

    return GroupDetail(
      id: groupId,
      name: groupRows.first['name'] as String,
      members: members,
      expenses: expenses,
      balances: balances,
      suggestions: _suggestSettlements(members, balances),
    );
  }

  /// Ghép người nợ với người được nhận để giảm số lần chuyển tiền.
  List<SettlementSuggestion> _suggestSettlements(List<GroupMemberModel> members, Map<String, int> balances) {
    final names = {for (final m in members) m.id: m.displayName};
    final creditors = <MapEntry<String, int>>[];
    final debtors = <MapEntry<String, int>>[];
    balances.forEach((id, value) {
      if (value > 0) creditors.add(MapEntry(id, value));
      if (value < 0) debtors.add(MapEntry(id, -value));
    });
    creditors.sort((a, b) => b.value.compareTo(a.value));
    debtors.sort((a, b) => b.value.compareTo(a.value));

    final result = <SettlementSuggestion>[];
    var i = 0;
    var j = 0;
    var creditLeft = creditors.isEmpty ? 0 : creditors[0].value;
    var debtLeft = debtors.isEmpty ? 0 : debtors[0].value;
    while (i < creditors.length && j < debtors.length) {
      final amount = creditLeft < debtLeft ? creditLeft : debtLeft;
      if (amount > 0) {
        result.add(SettlementSuggestion(
          fromId: debtors[j].key,
          fromName: names[debtors[j].key] ?? '?',
          toId: creditors[i].key,
          toName: names[creditors[i].key] ?? '?',
          amount: amount,
        ));
      }
      creditLeft -= amount;
      debtLeft -= amount;
      if (creditLeft == 0) {
        i++;
        if (i < creditors.length) creditLeft = creditors[i].value;
      }
      if (debtLeft == 0) {
        j++;
        if (j < debtors.length) debtLeft = debtors[j].value;
      }
    }
    return result;
  }

  /// Chia đều [amount] cho các thành viên trong [participantIds].
  Future<void> addGroupExpense({
    required String groupId,
    required String description,
    required int amount,
    required String paidByMemberId,
    required List<String> participantIds,
    required DateTime date,
  }) async {
    if (participantIds.isEmpty) {
      throw ArgumentError('Cần chọn ít nhất một người tham gia.');
    }
    final db = await readyDatabase;
    final expenseId = 'ge_${DateTime.now().microsecondsSinceEpoch}';
    final base = amount ~/ participantIds.length;
    final remainder = amount % participantIds.length;

    await db.transaction((txn) async {
      await txn.insert('group_expenses', {
        'id': expenseId,
        'group_id': groupId,
        'paid_by_member_id': paidByMemberId,
        'description': description.trim(),
        'amount': amount,
        'occurred_on': dbDate(date),
      });
      for (var i = 0; i < participantIds.length; i++) {
        await txn.insert('group_expense_shares', {
          'id': 'ges_${expenseId}_$i',
          'expense_id': expenseId,
          'member_id': participantIds[i],
          'share_amount': base + (i < remainder ? 1 : 0),
        });
      }
    });
  }

  Future<void> deleteGroupExpense(String expenseId) async {
    final db = await readyDatabase;
    await db.delete('group_expenses', where: 'id = ?', whereArgs: [expenseId]);
  }

  Future<void> recordGroupSettlement({
    required String groupId,
    required String fromMemberId,
    required String toMemberId,
    required int amount,
  }) async {
    final db = await readyDatabase;
    await db.insert('group_settlements', {
      'id': 'gs_${DateTime.now().microsecondsSinceEpoch}',
      'group_id': groupId,
      'from_member_id': fromMemberId,
      'to_member_id': toMemberId,
      'amount': amount,
      'occurred_on': dbDate(DateTime.now()),
    });
  }

  // ================= DEBTS ================= //

  Future<List<DebtModel>> getDebts({bool includeArchived = false}) async {
    final db = await readyDatabase;
    final rows = await db.rawQuery('''
      SELECT d.id, d.counterparty_name, d.direction, d.principal_amount, d.opened_on, d.due_on, d.note,
        COALESCE((
          SELECT SUM(t.amount) FROM debt_payments p
          JOIN transactions t ON t.id = p.transaction_id
          WHERE p.debt_id = d.id
        ), 0) AS paid
      FROM debts d
      WHERE d.user_id = ? ${includeArchived ? '' : 'AND d.is_archived = 0'}
      ORDER BY d.rowid DESC
    ''', [uid]);
    return rows
        .map((r) => DebtModel(
              id: r['id'] as String,
              counterparty: r['counterparty_name'] as String,
              isBorrowed: r['direction'] == 'borrowed',
              principal: (r['principal_amount'] as num).toInt(),
              paid: (r['paid'] as num).toInt(),
              openedOn: DateTime.tryParse(r['opened_on'] as String) ?? DateTime.now(),
              dueOn: r['due_on'] == null ? null : DateTime.tryParse(r['due_on'] as String),
              note: r['note'] as String?,
            ))
        .toList();
  }

  /// Nếu [walletName] != null, đồng thời ghi một giao dịch thu/chi tương ứng
  /// (đi vay -> thu nhập, cho vay -> chi tiêu).
  Future<void> addDebt({
    required String counterparty,
    required bool isBorrowed,
    required int amount,
    required DateTime openedOn,
    DateTime? dueOn,
    String? note,
    String? walletName,
  }) async {
    final db = await readyDatabase;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final debtId = 'debt_$stamp';
    String? txId;
    String? walletId;
    if (walletName != null) {
      walletId = await resolveWalletId(walletName);
      txId = 'tx_debt_$stamp';
    }

    await db.transaction((txn) async {
      if (txId != null && walletId != null) {
        await txn.insert('transactions', {
          'id': txId,
          'user_id': uid,
          'wallet_id': walletId,
          'category_code': isBorrowed ? 'vay_no' : 'cho_vay',
          'type': isBorrowed ? 'income' : 'expense',
          'kind': isBorrowed ? 'Vay nợ' : 'Cho vay',
          'amount': amount,
          'occurred_on': dbDate(openedOn),
          'note': isBorrowed ? 'Vay từ ${counterparty.trim()}' : 'Cho ${counterparty.trim()} vay',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      await txn.insert('debts', {
        'id': debtId,
        'user_id': uid,
        'counterparty_name': counterparty.trim(),
        'direction': isBorrowed ? 'borrowed' : 'lent',
        'principal_amount': amount,
        'opening_transaction_id': txId,
        'opened_on': dbDate(openedOn),
        'due_on': dueOn == null ? null : dbDate(dueOn),
        'note': (note ?? '').trim().isEmpty ? null : note!.trim(),
      });
    });
  }

  /// Ghi nhận một lần trả (đi vay) / thu hồi (cho vay) nợ, đồng thời tạo giao dịch.
  Future<void> recordDebtPayment({
    required DebtModel debt,
    required int amount,
    required String walletName,
  }) async {
    if (amount <= 0 || amount > debt.remaining) {
      throw ArgumentError('Số tiền phải nằm trong khoảng 1 – ${formatVND(debt.remaining)}.');
    }
    final db = await readyDatabase;
    final walletId = await resolveWalletId(walletName);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final txId = 'tx_dp_$stamp';
    final now = DateTime.now();

    await db.transaction((txn) async {
      await txn.insert('transactions', {
        'id': txId,
        'user_id': uid,
        'wallet_id': walletId,
        'category_code': debt.isBorrowed ? 'tra_no' : 'thu_no',
        'type': debt.isBorrowed ? 'expense' : 'income',
        'kind': debt.isBorrowed ? 'Trả nợ' : 'Thu nợ',
        'amount': amount,
        'occurred_on': dbDate(now),
        'note': debt.isBorrowed ? 'Trả nợ ${debt.counterparty}' : '${debt.counterparty} trả nợ',
        'created_at': now.toIso8601String(),
      });
      await txn.insert('debt_payments', {
        'id': 'dp_$stamp',
        'debt_id': debt.id,
        'transaction_id': txId,
      });
    });
  }

  Future<List<DebtPaymentModel>> getDebtPayments(String debtId) async {
    final db = await readyDatabase;
    final rows = await db.rawQuery('''
      SELECT p.id, t.amount, t.occurred_on, t.note
      FROM debt_payments p JOIN transactions t ON t.id = p.transaction_id
      WHERE p.debt_id = ?
      ORDER BY t.occurred_on DESC, t.created_at DESC
    ''', [debtId]);
    return rows
        .map((r) => DebtPaymentModel(
              id: r['id'] as String,
              amount: (r['amount'] as num).toInt(),
              date: DateTime.tryParse(r['occurred_on'] as String) ?? DateTime.now(),
              note: r['note'] as String?,
            ))
        .toList();
  }

  Future<void> archiveDebt(String debtId) async {
    final db = await readyDatabase;
    await db.update('debts', {'is_archived': 1}, where: 'id = ? AND user_id = ?', whereArgs: [debtId, uid]);
  }
}
