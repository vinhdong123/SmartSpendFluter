class DebtModel {
  final String id;
  final String counterparty;
  final bool isBorrowed; // true: mình đi vay, false: mình cho vay
  final int principal;
  final int paid;
  final DateTime openedOn;
  final DateTime? dueOn;
  final String? note;

  const DebtModel({
    required this.id,
    required this.counterparty,
    required this.isBorrowed,
    required this.principal,
    required this.paid,
    required this.openedOn,
    this.dueOn,
    this.note,
  });

  int get remaining => principal - paid < 0 ? 0 : principal - paid;
  bool get isSettled => remaining <= 0;
  double get ratio => principal <= 0 ? 0 : (paid / principal).clamp(0.0, 1.0);

  bool get isOverdue {
    if (dueOn == null || isSettled) return false;
    final now = DateTime.now();
    return dueOn!.isBefore(DateTime(now.year, now.month, now.day));
  }

  /// Còn tối đa 3 ngày nữa đến hạn (hoặc đã quá hạn).
  bool get isDueSoon {
    if (dueOn == null || isSettled) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return dueOn!.difference(today).inDays <= 3;
  }
}

class DebtPaymentModel {
  final String id;
  final int amount;
  final DateTime date;
  final String? note;

  const DebtPaymentModel({
    required this.id,
    required this.amount,
    required this.date,
    this.note,
  });
}
