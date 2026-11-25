import 'dart:io';

import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/transaction_controller.dart';
import '../../models/transaction_model.dart';
import '../widgets/common_widgets.dart';
import '../widgets/custom_button.dart';
import '../widgets/ui_kit.dart';
import 'add_transaction_screen.dart';

/// Chi tiết giao dịch. Pop(true) nếu dữ liệu đã thay đổi (sửa / xóa).
class TransactionDetailScreen extends StatefulWidget {
  final TransactionModel transaction;
  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final TransactionController _controller = TransactionController();
  late TransactionModel _tx = widget.transaction;
  String? _receipt;

  @override
  void initState() {
    super.initState();
    _loadReceipt();
  }

  Future<void> _loadReceipt() async {
    final p = await _controller.receiptOf(_tx.id);
    if (mounted) setState(() => _receipt = p);
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddTransactionScreen(editing: _tx)),
    );
    if (saved == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Xóa giao dịch này?',
      message: 'Số dư của ví sẽ được cập nhật lại. Bạn có thể khôi phục sau khi đồng bộ.',
      confirmLabel: 'Xóa',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _controller.deleteTransaction(_tx.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tx = _tx;
    final color = tx.isExpense ? AppColors.expense : AppColors.income;
    final hasTime = tx.date.hour != 0 || tx.date.minute != 0;
    final dateText = hasTime ? '${formatDate(tx.date)} · ${formatTime(tx.date)}' : formatDate(tx.date);
    return SubPage(
      title: 'Chi tiết giao dịch',
      actions: [
        SquareIconButton(icon: Icons.edit_outlined, onTap: _edit),
        SquareIconButton(icon: Icons.delete_outline_rounded, onTap: _delete),
      ],
      bottom: Row(
        children: [
          Expanded(child: TonalButton(text: 'Sửa', icon: Icons.edit_outlined, onPressed: _edit)),
          const SizedBox(width: 12),
          Expanded(
            child: TonalButton(
              text: 'Xóa',
              icon: Icons.delete_outline_rounded,
              onPressed: _delete,
              background: AppColors.expense50,
              foreground: AppColors.expense,
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 4),
          Center(
            child: IconBadge(
              icon: tx.categoryIcon,
              size: 68,
              color: tx.isExpense ? AppColors.warning700 : AppColors.income,
              background: tx.isExpense ? AppColors.warning50 : AppColors.income50,
            ),
          ),
          const SizedBox(height: 10),
          Text(tx.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(tx.formattedAmount, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 18),
          OutlineCard(
            child: Column(
              children: [
                _row('Danh mục', tx.category),
                _row('Ví', tx.wallet),
                _row('Ngày', dateText),
                if ((tx.note ?? '').trim().isNotEmpty) _row('Ghi chú', tx.note!.trim()),
              ],
            ),
          ),
          const SizedBox(height: 14),
          OutlineCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ảnh hóa đơn',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _receipt != null
                      ? GestureDetector(
                          onTap: () => showDialog<void>(
                            context: context,
                            builder: (_) => Dialog(
                              insetPadding: const EdgeInsets.all(12),
                              child: InteractiveViewer(child: Image.file(File(_receipt!))),
                            ),
                          ),
                          child: Image.file(File(_receipt!), width: double.infinity, height: 200, fit: BoxFit.cover),
                        )
                      : Container(
                          height: 110,
                          width: double.infinity,
                          color: AppColors.primary100,
                          child: const Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 40),
                        ),
                ),
                if (_receipt == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Chưa có ảnh hóa đơn. Bấm Sửa để thêm.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
