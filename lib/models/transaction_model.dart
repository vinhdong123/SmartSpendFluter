import 'package:material_ui/material_ui.dart';
import '../core/constants/categories.dart';
import '../core/utils/formatters.dart';

class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final bool isExpense;
  final String category;
  final String wallet;
  final DateTime date;
  final String? note;

  const TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.isExpense,
    required this.category,
    required this.wallet,
    required this.date,
    this.note,
  });

  String get formattedAmount => '${isExpense ? '-' : '+'}${formatVND(amount.abs())}';

  IconData get categoryIcon => Categories.iconOf(category);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'isExpense': isExpense,
      'category': category,
      'wallet': wallet,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      isExpense: json['isExpense'] as bool? ?? true,
      category: json['category'] as String? ?? 'Khác',
      wallet: json['wallet'] as String? ?? 'Tiền mặt',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      note: json['note'] as String?,
    );
  }
}
