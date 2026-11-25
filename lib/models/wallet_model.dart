import 'package:material_ui/material_ui.dart';

class WalletModel {
  final String id;
  final String name;
  final String type; // cash | ewallet | bank
  final int initialBalance;
  final int balance;

  const WalletModel({
    required this.id,
    required this.name,
    required this.type,
    required this.initialBalance,
    required this.balance,
  });

  IconData get icon {
    switch (type) {
      case 'bank':
        return Icons.account_balance_outlined;
      case 'ewallet':
        return Icons.phone_android_rounded;
      default:
        return Icons.payments_outlined;
    }
  }

  static String typeLabel(String type) {
    switch (type) {
      case 'bank':
        return 'Thẻ ngân hàng';
      case 'ewallet':
        return 'Ví điện tử';
      default:
        return 'Tiền mặt';
    }
  }
}
