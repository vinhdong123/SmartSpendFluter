import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/transaction_controller.dart';
import '../../models/transaction_model.dart';
import '../../models/tx_filter.dart';
import '../transaction/transaction_detail_screen.dart';
import '../widgets/common_widgets.dart';
import '../widgets/ui_kit.dart';
import 'search_filter_screen.dart';

class HistoryScreen extends StatefulWidget {
  final VoidCallback? onChanged;

  const HistoryScreen({super.key, this.onChanged});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TransactionController _controller = TransactionController();

  List<TransactionModel> _all = [];
  bool _loading = true;
  TxFilter _filter = TxFilter.thisMonth();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _controller.fetchTransactions();
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Không tải được dữ liệu: $e', isError: true);
    }
  }

  Future<void> _openFilter() async {
    final result = await Navigator.of(context).push<TxFilter>(
      MaterialPageRoute(builder: (_) => SearchFilterScreen(initial: _filter)),
    );
    if (result != null) setState(() => _filter = result);
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final months = [for (var i = 0; i < 12; i++) DateTime(now.year, now.month - i, 1)];
    final picked = await showPickerSheet<DateTime?>(
      context,
      title: 'Chọn tháng',
      selected: _filter.isMonthRange ? _filter.from : null,
      options: [
        const PickerOption<DateTime?>('Tất cả thời gian', null),
        for (final m in months) PickerOption<DateTime?>('Tháng ${m.month}/${m.year}', m),
      ],
    );
    if (picked == null) return;
    final m = picked.value;
    setState(() {
      _filter = m == null
          ? _filter.copyWith(clearRange: true)
          : _filter.copyWith(from: m, to: DateTime(m.year, m.month + 1, 0));
    });
  }

  Future<void> _openDetail(TransactionModel tx) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TransactionDetailScreen(transaction: tx)),
    );
    if (changed == true) {
      await _load();
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _controller.filterTransactions(_all, _filter);
    var income = 0.0, expense = 0.0;
    for (final t in list) {
      if (t.isExpense) {
        expense += t.amount;
      } else {
        income += t.amount;
      }
    }

    // Nhóm theo ngày (giữ thứ tự mới nhất trước).
    final groups = <String, List<TransactionModel>>{};
    for (final t in list) {
      groups.putIfAbsent(TransactionController.dayHeader(t.date), () => []).add(t);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Lịch sử',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  ),
                  SquareIconButton(icon: Icons.search_rounded, onTap: _openFilter, dot: _filter.query.isNotEmpty),
                  const SizedBox(width: 10),
                  SquareIconButton(
                    icon: Icons.filter_alt_outlined,
                    onTap: _openFilter,
                    dot: _filter.wallet != null || _filter.category != null,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('Tất cả', _filter.type == 0, () => setState(() => _filter = _filter.copyWith(type: 0))),
                    _chip('Chi tiêu', _filter.type == 1, () => setState(() => _filter = _filter.copyWith(type: 1))),
                    _chip('Thu nhập', _filter.type == 2, () => setState(() => _filter = _filter.copyWith(type: 2))),
                    _chip(_filter.rangeLabel, _filter.hasRange, _pickMonth, trailing: Icons.expand_more_rounded),
                  ],
                ),
              ),
            ),
            if (_filter.hasExtra)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    const Icon(Icons.filter_alt_outlined, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        [
                          if (_filter.query.trim().isNotEmpty) '"${_filter.query.trim()}"',
                          if (_filter.wallet != null) _filter.wallet!,
                          if (_filter.category != null) _filter.category!,
                        ].join(' · '),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _filter = TxFilter(from: _filter.from, to: _filter.to, type: _filter.type)),
                      child: const Text('Xóa lọc',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: StatCard(label: 'Thu', value: formatVND(income), valueColor: AppColors.income)),
                  const SizedBox(width: 12),
                  Expanded(child: StatCard(label: 'Chi', value: formatVND(expense), valueColor: AppColors.expense)),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : list.isEmpty
                      ? EmptyState(
                          icon: Icons.receipt_long_outlined,
                          message: _all.isEmpty ? 'Chưa có giao dịch nào' : 'Không có giao dịch phù hợp bộ lọc',
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                            children: [
                              for (final entry in groups.entries) ...[
                                SectionLabel(entry.key),
                                ListCard(
                                  children: [for (final t in entry.value) TxRow(tx: t, onTap: () => _openDetail(t))],
                                ),
                              ],
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, {IconData? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.primary100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textPrimary)),
              if (trailing != null) ...[
                const SizedBox(width: 2),
                Icon(trailing, size: 18, color: selected ? Colors.white : AppColors.textPrimary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
