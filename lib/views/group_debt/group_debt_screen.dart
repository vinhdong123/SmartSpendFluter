import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/group_debt_controller.dart';
import '../../models/debt_model.dart';
import '../../models/group_models.dart';
import '../widgets/common_widgets.dart';
import '../widgets/custom_button.dart';
import '../widgets/ui_kit.dart';
import 'add_debt_screen.dart';
import 'add_group_expense_screen.dart';
import 'create_group_screen.dart';
import 'group_balance_screen.dart';
import 'group_detail_screen.dart';
import 'pay_debt_screen.dart';

class GroupDebtScreen extends StatefulWidget {
  const GroupDebtScreen({super.key});

  @override
  State<GroupDebtScreen> createState() => _GroupDebtScreenState();
}

class _GroupDebtScreenState extends State<GroupDebtScreen> {
  final GroupDebtController _controller = GroupDebtController();
  int _tab = 0; // 0: Nhóm, 1: Khoản nợ
  bool _loading = true;
  List<GroupDetail> _groups = [];
  List<DebtModel> _debts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool pull = true}) async {
    try {
      final groups = await _controller.fetchGroups();
      final debts = await _controller.fetchDebts();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _debts = debts;
        _loading = false;
      });
      if (pull && _controller.canShareGroups) {
        final r = await _controller.syncGroups();
        if (!mounted) return;
        if (r.error != null) {
          if (!r.error!.contains('kết nối')) showSnack(context, 'Chưa đồng bộ được nhóm: ${r.error}', isError: true);
        } else if (r.changed) {
          _load(pull: false);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Không tải được dữ liệu: $e', isError: true);
    }
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    _load(pull: false);
  }

  void _onAdd() => _push(_tab == 0 ? const CreateGroupScreen() : const AddDebtScreen());

  Future<void> _addExpense() async {
    if (_groups.isEmpty) {
      showSnack(context, 'Hãy tạo nhóm trước khi thêm chi phí');
      return;
    }
    var group = _groups.first;
    if (_groups.length > 1) {
      final picked = await showPickerSheet<GroupDetail>(
        context,
        title: 'Chọn nhóm',
        options: [for (final g in _groups) PickerOption(g.name, g, icon: Icons.groups_outlined)],
      );
      if (picked == null) return;
      group = picked.value;
    }
    if (group.members.length < 2) {
      showSnack(context, 'Nhóm cần ít nhất 2 thành viên. Hãy mời thêm người.');
      _push(GroupDetailScreen(groupId: group.id));
      return;
    }
    _push(AddGroupExpenseScreen(group: group));
  }

  @override
  Widget build(BuildContext context) {
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
                    child: Text('Nhóm & Nợ',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  ),
                  SquareIconButton(icon: Icons.add_rounded, onTap: _onAdd),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedTabs(
                labels: const ['Nhóm', 'Khoản nợ'],
                selected: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        children: _tab == 0 ? _groupTab() : _debtTab(),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: PrimaryButton(
                text: _tab == 0 ? 'Thêm chi phí nhóm' : 'Thêm khoản nợ',
                onPressed: _tab == 0 ? _addExpense : () => _push(const AddDebtScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Nhóm ----------------

  List<Widget> _groupTab() {
    if (_groups.isEmpty) {
      return [
        OutlineCard(
          child: EmptyState(
            icon: Icons.groups_outlined,
            message: 'Chưa có nhóm nào. Tạo nhóm để chia tiền chuyến đi, ăn uống cùng bạn bè.',
            actionLabel: 'Tạo nhóm',
            onAction: () => _push(const CreateGroupScreen()),
          ),
        ),
      ];
    }
    final first = _groups.first;
    return [
      for (final g in _groups) ...[_groupCard(g), const SizedBox(height: 12)],
      SectionTitle(_groups.length > 1 ? 'Công nợ nhóm · ${first.name}' : 'Công nợ nhóm'),
      if (first.suggestions.isEmpty)
        const OutlineCard(
          child: Text('Chưa có công nợ nào cần cân đối.', style: TextStyle(color: AppColors.textSecondary)),
        )
      else
        ListCard(
          children: [
            for (final s in first.suggestions)
              ListRow(
                onTap: () => _push(GroupBalanceScreen(groupId: first.id)),
                leading: const IconBadge(icon: Icons.person_outline_rounded, size: 48),
                title: '${s.fromName} → ${s.toName}',
                subtitle: first.name,
                trailing: Text(
                  formatVND(s.amount),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: s.fromId == first.me?.id
                        ? AppColors.expense
                        : (s.toId == first.me?.id ? AppColors.income : AppColors.textPrimary),
                  ),
                ),
              ),
          ],
        ),
    ];
  }

  Widget _groupCard(GroupDetail g) {
    final me = g.me;
    final mine = g.suggestions.where((s) => s.fromId == me?.id).toList();
    final owe = g.myBalance < 0;
    final get = g.myBalance > 0;
    return OutlineCard(
      onTap: () => _push(GroupDetailScreen(groupId: g.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(icon: Icons.groups_outlined, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('${g.members.length} thành viên',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 12),
          Text('Tổng chi phí: ${formatVND(g.totalExpense)}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          InfoBanner(
            icon: owe ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
            tone: owe ? BannerTone.danger : BannerTone.success,
            title: owe
                ? 'Bạn đang nợ ${formatVND(-g.myBalance)}'
                : get
                    ? 'Bạn sẽ nhận lại ${formatVND(g.myBalance)}'
                    : 'Công nợ đã cân bằng',
            subtitle: owe && mine.isNotEmpty ? 'Trả cho ${mine.first.toName} · cân đối công nợ' : null,
          ),
        ],
      ),
    );
  }

  // ---------------- Khoản nợ ----------------

  List<Widget> _debtTab() {
    final owe = _debts.where((d) => d.isBorrowed).fold<int>(0, (s, d) => s + d.remaining);
    final lent = _debts.where((d) => !d.isBorrowed).fold<int>(0, (s, d) => s + d.remaining);
    return [
      Row(
        children: [
          Expanded(child: StatCard(label: 'Bạn nợ', value: formatVND(owe), valueColor: AppColors.expense)),
          const SizedBox(width: 12),
          Expanded(child: StatCard(label: 'Cho vay', value: formatVND(lent), valueColor: AppColors.income)),
        ],
      ),
      const SizedBox(height: 14),
      if (_debts.isEmpty)
        OutlineCard(
          child: EmptyState(
            icon: Icons.handshake_outlined,
            message: 'Chưa có khoản nợ hay cho vay nào',
            actionLabel: 'Thêm khoản nợ',
            onAction: () => _push(const AddDebtScreen()),
          ),
        )
      else
        ListCard(
          children: [
            for (final d in _debts)
              ListRow(
                onTap: () => _push(PayDebtScreen(debt: d)),
                leading: IconBadge(
                  icon: d.isSettled ? Icons.check_rounded : Icons.person_outline_rounded,
                  size: 48,
                  color: d.isSettled ? AppColors.primary : (d.isBorrowed ? AppColors.expense : AppColors.income),
                  background: d.isSettled ? AppColors.primary100 : (d.isBorrowed ? AppColors.expense50 : AppColors.income50),
                ),
                title: d.isBorrowed ? 'Nợ ${d.counterparty}' : 'Cho ${d.counterparty} vay',
                subtitle: d.isSettled
                    ? 'Đã tất toán'
                    : '${d.dueOn == null ? 'Không có hạn' : 'Hạn ${formatDayMonth(d.dueOn!)}'} · còn ${formatVND(d.remaining)}',
                trailing: Text(
                  d.isSettled ? formatVND(0) : (d.isBorrowed ? 'Đang nợ' : 'Cho vay'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: d.isSettled ? AppColors.textPrimary : (d.isBorrowed ? AppColors.expense : AppColors.income),
                  ),
                ),
              ),
          ],
        ),
    ];
  }
}
