import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/group_debt_controller.dart';
import '../../models/group_models.dart';
import '../widgets/common_widgets.dart';
import '../widgets/ui_kit.dart';

/// Công nợ nhóm: đề xuất cân đối và ghi nhận thanh toán.
class GroupBalanceScreen extends StatefulWidget {
  final String groupId;
  const GroupBalanceScreen({super.key, required this.groupId});

  @override
  State<GroupBalanceScreen> createState() => _GroupBalanceScreenState();
}

class _GroupBalanceScreenState extends State<GroupBalanceScreen> {
  final GroupDebtController _controller = GroupDebtController();
  GroupDetail? _group;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = await _controller.fetchGroup(widget.groupId);
    if (mounted) setState(() => _group = g);
  }

  Future<void> _record() async {
    final g = _group;
    if (g == null || g.suggestions.isEmpty) return;
    var s = g.suggestions.first;
    if (g.suggestions.length > 1) {
      final picked = await showPickerSheet<SettlementSuggestion>(
        context,
        title: 'Ghi nhận khoản thanh toán nào?',
        options: [
          for (final x in g.suggestions) PickerOption('${x.fromName} → ${x.toName} · ${formatVND(x.amount)}', x),
        ],
      );
      if (picked == null) return;
      s = picked.value;
    }
    if (!mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'Ghi nhận thanh toán?',
      message: '${s.fromName} đã trả ${s.toName} ${formatVND(s.amount)}.',
      confirmLabel: 'Ghi nhận',
    );
    if (!ok || !mounted) return;
    final done = await runGuarded(context, () => _controller.settle(g.id, s));
    if (done && mounted) {
      showSnack(context, 'Đã ghi nhận thanh toán');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = _group;
    if (g == null) {
      return const SubPage(
        title: 'Công nợ nhóm',
        child: Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
      );
    }
    final me = g.me;
    final mine = g.suggestions.where((s) => s.fromId == me?.id).toList();
    final owe = g.myBalance < 0;
    final totalShares = g.totalExpense;
    return SubPage(
      title: 'Công nợ nhóm',
      bottom: BottomPrimary(text: 'Ghi nhận thanh toán', onPressed: g.suggestions.isEmpty ? null : _record),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoBanner(
            icon: owe ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
            tone: owe ? BannerTone.danger : BannerTone.success,
            title: owe
                ? 'Bạn đang nợ ${formatVND(-g.myBalance)}'
                : g.myBalance > 0
                    ? 'Bạn sẽ nhận lại ${formatVND(g.myBalance)}'
                    : 'Mọi người đã cân bằng',
            subtitle: owe && mine.isNotEmpty ? 'Đề xuất: trả ${mine.first.toName} ${formatVND(mine.first.amount)} là xong' : null,
          ),
          const SectionTitle('Cân đối công nợ'),
          if (g.suggestions.isEmpty)
            const OutlineCard(child: Text('Không còn khoản nào cần thanh toán.', style: TextStyle(color: AppColors.textSecondary)))
          else
            ListCard(
              children: [
                for (final s in g.suggestions)
                  ListRow(
                    leading: IconBadge(
                      icon: Icons.swap_horiz_rounded,
                      size: 48,
                      color: s.fromId == me?.id ? AppColors.expense : (s.toId == me?.id ? AppColors.income : AppColors.primary),
                      background: s.fromId == me?.id ? AppColors.expense50 : (s.toId == me?.id ? AppColors.income50 : AppColors.primary100),
                    ),
                    title: '${s.fromName} → ${s.toName}',
                    trailing: Text(formatVND(s.amount),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: s.fromId == me?.id ? AppColors.expense : (s.toId == me?.id ? AppColors.income : AppColors.textPrimary),
                        )),
                  ),
              ],
            ),
          const SizedBox(height: 14),
          InfoBanner(
            icon: Icons.check_rounded,
            tone: BannerTone.success,
            title: 'Tổng chi = tổng chia',
            subtitle: '${formatVND(totalShares)} đã được chia đủ cho ${g.members.length} người',
          ),
        ],
      ),
    );
  }
}
