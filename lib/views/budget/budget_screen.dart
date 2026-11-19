import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/categories.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/budget_controller.dart';
import '../../models/budget_models.dart';
import '../goals/savings_goals_screen.dart';
import '../widgets/common_widgets.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final BudgetController _controller = BudgetController();
  int _selectedPeriod = 1; // 0: Tuần, 1: Tháng, 2: Năm
  bool _isLoading = true;
  BudgetOverview? _overview;

  static const _amber = Color(0xFFD97706);
  static const _amberBg = Color(0xFFFEF3C7);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await _controller.fetchOverview(_selectedPeriod);
      if (!mounted) return;
      setState(() {
        _overview = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showSnack(context, 'Không tải được dữ liệu: $e', isError: true);
    }
  }

  String get _periodWord => _selectedPeriod == 0 ? 'tuần' : (_selectedPeriod == 2 ? 'năm' : 'tháng');

  Future<void> _editTotal() async {
    final value = await showAmountDialog(
      context,
      title: 'Hạn mức chi tiêu tháng ${DateTime.now().month}',
      initial: _overview?.exists == true && _selectedPeriod == 1 ? _overview!.totalLimit : null,
    );
    if (value == null) return;
    await _controller.saveTotalLimit(value);
    _loadData();
  }

  Future<void> _copyPrevious() async {
    final ok = await _controller.copyFromPreviousMonth();
    if (!mounted) return;
    if (!ok) {
      showSnack(context, 'Tháng trước chưa có ngân sách để sao chép.');
      return;
    }
    _loadData();
  }

  Future<void> _addOrEditCategory({BudgetItemModel? item}) async {
    final used = {for (final i in _overview?.items ?? const <BudgetItemModel>[]) i.label};
    final saved = await showAppSheet<bool>(
      context,
      builder: (ctx) => _CategoryBudgetForm(
        controller: _controller,
        editing: item,
        usedLabels: used,
      ),
    );
    if (saved == true) _loadData();
  }

  Future<void> _removeCategory(BudgetItemModel item) async {
    final ok = await confirmDialog(
      context,
      title: 'Xóa ngân sách',
      message: 'Xóa ngân sách danh mục "${item.label}"?',
      confirmLabel: 'Xóa',
      destructive: true,
    );
    if (!ok) return;
    await _controller.deleteCategoryLimit(item.id);
    _loadData();
  }

  void _openItemMenu(BudgetItemModel item) {
    if (_selectedPeriod != 1) {
      showSnack(context, 'Chuyển sang tab Tháng để chỉnh sửa hạn mức.');
      return;
    }
    showAppSheet<void>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetHeader(item.label),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.edit_outlined, color: AppColors.primaryTeal),
            title: const Text('Đổi hạn mức'),
            onTap: () {
              Navigator.of(ctx).pop();
              _addOrEditCategory(item: item);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            title: const Text('Xóa', style: TextStyle(color: AppColors.error)),
            onTap: () {
              Navigator.of(ctx).pop();
              _removeCategory(item);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overview = _overview;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primaryTeal,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ngân sách',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add_rounded, color: AppColors.textPrimary, size: 20),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          if (_selectedPeriod != 1) {
                            showSnack(context, 'Chuyển sang tab Tháng để thêm ngân sách.');
                          } else if (overview?.exists != true) {
                            _editTotal();
                          } else {
                            _addOrEditCategory();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                SegmentedTabs(
                  labels: const ['Tuần', 'Tháng', 'Năm'],
                  selected: _selectedPeriod,
                  onChanged: (i) {
                    setState(() {
                      _selectedPeriod = i;
                      _isLoading = true;
                    });
                    _loadData();
                  },
                ),
                const SizedBox(height: 20),

                if (_isLoading || overview == null)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primaryTeal)),
                  )
                else if (!overview.exists)
                  _buildNoBudget(overview)
                else ...[
                  _buildTotalCard(overview),
                  if (_selectedPeriod != 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Text(
                        'Hạn mức $_periodWord được quy đổi từ ngân sách tháng.',
                        style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (overview.items.isEmpty)
                    AppCard(
                      child: EmptyState(
                        icon: Icons.category_outlined,
                        message: 'Chưa đặt ngân sách theo danh mục.',
                        actionLabel: 'Thêm danh mục',
                        onAction: () {
                          if (_selectedPeriod == 1) _addOrEditCategory();
                        },
                      ),
                    )
                  else
                    for (final item in overview.items) _buildItemCard(item),
                ],
                const SizedBox(height: 8),

                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SavingsGoalsScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.track_changes_outlined, color: Color(0xFF2563EB), size: 22),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Mục tiêu tiết kiệm',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoBudget(BudgetOverview overview) {
    return AppCard(
      child: Column(
        children: [
          EmptyState(
            icon: Icons.account_balance_wallet_outlined,
            message: 'Chưa có ngân sách tháng ${DateTime.now().month}.\n'
                'Đã chi tháng này: ${formatVND(overview.totalSpent)}',
            actionLabel: 'Đặt hạn mức tháng',
            onAction: () {
              if (_selectedPeriod == 1) {
                _editTotal();
              } else {
                showSnack(context, 'Chuyển sang tab Tháng để đặt ngân sách.');
              }
            },
          ),
          TextButton(
            onPressed: _copyPrevious,
            child: const Text(
              'Sao chép từ tháng trước',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(BudgetOverview o) {
    final ratio = o.totalLimit <= 0 ? 0.0 : (o.totalSpent / o.totalLimit).clamp(0.0, 1.0);
    final over = o.remaining < 0;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: _selectedPeriod == 1 ? _editTotal : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primaryTeal,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryTeal.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Đã chi / Hạn mức $_periodWord',
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 8),
            Text(
              '${formatVND(o.totalSpent)} / ${formatVND(o.totalLimit)}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                valueColor: AlwaysStoppedAnimation<Color>(over ? const Color(0xFFFCA5A5) : const Color(0xFFF59E0B)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              over
                  ? 'Vượt hạn mức ${formatVND(-o.remaining)}'
                  : 'Còn lại ${formatVND(o.remaining)} · ${100 - o.percent}%',
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(BudgetItemModel item) {
    final color = item.isOver ? AppColors.error : (item.isWarning ? _amber : AppColors.primaryTeal);
    final bg = item.isOver ? const Color(0xFFFEE2E2) : (item.isWarning ? _amberBg : AppColors.lightMint);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        radius: 18,
        onTap: () => _openItemMenu(item),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                  child: Icon(item.icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const Spacer(),
                Text(
                  '${item.percent}%',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: item.limit <= 0 ? (item.spent > 0 ? 1.0 : 0.0) : (item.spent / item.limit).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.lightMint,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${formatVND(item.spent)} / ${formatVND(item.limit)}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBudgetForm extends StatefulWidget {
  final BudgetController controller;
  final BudgetItemModel? editing;
  final Set<String> usedLabels;

  const _CategoryBudgetForm({
    required this.controller,
    required this.editing,
    required this.usedLabels,
  });

  @override
  State<_CategoryBudgetForm> createState() => _CategoryBudgetFormState();
}

class _CategoryBudgetFormState extends State<_CategoryBudgetForm> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.editing == null ? '' : formatNumber(widget.editing!.limit),
  );
  late String? _category = widget.editing?.label;
  String? _error;
  bool _saving = false;

  List<String> get _available => [
        for (final c in Categories.expense)
          if (!widget.usedLabels.contains(c.label) || c.label == widget.editing?.label) c.label,
      ];

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseAmount(_amount.text);
    if (_category == null) {
      setState(() => _error = 'Vui lòng chọn danh mục');
      return;
    }
    if (amount <= 0) {
      setState(() => _error = 'Vui lòng nhập hạn mức lớn hơn 0');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await widget.controller.saveCategoryLimit(_category!, amount);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, 'Lỗi: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _available;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SheetHeader(widget.editing == null ? 'Thêm ngân sách danh mục' : 'Đổi hạn mức'),
        if (options.isEmpty)
          const Text('Tất cả danh mục đã có ngân sách.', style: TextStyle(color: AppColors.textSecondary))
        else if (widget.editing == null) ...[
          const Text('Danh mục', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          ChipSelector(
            options: options,
            selected: _category,
            onSelected: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 16),
        ],
        AmountField(controller: _amount, label: 'Hạn mức tháng', errorText: _error),
        SheetSubmit(label: 'Lưu', onPressed: () {
            if (options.isNotEmpty) _save();
          }, isLoading: _saving),
      ],
    );
  }
}
