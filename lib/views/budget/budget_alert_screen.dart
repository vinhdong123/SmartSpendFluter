import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/budget_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../models/budget_models.dart';
import '../../models/notification_item.dart';
import '../../models/transaction_model.dart';
import '../goals/savings_goals_screen.dart';
import '../group_debt/pay_debt_screen.dart';
import '../settings/bill_reminders_screen.dart';
import '../widgets/custom_button.dart';
import '../widgets/ui_kit.dart';
import 'budget_form_screen.dart';
import 'budget_screen.dart';

/// Màn hình đích khi bấm vào một thông báo.
Widget alertPageFor(NotificationItem n) {
  switch (n.kind) {
    case NotifKind.budgetOver:
      return OverBudgetScreen(item: n.budget!);
    case NotifKind.budgetWarning:
      return BudgetAlertScreen(item: n.budget!);
    case NotifKind.bill:
      return const BillRemindersScreen();
    case NotifKind.debt:
      return PayDebtScreen(debt: n.debt!);
    case NotifKind.goal:
      return const SavingsGoalsScreen();
    case NotifKind.budgetTotal:
      return const BudgetScreen();
  }
}

class _AlertBody extends StatelessWidget {
  final BudgetItemModel item;
  final bool over;
  const _AlertBody({required this.item, required this.over});

  @override
  Widget build(BuildContext context) {
    final remaining = item.limit - item.spent;
    final color = over ? AppColors.expense : AppColors.textPrimary;
    Widget row(String label, String value, {Color? valueColor}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Text(label, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
              const Spacer(),
              Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: valueColor ?? color)),
            ],
          ),
        );
    return OutlineCard(
      child: Column(
        children: [
          AppProgressBar(
            value: item.limit <= 0 ? 0 : item.spent / item.limit,
            color: budgetColor(item.percent, over: over),
            height: 10,
          ),
          const SizedBox(height: 12),
          row('Hạn mức', formatVND(item.limit), valueColor: AppColors.textPrimary),
          row('Đã chi', formatVND(item.spent), valueColor: over ? AppColors.expense : AppColors.textPrimary),
          over
              ? row('Vượt', formatVND(-remaining), valueColor: AppColors.expense)
              : row('Còn lại', formatVND(remaining), valueColor: AppColors.textPrimary),
        ],
      ),
    );
  }
}

Future<void> _adjust(BuildContext context, BudgetItemModel item) async {
  final changed = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => BudgetFormScreen(editing: item)),
  );
  if (changed == true && context.mounted) Navigator.of(context).pop(true);
}

/// Cảnh báo ngân sách sắp vượt hạn mức.
class BudgetAlertScreen extends StatefulWidget {
  final BudgetItemModel item;
  const BudgetAlertScreen({super.key, required this.item});

  @override
  State<BudgetAlertScreen> createState() => _BudgetAlertScreenState();
}

class _BudgetAlertScreenState extends State<BudgetAlertScreen> {
  List<TransactionModel> _top = [];

  @override
  void initState() {
    super.initState();
    BudgetController().monthTransactions(widget.item.label, largestFirst: true).then((l) {
      if (mounted) setState(() => _top = l.take(3).toList());
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return SubPage(
      title: 'Cảnh báo ngân sách',
      bottom: BottomPrimary(text: 'Điều chỉnh ngân sách', onPressed: () => _adjust(context, item)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoBanner(
            icon: Icons.warning_amber_rounded,
            tone: BannerTone.warning,
            title: '${item.label} sắp vượt hạn mức',
            subtitle: 'Bạn đã dùng ${item.percent}% ngân sách tháng ${DateTime.now().month}',
          ),
          const SizedBox(height: 14),
          _AlertBody(item: item, over: false),
          const SectionTitle('Giao dịch lớn nhất'),
          if (_top.isEmpty)
            const OutlineCard(child: Text('Chưa có giao dịch.', style: TextStyle(color: AppColors.textSecondary)))
          else
            ListCard(
              children: [
                for (final t in _top)
                  ListRow(
                    leading: IconBadge(icon: t.categoryIcon, color: AppColors.expense, background: AppColors.expense50, size: 48),
                    title: t.title,
                    subtitle: formatDayMonth(t.date),
                    trailing: Text(t.formattedAmount,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.expense)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Đã vượt ngân sách.
class OverBudgetScreen extends StatelessWidget {
  final BudgetItemModel item;
  const OverBudgetScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: 'Vượt ngân sách',
      closeIcon: true,
      bottom: BottomPrimary(text: 'Điều chỉnh ngân sách', onPressed: () => _adjust(context, item)),
      child: Column(
        children: [
          InfoBanner(
            icon: Icons.warning_amber_rounded,
            tone: BannerTone.danger,
            title: '${item.label} đã vượt hạn mức',
            subtitle: 'Chi ${formatVND(item.spent)} / ${formatVND(item.limit)} (${item.percent}%)',
          ),
          const SizedBox(height: 14),
          _AlertBody(item: item, over: true),
          const SizedBox(height: 14),
          OutlineAppButton(
            text: 'Bỏ qua cảnh báo',
            onPressed: () async {
              await NotificationController().dismissBudget(item);
              if (context.mounted) Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
    );
  }
}
