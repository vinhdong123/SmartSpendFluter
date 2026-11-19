class GroupMemberModel {
  final String id;
  final String name;
  final bool isMe;

  const GroupMemberModel({required this.id, required this.name, required this.isMe});

  String get displayName => isMe ? 'Bạn' : name;
}

class GroupExpenseModel {
  final String id;
  final String description;
  final int amount;
  final DateTime date;
  final String paidByMemberId;

  const GroupExpenseModel({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.paidByMemberId,
  });
}

class SettlementSuggestion {
  final String fromId;
  final String fromName;
  final String toId;
  final String toName;
  final int amount;

  const SettlementSuggestion({
    required this.fromId,
    required this.fromName,
    required this.toId,
    required this.toName,
    required this.amount,
  });
}

class GroupDetail {
  final String id;
  final String name;
  final List<GroupMemberModel> members;
  final List<GroupExpenseModel> expenses;

  /// memberId -> số dư. Dương: được nhận lại; âm: đang nợ.
  final Map<String, int> balances;
  final List<SettlementSuggestion> suggestions;

  const GroupDetail({
    required this.id,
    required this.name,
    required this.members,
    required this.expenses,
    required this.balances,
    required this.suggestions,
  });

  int get totalExpense => expenses.fold<int>(0, (sum, e) => sum + e.amount);

  GroupMemberModel? get me {
    for (final m in members) {
      if (m.isMe) return m;
    }
    return null;
  }

  int get myBalance => me == null ? 0 : (balances[me!.id] ?? 0);

  String memberName(String id) {
    for (final m in members) {
      if (m.id == id) return m.displayName;
    }
    return '?';
  }
}
