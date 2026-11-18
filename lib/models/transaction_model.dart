import 'package:material_ui/material_ui.dart';

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

  String get formattedAmount {
    final valueStr = amount.toInt().abs().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    final prefix = isExpense ? '-' : '+';
    return '$prefix$valueStrđ';
  }

  IconData get categoryIcon {
    switch (category.toLowerCase()) {
      case 'ăn uống':
        return Icons.local_cafe_outlined;
      case 'di chuyển':
        return Icons.directions_car_outlined;
      case 'mua sắm':
        return Icons.shopping_bag_outlined;
      case 'hóa đơn':
        return Icons.bolt_outlined;
      case 'giải trí':
        return Icons.sports_esports_outlined;
      case 'học tập':
        return Icons.school_outlined;
      case 'sức khỏe':
        return Icons.favorite_border_rounded;
      case 'thu nhập':
        return Icons.attach_money_rounded;
      default:
        return Icons.more_horiz_rounded;
    }
  }

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
