import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../models/transaction_model.dart';
import '../../controllers/transaction_controller.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TransactionController _controller = TransactionController();
  final _searchController = TextEditingController();

  List<TransactionModel> _allTransactions = [];
  List<TransactionModel> _filteredTransactions = [];
  bool _isLoading = true;
  String? _selectedCategoryFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final list = await _controller.fetchTransactions();
    if (!mounted) return;
    setState(() {
      _allTransactions = list;
      _filteredTransactions = list;
      _isLoading = false;
    });
  }

  void _onSearchChanged() {
    setState(() {
      _filteredTransactions = _controller.filterTransactions(
        transactions: _allTransactions,
        searchQuery: _searchController.text,
        categoryFilter: _selectedCategoryFilter,
      );
    });
  }

  Map<String, List<TransactionModel>> _groupTransactionsByDate() {
    final Map<String, List<TransactionModel>> grouped = {};

    for (final tx in _filteredTransactions) {
      final now = DateTime.now();
      String dateKey;
      if (tx.date.year == now.year && tx.date.month == now.month && tx.date.day == now.day) {
        dateKey = 'Hôm nay · ${tx.date.day.toString().padLeft(2, '0')}/${tx.date.month.toString().padLeft(2, '0')}';
      } else {
        dateKey = '${tx.date.day.toString().padLeft(2, '0')}/${tx.date.month.toString().padLeft(2, '0')}';
      }

      grouped.putIfAbsent(dateKey, () => []).add(tx);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedData = _groupTransactionsByDate();

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primaryTeal,
          child: Column(
            children: [
              // Header Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Lịch sử',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search_rounded, color: AppColors.textPrimary),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),

              // Search Input Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm theo ghi chú, danh mục...',
                    hintStyle: const TextStyle(fontSize: 14, color: AppColors.textHint),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.primaryTeal, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _buildFilterChip('Tháng 11', isSelected: true),
                    const SizedBox(width: 8),
                    _buildFilterChip('Tất cả ví'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Danh mục'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Transactions List grouped by date
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primaryTeal),
                      )
                    : _filteredTransactions.isEmpty
                        ? const Center(
                            child: Text(
                              'Không tìm thấy giao dịch nào',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            itemCount: groupedData.keys.length,
                            itemBuilder: (context, index) {
                              final dateHeader = groupedData.keys.elementAt(index);
                              final txList = groupedData[dateHeader]!;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                                    child: Text(
                                      dateHeader,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Column(
                                      children: [
                                        for (int i = 0; i < txList.length; i++) ...[
                                          _buildHistoryTile(txList[i]),
                                          if (i < txList.length - 1)
                                            const Divider(height: 1, indent: 64, color: AppColors.border),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.lightMint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryTeal,
        ),
      ),
    );
  }

  Widget _buildHistoryTile(TransactionModel tx) {
    final amountColor = tx.isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.lightMint,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          !tx.isExpense ? Icons.attach_money_rounded : tx.categoryIcon,
          color: AppColors.primaryTeal,
          size: 22,
        ),
      ),
      title: Text(
        tx.title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        '${tx.category} · ${tx.wallet}',
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: Text(
        tx.formattedAmount,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: amountColor,
        ),
      ),
    );
  }
}
