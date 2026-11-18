import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../controllers/transaction_controller.dart';
import '../widgets/custom_button.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final TransactionController _controller = TransactionController();
  final _noteController = TextEditingController(text: 'Ăn trưa cơm tấm');
  final _amountController = TextEditingController(text: '45.000');

  bool _isExpense = true;
  String _selectedCategory = 'Ăn uống';
  final String _selectedWallet = 'Tiền mặt';
  final DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  final List<(String label, IconData icon)> _categories = const [
    ('Ăn uống', Icons.local_cafe_outlined),
    ('Di chuyển', Icons.directions_car_outlined),
    ('Mua sắm', Icons.shopping_bag_outlined),
    ('Hóa đơn', Icons.bolt_outlined),
    ('Giải trí', Icons.sports_esports_outlined),
    ('Học tập', Icons.school_outlined),
    ('Sức khỏe', Icons.favorite_border_rounded),
    ('Khác', Icons.more_horiz_rounded),
  ];

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final rawAmount = _amountController.text.replaceAll('.', '').replaceAll(',', '');
    final amount = double.tryParse(rawAmount) ?? 45000.0;

    setState(() => _isLoading = true);

    try {
      await _controller.addTransaction(
        title: _noteController.text.trim().isEmpty ? _selectedCategory : _noteController.text.trim(),
        amount: amount,
        isExpense: _isExpense,
        category: _selectedCategory,
        wallet: _selectedWallet,
        date: _selectedDate,
        note: _noteController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Thêm giao dịch',
          style: TextStyle(
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
                        onTap: () => setState(() => _isExpense = true),
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
                        onTap: () => setState(() => _isExpense = false),
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
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Số tiền',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IntrinsicWidth(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEF4444),
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                          ),
                        ),
                        const Text(
                          'đ',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Category Selection Header
              const Text(
                'Danh mục',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),

              // Category Grid (8 items)
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
                  final isSelected = _selectedCategory == cat.$1;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat.$1),
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
                            cat.$2,
                            color: isSelected ? Colors.white : AppColors.primaryTeal,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cat.$1,
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

              // Form Details Container
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
                      trailing: const Text('Tiền mặt', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      onTap: () {},
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
                    ListTile(
                      leading: const Icon(Icons.calendar_today_outlined, color: AppColors.textSecondary),
                      title: const Text('Ngày', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      trailing: const Text('Hôm nay, 04/11', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      onTap: () {},
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
                    ListTile(
                      leading: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
                      title: const Text('Ghi chú', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      trailing: SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _noteController,
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          decoration: const InputDecoration(
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

              // Action buttons (Chụp ảnh & Quét hóa đơn)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.lightMint,
                          foregroundColor: AppColors.primaryTeal,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.lightMint,
                          foregroundColor: AppColors.primaryTeal,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.receipt_long_outlined, size: 20),
                        label: const Text('Quét hóa đơn', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Primary Teal Button "Lưu giao dịch"
              PrimaryButton(
                text: 'Lưu giao dịch',
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
