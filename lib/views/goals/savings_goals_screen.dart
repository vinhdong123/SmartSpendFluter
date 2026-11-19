import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/wallet_goal_controller.dart';
import '../../models/goal_model.dart';
import '../../models/wallet_model.dart';
import '../widgets/common_widgets.dart';

class SavingsGoalsScreen extends StatefulWidget {
  const SavingsGoalsScreen({super.key});

  @override
  State<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends State<SavingsGoalsScreen> {
  final GoalController _controller = GoalController();
  List<SavingsGoalModel> _goals = [];
  List<WalletModel> _wallets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final goals = await _controller.fetchGoals();
    final wallets = await _controller.fetchWallets();
    if (!mounted) return;
    setState(() {
      _goals = goals;
      _wallets = wallets;
      _isLoading = false;
    });
  }

  Future<void> _addGoal() async {
    final created = await showAppSheet<bool>(
      context,
      builder: (ctx) => _GoalForm(controller: _controller),
    );
    if (created == true) _load();
  }

  Future<void> _contribute(SavingsGoalModel goal) async {
    final done = await showAppSheet<bool>(
      context,
      builder: (ctx) => _ContributeForm(controller: _controller, goal: goal, wallets: _wallets),
    );
    if (done == true) _load();
  }

  Future<void> _archive(SavingsGoalModel goal) async {
    final ok = await confirmDialog(
      context,
      title: 'Xóa mục tiêu',
      message: 'Xóa mục tiêu "${goal.name}"? Các khoản đã dành sẽ không còn được tính.',
      confirmLabel: 'Xóa',
      destructive: true,
    );
    if (!ok) return;
    await _controller.archive(goal.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Mục tiêu tiết kiệm'),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: _addGoal),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primaryTeal,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  if (_goals.isEmpty)
                    EmptyState(
                      icon: Icons.track_changes_outlined,
                      message: 'Chưa có mục tiêu nào.\nĐặt mục tiêu để theo dõi tiến độ tiết kiệm.',
                      actionLabel: 'Tạo mục tiêu',
                      onAction: _addGoal,
                    )
                  else
                    for (final g in _goals) _buildGoalCard(g),
                ],
              ),
            ),
    );
  }

  Widget _buildGoalCard(SavingsGoalModel g) {
    final color = g.isDone ? AppColors.success : AppColors.primaryTeal;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    g.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
                Text(
                  '${g.percent}%',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary, size: 20),
                  onSelected: (v) {
                    if (v == 'delete') _archive(g);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Text('Xóa mục tiêu')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: g.ratio,
                minHeight: 8,
                backgroundColor: AppColors.lightMint,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${formatVND(g.saved)} / ${formatVND(g.target)}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            if (g.deadline != null) ...[
              const SizedBox(height: 4),
              Text(
                'Hạn: ${formatDate(g.deadline!)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _contribute(g),
                icon: const Icon(Icons.savings_outlined, size: 18, color: AppColors.primaryTeal),
                label: const Text(
                  'Nạp / rút tiền',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryTeal),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalForm extends StatefulWidget {
  final GoalController controller;
  const _GoalForm({required this.controller});

  @override
  State<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<_GoalForm> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  DateTime? _deadline;
  String? _nameError;
  String? _targetError;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await pickDate(
      context,
      initial: _deadline ?? DateTime(now.year, now.month + 1, now.day),
      first: now,
      last: DateTime(now.year + 20),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final target = parseAmount(_target.text);
    setState(() {
      _nameError = name.isEmpty ? 'Vui lòng nhập tên mục tiêu' : null;
      _targetError = target <= 0 ? 'Vui lòng nhập số tiền mục tiêu' : null;
    });
    if (_nameError != null || _targetError != null) return;

    setState(() => _saving = true);
    try {
      await widget.controller.addGoal(name, target, _deadline);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetHeader('Mục tiêu mới'),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: 'Tên mục tiêu (VD: Mua laptop)', errorText: _nameError),
        ),
        const SizedBox(height: 12),
        AmountField(controller: _target, label: 'Số tiền mục tiêu', errorText: _targetError),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined, color: AppColors.textSecondary),
          title: Text(_deadline == null ? 'Thêm hạn hoàn thành (tuỳ chọn)' : 'Hạn: ${formatDate(_deadline!)}'),
          trailing: _deadline == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => setState(() => _deadline = null),
                ),
          onTap: _pickDeadline,
        ),
        SheetSubmit(label: 'Tạo mục tiêu', onPressed: _save, isLoading: _saving),
      ],
    );
  }
}

class _ContributeForm extends StatefulWidget {
  final GoalController controller;
  final SavingsGoalModel goal;
  final List<WalletModel> wallets;

  const _ContributeForm({required this.controller, required this.goal, required this.wallets});

  @override
  State<_ContributeForm> createState() => _ContributeFormState();
}

class _ContributeFormState extends State<_ContributeForm> {
  final _amount = TextEditingController();
  bool _isRelease = false;
  late String _wallet = widget.wallets.isEmpty ? '' : widget.wallets.first.name;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseAmount(_amount.text);
    if (amount <= 0) {
      setState(() => _error = 'Vui lòng nhập số tiền lớn hơn 0');
      return;
    }
    if (_isRelease && amount > widget.goal.saved) {
      setState(() => _error = 'Chỉ có thể rút tối đa ${formatVND(widget.goal.saved)}');
      return;
    }
    if (_wallet.isEmpty) {
      setState(() => _error = 'Chưa có ví nào');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await widget.controller.contribute(widget.goal.id, _wallet, amount, _isRelease);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SheetHeader(widget.goal.name),
        SegmentedTabs(
          labels: const ['Nạp thêm', 'Rút ra'],
          selected: _isRelease ? 1 : 0,
          onChanged: (i) => setState(() => _isRelease = i == 1),
        ),
        const SizedBox(height: 16),
        AmountField(controller: _amount, errorText: _error, autofocus: true),
        const SizedBox(height: 16),
        const Text('Từ ví', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        ChipSelector(
          options: [for (final w in widget.wallets) w.name],
          selected: _wallet,
          onSelected: (v) => setState(() => _wallet = v),
        ),
        SheetSubmit(label: _isRelease ? 'Rút khỏi mục tiêu' : 'Nạp vào mục tiêu', onPressed: _save, isLoading: _saving),
      ],
    );
  }
}
