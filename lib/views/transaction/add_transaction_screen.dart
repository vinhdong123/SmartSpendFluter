import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/categories.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/budget_controller.dart';
import '../../controllers/transaction_controller.dart';
import '../../models/transaction_model.dart';
import '../../models/wallet_model.dart';
import '../widgets/common_widgets.dart';
import '../widgets/custom_button.dart';
import '../widgets/ui_kit.dart';
import 'category_picker_screen.dart';
import 'scan_receipt_screen.dart';

class AddTransactionScreen extends StatefulWidget {
  /// Truyền vào để chỉnh sửa một giao dịch có sẵn.
  final TransactionModel? editing;

  /// Ảnh hóa đơn đã chụp trước (từ nút "Chụp hóa đơn" ở Trang chủ).
  final String? initialReceiptPath;

  const AddTransactionScreen({super.key, this.editing, this.initialReceiptPath});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final TransactionController _controller = TransactionController();
  final BudgetController _budgetController = BudgetController();
  final _noteController = TextEditingController();
  final _amountController = TextEditingController();

  bool _isExpense = true;
  String _category = Categories.expense.first.label;
  String _wallet = 'Tiền mặt';
  DateTime _date = DateTime.now();
  List<WalletModel> _wallets = [];
  String? _amountError;
  String? _newReceipt; // ảnh mới chọn
  String? _oldReceipt; // ảnh đã lưu (khi sửa)
  bool _removeReceipt = false;
  bool _saving = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    _newReceipt = widget.initialReceiptPath;
    final e = widget.editing;
    if (e != null) {
      _isExpense = e.isExpense;
      _category = e.category;
      _wallet = e.wallet;
      _date = e.date;
      _amountController.text = formatNumber(e.amount);
      _noteController.text = e.note ?? '';
      _controller.receiptOf(e.id).then((p) {
        if (mounted) setState(() => _oldReceipt = p);
      });
    }
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    final wallets = await _controller.fetchWallets();
    if (!mounted) return;
    setState(() {
      _wallets = wallets;
      if (wallets.isNotEmpty && !wallets.any((w) => w.name == _wallet)) _wallet = wallets.first.name;
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _switchType(bool expense) {
    if (_isExpense == expense) return;
    setState(() {
      _isExpense = expense;
      final list = expense ? Categories.expense : Categories.income;
      if (!list.any((c) => c.label == _category)) _category = list.first.label;
    });
  }

  Future<void> _pickCategory() async {
    final label = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => CategoryPickerScreen(isIncome: !_isExpense, selected: _category)),
    );
    if (label != null) setState(() => _category = label);
  }

  Future<void> _pickWallet() async {
    if (_wallets.isEmpty) return;
    final picked = await showPickerSheet<String>(
      context,
      title: 'Chọn ví',
      selected: _wallet,
      options: [for (final w in _wallets) PickerOption(w.name, w.name, icon: w.icon)],
    );
    if (picked != null) setState(() => _wallet = picked.value);
  }

  Future<void> _pickDate() async {
    final d = await pickDate(context, _date, last: DateTime.now().add(const Duration(days: 365)));
    if (d != null) setState(() => _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute));
  }

  Future<void> _scan() async {
    final path = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const ScanReceiptScreen()));
    if (path != null) setState(() => _newReceipt = path);
  }

  Future<void> _save() async {
    final amount = parseAmount(_amountController.text);
    if (amount <= 0) {
      setState(() => _amountError = 'Nhập số tiền lớn hơn 0');
      return;
    }
    if (_wallets.isEmpty) {
      showSnack(context, 'Chưa có ví nào. Hãy tạo ví trong Cài đặt.', isError: true);
      return;
    }
    setState(() {
      _amountError = null;
      _saving = true;
    });
    final note = _noteController.text.trim();
    final title = note.isEmpty ? _category : note.split('\n').first;
    try {
      if (_isEditing) {
        await _controller.updateTransaction(
          id: widget.editing!.id,
          title: title,
          amount: amount.toDouble(),
          isExpense: _isExpense,
          category: _category,
          wallet: _wallet,
          date: _date,
          note: note.isEmpty ? null : note,
          receiptPath: _newReceipt,
          removeReceipt: _removeReceipt,
        );
      } else {
        await _controller.addTransaction(
          title: title,
          amount: amount.toDouble(),
          isExpense: _isExpense,
          category: _category,
          wallet: _wallet,
          date: _date,
          note: note.isEmpty ? null : note,
          receiptPath: _newReceipt,
        );
      }
      String? warning;
      if (_isExpense) warning = await _budgetController.alertAfterExpense(_category, _date);
      if (!mounted) return;
      if (warning != null) showSnack(context, warning);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, 'Không thể lưu giao dịch: $e', isError: true);
      }
    }
  }

  Widget _receiptPreview() {
    final path = _newReceipt ?? (_removeReceipt ? null : _oldReceipt);
    if (path == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(File(path), width: 56, height: 56, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const IconBadge(icon: Icons.receipt_long_outlined, size: 56)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Đã đính kèm ảnh hóa đơn',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
          IconButton(
            onPressed: () => setState(() {
              _newReceipt = null;
              _removeReceipt = true;
            }),
            icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amountColor = _isExpense ? AppColors.expense : AppColors.income;
    final categoryList = _isExpense ? Categories.expense : Categories.income;
    final catIcon = categoryList.any((c) => c.label == _category) ? Categories.iconOf(_category) : Icons.label_outline_rounded;

    return SubPage(
      title: _isEditing ? 'Sửa giao dịch' : 'Thêm giao dịch',
      closeIcon: !_isEditing,
      bottom: BottomPrimary(
        text: _isEditing ? 'Lưu thay đổi' : 'Lưu giao dịch',
        onPressed: _save,
        loading: _saving,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedTabs(
            labels: const ['Chi tiêu', 'Thu nhập'],
            selected: _isExpense ? 0 : 1,
            onChanged: (i) => _switchType(i == 0),
          ),
          const SizedBox(height: 18),
          const Center(child: Text('Số tiền', style: TextStyle(fontSize: 14, color: AppColors.textSecondary))),
          TextField(
            controller: _amountController,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsSeparatorFormatter()],
            onChanged: (_) {
              if (_amountError != null) setState(() => _amountError = null);
            },
            style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: amountColor),
            decoration: InputDecoration(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              hintText: '0',
              hintStyle: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: amountColor.withValues(alpha: 0.3)),
              suffixText: 'đ',
              suffixStyle: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: amountColor),
              errorText: _amountError,
            ),
          ),
          LabeledSelect(label: 'Danh mục', icon: catIcon, value: _category, onTap: _pickCategory),
          LabeledSelect(
            label: 'Ví',
            icon: Icons.account_balance_wallet_outlined,
            value: _wallet,
            onTap: _wallets.length > 1 ? _pickWallet : null,
          ),
          LabeledSelect(
            label: 'Ngày',
            icon: Icons.calendar_today_outlined,
            value: formatDate(_date),
            onTap: _pickDate,
            showChevron: false,
          ),
          LabeledInput(
            label: 'Ghi chú',
            controller: _noteController,
            icon: Icons.notes_rounded,
            hint: 'Ví dụ: Ăn trưa cùng đồng nghiệp',
          ),
          const SizedBox(height: 14),
          TonalButton(
            text: (_newReceipt ?? _oldReceipt) != null && !_removeReceipt ? 'Chụp lại hóa đơn' : 'Chụp hóa đơn',
            icon: Icons.photo_camera_outlined,
            onPressed: _scan,
          ),
          _receiptPreview(),
        ],
      ),
    );
  }
}
