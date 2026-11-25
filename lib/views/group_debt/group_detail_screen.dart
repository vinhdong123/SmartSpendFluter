import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/group_debt_controller.dart';
import '../../models/group_models.dart';
import '../widgets/common_widgets.dart';
import '../widgets/ui_kit.dart';
import 'add_group_expense_screen.dart';
import 'group_balance_screen.dart';
import 'invite_member_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final GroupDebtController _controller = GroupDebtController();
  GroupDetail? _group;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = await _controller.fetchGroup(widget.groupId);
    if (!mounted) return;
    setState(() {
      _group = g;
      _loading = false;
    });
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    _load();
  }

  Future<void> _deleteExpense(GroupExpenseModel e) async {
    final ok = await confirmDialog(
      context,
      title: 'Xóa khoản chi "${e.description}"?',
      message: 'Công nợ của nhóm sẽ được tính lại.',
      confirmLabel: 'Xóa',
      destructive: true,
    );
    if (!ok) return;
    await runGuarded(context, () => _controller.deleteGroupExpense(e.id));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final g = _group;
    if (_loading || g == null) {
      return SubPage(
        title: 'Nhóm',
        child: _loading
            ? const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            : const OutlineCard(child: EmptyState(icon: Icons.groups_outlined, message: 'Không tìm thấy nhóm này')),
      );
    }
    final owe = g.myBalance < 0;
    return SubPage(
      title: g.name,
      actions: [SquareIconButton(icon: Icons.person_add_alt_outlined, onTap: () => _push(InviteMemberScreen(groupId: g.id)))],
      bottom: BottomPrimary(
        text: 'Thêm chi phí nhóm',
        onPressed: g.members.length < 2
            ? () => showSnack(context, 'Nhóm cần ít nhất 2 thành viên. Hãy mời thêm người.')
            : () => _push(AddGroupExpenseScreen(group: g)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tổng chi phí · ${g.members.length} thành viên',
                    style: const TextStyle(fontSize: 14, color: Color(0xCCFFFFFF))),
                const SizedBox(height: 6),
                Text(formatVND(g.totalExpense),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          InfoBanner(
            icon: owe ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
            tone: owe ? BannerTone.danger : BannerTone.success,
            title: owe
                ? 'Bạn đang nợ ${formatVND(-g.myBalance)}'
                : g.myBalance > 0
                    ? 'Bạn sẽ nhận lại ${formatVND(g.myBalance)}'
                    : 'Công nợ đã cân bằng',
            subtitle: 'Xem chi tiết & cân đối công nợ',
            onTap: () => _push(GroupBalanceScreen(groupId: g.id)),
          ),
          const SectionTitle('Thành viên'),
          ListCard(
            children: [
              for (final m in g.members)
                ListRow(
                  leading: const IconBadge(icon: Icons.person_outline_rounded, size: 48),
                  title: m.isMe ? 'Bạn' : m.name,
                  trailing: Builder(builder: (_) {
                    final b = g.balances[m.id] ?? 0;
                    return Text(
                      b == 0 ? 'Cân bằng' : (b > 0 ? '+${formatVND(b)}' : formatVND(b)),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: b == 0 ? AppColors.textSecondary : (b > 0 ? AppColors.income : AppColors.expense),
                      ),
                    );
                  }),
                ),
            ],
          ),
          const SectionTitle('Các khoản chi'),
          if (g.expenses.isEmpty)
            const OutlineCard(child: Text('Chưa có khoản chi nào.', style: TextStyle(color: AppColors.textSecondary)))
          else
            ListCard(
              children: [
                for (final e in g.expenses)
                  ListRow(
                    onTap: () => _deleteExpense(e),
                    leading: const IconBadge(icon: Icons.receipt_long_outlined, size: 48),
                    title: e.description,
                    subtitle: '${g.memberName(e.paidByMemberId)} trả · ${formatDayMonth(e.date)}',
                    trailing: Text(formatVND(e.amount),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ),
              ],
            ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Chạm vào khoản chi để xóa', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
