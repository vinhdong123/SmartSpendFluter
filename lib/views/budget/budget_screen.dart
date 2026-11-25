import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/budget_controller.dart';
import '../../models/budget_models.dart';
import '../goals/savings_goals_screen.dart';
import '../widgets/common_widgets.dart';
import '../widgets/ui_kit.dart';
import 'budget_detail_screen.dart';
import 'budget_form_screen.dart';

class BudgetScreen extends StatefulWidget {
  final VoidCallback? onChanged;
  const BudgetScreen({super.key, this.onChanged});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final BudgetController _controller = BudgetController();
  BudgetOverview? _overview;
  int _period = 1;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await _controller.fetchOverview(_period);
      if (!mounted) return;
      setState(() {
        _overview = o;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Không tải được ngân sách: $e', isError: true);
    }
  }

  String get _periodLabel {
    final now = DateTime.now();
    switch (_period) {
      case 0:
        return 'tuần này';
      case 2:
        return 'năm ${now.year}';
      default:
        return 'tháng ${now.month}';
    }
  }

  Future<void> _push(Widget page) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => page));
    if (changed == true) widget.onChanged?.call();
    _load();
  }

  Future<void> _editTotal() async {
    if (_period != 1) {
      showSnack(context, 'Chuyển sang tab Tháng để chỉnh hạn mức tổng.');
      return;
    }
    final o = _overview;
    final amount = await showAmountDialog(
      context,
      title: 'Hạn mức chi tiêu tháng',
      initial: o != null && o.exists ? o.totalLimit : null,
      confirmLabel: 'Lưu',
    );
    if (amount == null) return;
    if (o != null && amount < o.items.fold<int>(0, (s, e) => s + e.limit)) {
      if (mounted) showSnack(context, 'Hạn mức tổng không được nhỏ hơn tổng hạn mức các danh mục.', isError: true);
      return;
    }
    await _controller.saveTotalLimit(amount);
    widget.onChanged?.call();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final o = _overview;
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
                    child: Text('Ngân sách',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  ),
                  SquareIconButton(icon: Icons.add_rounded, onTap: () => _push(const BudgetFormScreen())),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedTabs(
                labels: const ['Tuần', 'Tháng', 'Năm'],
                selected: _period,
                onChanged: (i) {
                  setState(() => _period = i);
                  _load();
                },
              ),
            ),
            Expanded(
              child: _loading || o == null
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: [
                          if (!o.exists && o.items.isEmpty) _emptyState() else ...[
                            _summary(o),
                            const SizedBox(height: 14),
                            for (final item in o.items) ...[_itemCard(item), const SizedBox(height: 12)],
                            if (o.items.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text('Chưa đặt hạn mức cho danh mục nào. Bấm + để thêm.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppColors.textSecondary)),
                              ),
                          ],
                          const SizedBox(height: 4),
                          _goalsRow(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return OutlineCard(
      child: Column(
        children: [
          const EmptyState(icon: Icons.account_balance_wallet_outlined, message: 'Chưa có ngân sách cho kỳ này'),
          TonalButton2(label: 'Đặt ngân sách', onTap: () => _push(const BudgetFormScreen())),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              final ok = await _controller.copyFromPreviousMonth();
              if (!mounted) return;
              showSnack(context, ok ? 'Đã sao chép ngân sách từ tháng trước' : 'Tháng trước chưa có ngân sách để sao chép');
              if (ok) {
                widget.onChanged?.call();
                _load();
              }
            },
            child: const Text('Sao chép từ tháng trước', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _summary(BudgetOverview o) {
    final over = o.totalSpent > o.totalLimit && o.totalLimit > 0;
    final remaining = o.remaining;
    return GestureDetector(
      onTap: _editTotal,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Đã chi / Hạn mức $_periodLabel', style: const TextStyle(fontSize: 14, color: Color(0xCCFFFFFF))),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('${formatVND(o.totalSpent)} / ${formatVND(o.totalLimit)}',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            const SizedBox(height: 14),
            AppProgressBar(
              value: o.totalLimit <= 0 ? 0 : o.totalSpent / o.totalLimit,
              color: over ? const Color(0xFFFF8F8F) : AppColors.accent,
              background: AppColors.primary100,
              height: 10,
            ),
            const SizedBox(height: 12),
            Text(
              over ? 'Đã vượt ${formatVND(-remaining)} · ${o.percent}%' : 'Còn lại ${formatVND(remaining)} · ${(100 - o.percent).clamp(0, 100)}%',
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemCard(BudgetItemModel item) {
    final over = item.isOver;
    final warn = item.isWarning;
    final textColor = over ? AppColors.expense : (warn ? AppColors.warning700 : AppColors.primary);
    return OutlineCard(
      onTap: () => _push(BudgetDetailScreen(item: item)),
      child: Column(
        children: [
          Row(
            children: [
              IconBadge(
                icon: item.icon,
                size: 48,
                color: over ? AppColors.expense : (warn ? AppColors.warning700 : AppColors.primary),
                background: over ? AppColors.expense50 : (warn ? AppColors.warning50 : AppColors.primary100),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(item.label,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
              Text('${item.percent}%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
            ],
          ),
          const SizedBox(height: 12),
          AppProgressBar(
            value: item.limit <= 0 ? 0 : item.spent / item.limit,
            color: budgetColor(item.percent, over: over),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('${formatVND(item.spent)} / ${formatVND(item.limit)}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _goalsRow() {
    return GestureDetector(
      onTap: () => _push(const SavingsGoalsScreen()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(color: AppColors.savings50, borderRadius: BorderRadius.circular(16)),
        child: const Row(
          children: [
            Icon(Icons.track_changes_rounded, color: AppColors.savings600),
            SizedBox(width: 12),
            Expanded(
              child: Text('Mục tiêu tiết kiệm',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Nút chính nhỏ gọn dùng trong thẻ trống.
class TonalButton2 extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const TonalButton2({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
}
