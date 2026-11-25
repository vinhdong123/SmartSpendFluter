import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../controllers/notification_controller.dart';
import '../../models/notification_item.dart';
import '../budget/budget_alert_screen.dart';
import '../widgets/common_widgets.dart';
import '../widgets/ui_kit.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationItem>? _items;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await NotificationController().load();
    if (mounted) setState(() => _items = items);
  }

  Future<void> _open(NotificationItem n) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => alertPageFor(n)));
    if (changed == true) _changed = true;
    _load();
  }

  (Color, Color) _colors(NotifKind k) {
    switch (k) {
      case NotifKind.budgetOver:
        return (AppColors.expense, AppColors.expense50);
      case NotifKind.budgetWarning:
      case NotifKind.budgetTotal:
        return (AppColors.warning700, AppColors.warning50);
      case NotifKind.goal:
        return (AppColors.savings600, AppColors.savings50);
      default:
        return (AppColors.primary, AppColors.primary100);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: SubPage(
        title: 'Thông báo',
        child: items == null
            ? const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            : items.isEmpty
                ? const OutlineCard(
                    child: EmptyState(icon: Icons.notifications_none_rounded, message: 'Chưa có thông báo nào'),
                  )
                : ListCard(
                    children: [
                      for (final n in items)
                        ListRow(
                          onTap: () => _open(n),
                          leading: IconBadge(icon: n.icon, color: _colors(n.kind).$1, background: _colors(n.kind).$2, size: 48),
                          title: n.title,
                          subtitle: n.subtitle,
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
      ),
    );
  }
}
