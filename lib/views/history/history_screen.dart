import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/categories.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/transaction_controller.dart';
import '../../models/transaction_model.dart';
import '../../models/wallet_model.dart';
import '../transaction/add_transaction_screen.dart';
import '../widgets/common_widgets.dart';

class HistoryScreen extends StatefulWidget {
  final VoidCallback? onChanged;

  const HistoryScreen({super.key, this.onChanged});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TransactionController _controller = TransactionController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  List<TransactionModel> _allTransactions = [];
  List<WalletModel> _wallets = [];
  bool _isLoading = true;

  DateTime? _monthFilter = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String? _walletFilter;
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final list = await _controller.fetchTransactions();
      final wallets = await _controller.fetchWallets();
      if (!mounted) return;
      setState(() {
        _allTransactions = list;
        _wallets = wallets;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showSnack(context, 'Không tải được dữ liệu: $e', isError: true);
    }
  }

  List<TransactionModel> get _filtered => _controller.filterTransactions(
        transactions: _allTransactions,
        searchQuery: _searchController.text,
        categoryFilter: _categoryFilter,
        walletFilter: _walletFilter,
        month: _monthFilter,
      );

  Map<String, List<TransactionModel>> _groupByDate(List<TransactionModel> list) {
    final grouped = <String, List<TransactionModel>>{};
    for (final tx in list) {
      grouped.putIfAbsent(friendlyDate(tx.date), () => []).add(tx);
    }
    return grouped;
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final months = [for (int i = 0; i < 12; i++) DateTime(now.year, now.month - i, 1)];
    final result = await showPickerSheet<DateTime?>(
      context,
      title: 'Chọn thời gian',
      selected: _monthFilter,
      options: [
        const PickerOption<DateTime?>('Tất cả thời gian', null),
        for (final m in months) PickerOption<DateTime?>('Tháng ${m.month}/${m.year}', m),
      ],
    );
    if (result != null) setState(() => _monthFilter = result.value);
  }

  Future<void> _pickWallet() async {
    final result = await showPickerSheet<String?>(
      context,
      title: 'Chọn ví',
      selected: _walletFilter,
      options: [
        const PickerOption<String?>('Tất cả ví', null),
        for (final w in _wallets) PickerOption<String?>(w.name, w.name, icon: w.icon),
      ],
    );
    if (result != null) setState(() => _walletFilter = result.value);
  }

  Future<void> _pickCategory() async {
    final result = await showPickerSheet<String?>(
      context,
      title: 'Chọn danh mục',
      selected: _categoryFilter,
      options: [
        const PickerOption<String?>('Tất cả danh mục', null),
        for (final label in Categories.allLabels)
          PickerOption<String?>(label, label, icon: Categories.iconOf(label)),
      ],
    );
    if (result != null) setState(() => _categoryFilter = result.value);
  }

  Future<void> _showActions(TransactionModel tx) async {
    final action = await showAppSheet<String>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetHeader(tx.title),
          Text(
            '${tx.formattedAmount} · ${tx.category} · ${tx.wallet}',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.edit_outlined, color: AppColors.primaryTeal),
            title: const Text('Chỉnh sửa'),
            onTap: () => Navigator.of(ctx).pop('edit'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            title: const Text('Xóa giao dịch', style: TextStyle(color: AppColors.error)),
            onTap: () => Navigator.of(ctx).pop('delete'),
          ),
        ],
      ),
    );
    if (!mounted) return;

    if (action == 'edit') {
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => AddTransactionScreen(editing: tx),
          fullscreenDialog: true,
        ),
      );
      if (changed == true) {
        await _loadData();
        widget.onChanged?.call();
      }
    } else if (action == 'delete') {
      final ok = await confirmDialog(
        context,
        title: 'Xóa giao dịch',
        message: 'Xóa "${tx.title}" (${tx.formattedAmount})? Thao tác này không thể hoàn tác.',
        confirmLabel: 'Xóa',
        destructive: true,
      );
      if (!ok || !mounted) return;
      try {
        await _controller.deleteTransaction(tx.id);
        await _loadData();
        widget.onChanged?.call();
        if (mounted) showSnack(context, 'Đã xóa giao dịch');
      } catch (e) {
        if (mounted) showSnack(context, 'Không thể xóa: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final groupedData = _groupByDate(filtered);
    final income = filtered.where((t) => !t.isExpense).fold<double>(0, (s, t) => s + t.amount);
    final expense = filtered.where((t) => t.isExpense).fold<double>(0, (s, t) => s + t.amount);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Lịch sử',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search_rounded, color: AppColors.textPrimary),
                    onPressed: () => _searchFocus.requestFocus(),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                decoration: InputDecoration(
                  hintText: 'Tìm theo ghi chú, danh mục...',
                  hintStyle: const TextStyle(fontSize: 14, color: AppColors.textHint),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: _searchController.clear,
                        ),
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

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildFilterChip(
                    _monthFilter == null ? 'Tất cả thời gian' : 'Tháng ${_monthFilter!.month}/${_monthFilter!.year}',
                    isActive: _monthFilter != null,
                    onTap: _pickMonth,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(_walletFilter ?? 'Tất cả ví', isActive: _walletFilter != null, onTap: _pickWallet),
                  const SizedBox(width: 8),
                  _buildFilterChip(_categoryFilter ?? 'Danh mục', isActive: _categoryFilter != null, onTap: _pickCategory),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (!_isLoading && filtered.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      'Thu ${formatVND(income)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Chi ${formatVND(expense)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFEF4444)),
                    ),
                    const Spacer(),
                    Text(
                      '${filtered.length} giao dịch',
                      style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.primaryTeal,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal))
                    : filtered.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              EmptyState(
                                icon: Icons.search_off_rounded,
                                message: _allTransactions.isEmpty
                                    ? 'Chưa có giao dịch nào'
                                    : 'Không tìm thấy giao dịch phù hợp',
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, {required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryTeal : AppColors.lightMint,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : AppColors.primaryTeal,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: isActive ? Colors.white : AppColors.primaryTeal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTile(TransactionModel tx) {
    final amountColor = tx.isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return ListTile(
      onTap: () => _showActions(tx),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.lightMint,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(tx.categoryIcon, color: AppColors.primaryTeal, size: 22),
      ),
      title: Text(
        tx.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      ),
      subtitle: Text(
        '${tx.category} · ${tx.wallet}',
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
      trailing: Text(
        tx.formattedAmount,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: amountColor),
      ),
    );
  }
}
