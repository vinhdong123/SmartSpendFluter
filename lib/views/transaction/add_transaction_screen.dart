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

class AddTransactionScreen extends StatefulWidget {
  /// Truyền vào để chỉnh sửa một giao dịch có sẵn.
  final TransactionModel? editing;

  const AddTransactionScreen({super.key, this.editing});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final TransactionController _controller = TransactionController();
  final BudgetController _budgetController = BudgetController();
  final _noteController = TextEditingController();
  final _amountController = TextEditingController();

  bool _isExpense = true;
  String _selectedCategory = Categories.expense.first.label;
  String _selectedWallet = 'Tiền mặt';
  DateTime _selectedDate = DateTime.now();
  List<WalletModel> _wallets = [];
  String? _amountError;
  bool _isLoading = false;

  bool get _isEditing => widget.editing != null;
  List<CategoryInfo> get _categories => _isExpense ? Categories.expense : Categories.income;

  @override
  void initState() {
    super.initState();
    final tx = widget.editing;
    if (tx != null) {
      _isExpense = tx.isExpense;
      _selectedCategory = tx.category;
      _selectedWallet = tx.wallet;
      _selectedDate = tx.date;
      _amountController.text = formatNumber(tx.amount);
      _noteController.text = tx.note ?? tx.title;
    }
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    final list = await _controller.fetchWallets();
    if (!mounted) return;
    setState(() {
      _wallets = list;
      if (list.isNotEmpty && !list.any((w) => w.name == _selectedWallet)) {
        _selectedWallet = list.first.name;
      }
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _setType(bool isExpense) {
    if (_isExpense == isExpense) return;
    setState(() {
      _isExpense = isExpense;
      _selectedCategory = _categories.first.label;
    });
  }

  String get _dateLabel {
    final now = DateTime.now();
    if (isSameDay(_selectedDate, now)) return 'Hôm nay, ${formatDayMonth(_selectedDate)}';
    if (isSameDay(_selectedDate, DateTime(now.year, now.month, now.day - 1))) {
      return 'Hôm qua, ${formatDayMonth(_selectedDate)}';
    }
    return formatDate(_selectedDate);
  }

  Future<void> _pickWallet() async {
    if (_wallets.isEmpty) return;
    final result = await showPickerSheet<String>(
      context,
      title: 'Chọn ví',
      selected: _selectedWallet,
      options: [for (final w in _wallets) PickerOption(w.name, w.name, icon: w.icon)],
    );
    if (result != null) setState(() => _selectedWallet = result.value);
  }

  Future<void> _pickDate() async {
    final picked = await pickDate(
      context,
      initial: _selectedDate,
      last: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    final now = DateTime.now();
    setState(() {
      _selectedDate = isSameDay(picked, _selectedDate)
          ? _selectedDate
          : DateTime(picked.year, picked.month, picked.day, now.hour, now.minute);
    });
  }

  void _showComingSoon(String feature) {
    showSnack(context, '$feature cần tích hợp camera / OCR — sẽ bổ sung ở phiên bản sau.');
  }

  Future<void> _handleSave() async {
    final amount = parseAmount(_amountController.text);
    if (amount <= 0) {
      setState(() => _amountError = 'Vui lòng nhập số tiền lớn hơn 0');
      return;
    }
    setState(() {
      _amountError = null;
      _isLoading = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final note = _noteController.text.trim();
    final title = note.isEmpty ? _selectedCategory : note;

    try {
      if (_isEditing) {
        await _controller.updateTransaction(
          id: widget.editing!.id,
          title: title,
          amount: amount.toDouble(),
          isExpense: _isExpense,
          category: _selectedCategory,
          wallet: _selectedWallet,
          date: _selectedDate,
          note: note,
        );
      } else {
        await _controller.addTransaction(
          title: title,
          amount: amount.toDouble(),
          isExpense: _isExpense,
          category: _selectedCategory,
          wallet: _selectedWallet,
          date: _selectedDate,
          note: note,
        );
      }

      String? alert;
      if (_isExpense) {
        alert = await _budgetController.alertAfterExpense(_selectedCategory, _selectedDate);
      }

      if (!mounted) return;
      navigator.pop(true);
      if (alert != null) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(alert),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFD97706),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showSnack(context, 'Lỗi: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _isExpense ? const Color(0xFFEF4444) : AppColors.primaryTeal;
    final amountBg = _isExpense ? const Color(0xFFFFF1F2) : AppColors.lightMint;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Sửa giao dịch' : 'Thêm giao dịch',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Segmented Switcher (Chi tiêu / Thu nhập)
              Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2F1ED),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _setType(true),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _isExpense ? const Color(0xFFFFF1F2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Chi tiêu',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _isExpense ? const Color(0xFFEF4444) : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _setType(false),
                        child: Container(
                          decoration: BoxDecoration(
                            color: !_isExpense ? AppColors.primaryTeal : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Thu nhập',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: !_isExpense ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Large Amount Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: amountBg,
                  borderRadius: BorderRadius.circular(20),
                  border: _amountError == null ? null : Border.all(color: AppColors.error),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Số tiền',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IntrinsicWidth(
                          child: TextField(
                            controller: _amountController,
                            autofocus: !_isEditing,
                            keyboardType: TextInputType.number,
                            inputFormatters: [ThousandsSeparatorFormatter()],
                            textAlign: TextAlign.center,
                            onChanged: (_) {
                              if (_amountError != null) setState(() => _amountError = null);
                            },
                            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: accent),
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: accent.withValues(alpha: 0.35),
                              ),
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                          ),
                        ),
                        Text(
                          'đ',
                          style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: accent),
                        ),
                      ],
                    ),
                    if (_amountError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _amountError!,
                        style: const TextStyle(fontSize: 12, color: AppColors.error),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Danh mục',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _categories.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat.label;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat.label),
                    child: Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryTeal : AppColors.lightMint,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            cat.icon,
                            color: isSelected ? Colors.white : AppColors.primaryTeal,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cat.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.textSecondary),
                      title: const Text('Ví', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedWallet,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 20),
                        ],
                      ),
                      onTap: _pickWallet,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
                    ListTile(
                      leading: const Icon(Icons.calendar_today_outlined, color: AppColors.textSecondary),
                      title: const Text('Ngày', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _dateLabel,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 20),
                        ],
                      ),
                      onTap: _pickDate,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
                    ListTile(
                      leading: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
                      title: const Text('Ghi chú', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      trailing: SizedBox(
                        width: 170,
                        child: TextField(
                          controller: _noteController,
                          textAlign: TextAlign.end,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'Thêm ghi chú',
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () => _showComingSoon('Chụp ảnh'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.lightMint,
                          foregroundColor: AppColors.primaryTeal,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.camera_alt_outlined, size: 20),
                        label: const Text('Chụp ảnh', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () => _showComingSoon('Quét hóa đơn'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.lightMint,
                          foregroundColor: AppColors.primaryTeal,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.receipt_long_outlined, size: 20),
                        label: const Text('Quét hóa đơn', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              PrimaryButton(
                text: _isEditing ? 'Cập nhật giao dịch' : 'Lưu giao dịch',
                onPressed: _handleSave,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
