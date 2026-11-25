import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/wallet_goal_controller.dart';
import '../../models/goal_model.dart';
import '../../models/wallet_model.dart';
import '../widgets/common_widgets.dart';
import '../widgets/ui_kit.dart';

IconData goalIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('du lịch') || n.contains('du lich')) return Icons.public_rounded;
  if (n.contains('khẩn cấp') || n.contains('khan cap') || n.contains('dự phòng')) return Icons.favorite_border_rounded;
  return Icons.track_changes_rounded;
}

class SavingsGoalsScreen extends StatefulWidget {
  const SavingsGoalsScreen({super.key});

  @override
  State<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends State<SavingsGoalsScreen> {
  final GoalController _controller = GoalController();
  List<SavingsGoalModel> _goals = [];
  bool _loading = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final goals = await _controller.fetchGoals();
    if (!mounted) return;
    setState(() {
      _goals = goals;
      _loading = false;
    });
  }

  Future<void> _push(Widget page) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => page));
    if (changed == true) _changed = true;
    _load();
  }

  Future<void> _delete(SavingsGoalModel g) async {
    final ok = await confirmDialog(
      context,
      title: 'Xóa mục tiêu ${g.name}?',
      message: 'Các lần nạp tiền đã ghi nhận vẫn được giữ trong lịch sử giao dịch.',
      confirmLabel: 'Xóa',
      destructive: true,
    );
    if (!ok) return;
    await _controller.archive(g.id);
    _changed = true;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: SubPage(
        title: 'Mục tiêu tiết kiệm',
        actions: [SquareIconButton(icon: Icons.add_rounded, onTap: () => _push(const CreateGoalScreen()))],
        bottom: BottomPrimary(text: 'Tạo mục tiêu', onPressed: () => _push(const CreateGoalScreen())),
        child: _loading
            ? const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            : _goals.isEmpty
                ? const OutlineCard(
                    child: EmptyState(icon: Icons.track_changes_rounded, message: 'Chưa có mục tiêu nào. Hãy tạo mục tiêu đầu tiên!'),
                  )
                : Column(
                    children: [
                      for (final g in _goals) ...[
                        OutlineCard(
                          color: AppColors.savings50,
                          onTap: () => _push(DepositGoalScreen(goal: g)),
                          child: GestureDetector(
                            onLongPress: () => _delete(g),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(goalIcon(g.name), color: AppColors.savings600, size: 22),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(g.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                    ),
                                    Text('${g.percent}%',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.savings600)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                AppProgressBar(value: g.ratio, color: AppColors.savings600, background: AppColors.primary100),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text('${formatVND(g.saved)} / ${formatVND(g.target)}',
                                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                    ),
                                    if (g.deadline != null)
                                      Text('Hạn ${formatDate(g.deadline!)}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const Text('Chạm vào mục tiêu để nạp tiền · Giữ để xóa',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
      ),
    );
  }
}

class CreateGoalScreen extends StatefulWidget {
  const CreateGoalScreen({super.key});

  @override
  State<CreateGoalScreen> createState() => _CreateGoalScreenState();
}

class _CreateGoalScreenState extends State<CreateGoalScreen> {
  final GoalController _controller = GoalController();
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

  String? get _hint {
    final target = parseAmount(_target.text);
    final d = _deadline;
    if (target <= 0 || d == null) return null;
    final now = DateTime.now();
    final months = (d.year - now.year) * 12 + d.month - now.month;
    if (months <= 0) return 'Hạn hoàn thành nên sau tháng này';
    return 'Cần tiết kiệm khoảng ${formatVND((target / months).ceil())} mỗi tháng';
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final target = parseAmount(_target.text);
    setState(() {
      _nameError = name.isEmpty ? 'Nhập tên mục tiêu' : null;
      _targetError = target <= 0 ? 'Nhập số tiền lớn hơn 0' : null;
    });
    if (name.isEmpty || target <= 0) return;
    if (_deadline != null && _deadline!.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))) {
      showSnack(context, 'Hạn hoàn thành không được ở quá khứ', isError: true);
      return;
    }
    setState(() => _saving = true);
    final ok = await runGuarded(context, () => _controller.addGoal(name, target, _deadline));
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hint = _hint;
    return SubPage(
      title: 'Tạo mục tiêu',
      bottom: BottomPrimary(text: 'Lưu mục tiêu', onPressed: _save, loading: _saving),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LabeledInput(label: 'Tên mục tiêu', controller: _name, icon: Icons.track_changes_rounded, hint: 'Ví dụ: Mua xe máy', errorText: _nameError),
          LabeledInput(
            label: 'Số tiền cần đạt',
            controller: _target,
            icon: Icons.attach_money_rounded,
            amount: true,
            hint: '0',
            errorText: _targetError,
            onChanged: (_) => setState(() {}),
          ),
          LabeledSelect(
            label: 'Hạn hoàn thành',
            icon: Icons.calendar_today_outlined,
            value: _deadline == null ? 'Không đặt hạn' : formatDate(_deadline!),
            showChevron: false,
            onTap: () async {
              final d = await pickDate(context, _deadline ?? DateTime.now().add(const Duration(days: 180)), first: DateTime.now());
              if (d != null) setState(() => _deadline = d);
            },
          ),
          if (hint != null) ...[
            const SizedBox(height: 16),
            InfoBanner(icon: Icons.track_changes_rounded, tone: BannerTone.savings, title: 'Gợi ý', subtitle: hint),
          ],
        ],
      ),
    );
  }
}

class DepositGoalScreen extends StatefulWidget {
  final SavingsGoalModel goal;
  const DepositGoalScreen({super.key, required this.goal});

  @override
  State<DepositGoalScreen> createState() => _DepositGoalScreenState();
}

class _DepositGoalScreenState extends State<DepositGoalScreen> {
  final GoalController _controller = GoalController();
  final _amount = TextEditingController();
  List<WalletModel> _wallets = [];
  String? _wallet;
  DateTime _date = DateTime.now();
  bool _release = false;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller.fetchWallets().then((w) {
      if (mounted) {
        setState(() {
          _wallets = w;
          _wallet = w.isEmpty ? null : w.first.name;
        });
      }
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseAmount(_amount.text);
    final g = widget.goal;
    if (amount <= 0) {
      setState(() => _error = 'Nhập số tiền lớn hơn 0');
      return;
    }
    if (_release && amount > g.saved) {
      setState(() => _error = 'Chỉ có thể rút tối đa ${formatVND(g.saved)}');
      return;
    }
    if (_wallet == null) {
      showSnack(context, 'Chưa có ví nào', isError: true);
      return;
    }
    setState(() => _saving = true);
    final ok = await runGuarded(context, () => _controller.contribute(g.id, _wallet!, amount, _release, _date));
    if (!mounted) return;
    if (ok) {
      showSnack(context, _release ? 'Đã rút ${formatVND(amount)} về ví' : 'Đã nạp ${formatVND(amount)} vào mục tiêu');
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.goal;
    return SubPage(
      title: _release ? 'Rút tiền từ mục tiêu' : 'Nạp tiền vào mục tiêu',
      bottom: BottomPrimary(text: _release ? 'Rút tiền' : 'Nạp tiền', onPressed: _save, loading: _saving),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoBanner(
            icon: goalIcon(g.name),
            tone: BannerTone.savings,
            title: g.name,
            subtitle: 'Đã có ${formatVND(g.saved)} / ${formatVND(g.target)}',
          ),
          const SizedBox(height: 14),
          SegmentedTabs(
            labels: const ['Nạp thêm', 'Rút ra'],
            selected: _release ? 1 : 0,
            onChanged: (i) => setState(() {
              _release = i == 1;
              _error = null;
            }),
          ),
          LabeledInput(
            label: _release ? 'Số tiền rút' : 'Số tiền nạp',
            controller: _amount,
            icon: Icons.attach_money_rounded,
            amount: true,
            hint: '0',
            errorText: _error,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          LabeledSelect(
            label: _release ? 'Chuyển về ví' : 'Lấy từ ví',
            icon: Icons.account_balance_wallet_outlined,
            value: _wallet ?? '—',
            onTap: _wallets.length < 2
                ? null
                : () async {
                    final p = await showPickerSheet<String>(
                      context,
                      title: 'Chọn ví',
                      selected: _wallet,
                      options: [for (final w in _wallets) PickerOption(w.name, w.name, icon: w.icon)],
                    );
                    if (p != null) setState(() => _wallet = p.value);
                  },
          ),
          LabeledSelect(
            label: 'Ngày',
            icon: Icons.calendar_today_outlined,
            value: formatDate(_date),
            showChevron: false,
            onTap: () async {
              final d = await pickDate(context, _date, last: DateTime.now());
              if (d != null) setState(() => _date = d);
            },
          ),
        ],
      ),
    );
  }
}
