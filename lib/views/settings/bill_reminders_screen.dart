import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_settings.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/settings_controller.dart';
import '../../controllers/transaction_controller.dart';
import '../../models/bill_model.dart';
import '../../models/wallet_model.dart';
import '../budget/budget_form_screen.dart' show TextButtonDanger;
import '../widgets/common_widgets.dart' hide pickDate;
import '../widgets/custom_button.dart';
import '../widgets/ui_kit.dart';

class BillRemindersScreen extends StatefulWidget {
  const BillRemindersScreen({super.key});

  @override
  State<BillRemindersScreen> createState() => _BillRemindersScreenState();
}

class _BillRemindersScreenState extends State<BillRemindersScreen> {
  final BillController _controller = BillController();
  List<BillModel> _bills = [];
  bool _loading = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await _controller.fetch();
    if (!mounted) return;
    setState(() {
      _bills = l;
      _loading = false;
    });
  }

  Future<void> _open([BillModel? b]) async {
    final r = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => BillFormScreen(bill: b)));
    if (r == true) _changed = true;
    _load();
  }

  Future<void> _pickDays() async {
    final p = await showPickerSheet<int>(
      context,
      title: 'Nhắc trước',
      selected: AppSettings.billRemindDays,
      options: [for (final d in const [1, 2, 3, 5, 7]) PickerOption('$d ngày', d)],
    );
    if (p == null) return;
    await AppSettings.setBillRemindDays(p.value);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: SubPage(
        title: 'Nhắc nhở hóa đơn',
        bottom: BottomPrimary(text: 'Thêm nhắc nhở', onPressed: () => _open()),
        child: _loading
            ? const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_bills.isEmpty)
                    const OutlineCard(child: EmptyState(icon: Icons.receipt_long_outlined, message: 'Chưa có hóa đơn nào cần nhắc'))
                  else
                    ListCard(
                      children: [
                        for (final b in _bills)
                          ListRow(
                            onTap: () => _open(b),
                            leading: IconBadge(
                              icon: Icons.bolt_rounded,
                              size: 48,
                              color: b.daysLeft <= AppSettings.billRemindDays ? AppColors.warning700 : AppColors.primary,
                              background: b.daysLeft <= AppSettings.billRemindDays ? AppColors.warning50 : AppColors.primary100,
                            ),
                            title: b.title,
                            subtitle: b.isOverdue ? 'Quá hạn · ${formatDate(b.dueOn)}' : b.dueLabel,
                            trailing: Text(b.amount > 0 ? formatVND(b.amount) : '—',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          ),
                      ],
                    ),
                  LabeledSelect(
                    label: 'Nhắc trước',
                    icon: Icons.notifications_none_rounded,
                    value: '${AppSettings.billRemindDays} ngày',
                    onTap: _pickDays,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Hóa đơn sắp đến hạn sẽ hiện trong mục Thông báo và Trang chủ.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ),
                ],
              ),
      ),
    );
  }
}

class BillFormScreen extends StatefulWidget {
  final BillModel? bill;
  const BillFormScreen({super.key, this.bill});

  @override
  State<BillFormScreen> createState() => _BillFormScreenState();
}

class _BillFormScreenState extends State<BillFormScreen> {
  final BillController _controller = BillController();
  late final TextEditingController _title = TextEditingController(text: widget.bill?.title ?? '');
  late final TextEditingController _amount =
      TextEditingController(text: widget.bill == null || widget.bill!.amount == 0 ? '' : formatNumber(widget.bill!.amount));
  late DateTime _due = widget.bill?.dueOn ?? DateTime.now().add(const Duration(days: 7));
  late bool _repeat = widget.bill?.repeatMonthly ?? true;
  String? _titleError;
  bool _saving = false;

  bool get _isEditing => widget.bill != null;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Nhập tên hóa đơn');
      return;
    }
    setState(() => _saving = true);
    final ok = await runGuarded(
      context,
      () => _controller.save(id: widget.bill?.id, title: title, amount: parseAmount(_amount.text), dueOn: _due, repeatMonthly: _repeat),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Xóa nhắc nhở ${widget.bill!.title}?',
      message: 'Bạn sẽ không còn được nhắc về hóa đơn này.',
      confirmLabel: 'Xóa',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _controller.delete(widget.bill!.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _markPaid() async {
    final wallets = await TransactionController().fetchWallets();
    if (!mounted || wallets.isEmpty) return;
    WalletModel wallet = wallets.first;
    if (wallets.length > 1) {
      final p = await showPickerSheet<WalletModel>(
        context,
        title: 'Thanh toán từ ví',
        options: [for (final w in wallets) PickerOption(w.name, w, icon: w.icon)],
      );
      if (p == null) return;
      wallet = p.value;
    }
    if (!mounted) return;
    final b = widget.bill!;
    final ok = await runGuarded(context, () => _controller.pay(b, wallet.name));
    if (ok && mounted) {
      showSnack(context, b.amount > 0 ? 'Đã ghi khoản chi ${formatVND(b.amount)} từ ${wallet.name}' : 'Đã đánh dấu thanh toán');
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: _isEditing ? 'Sửa nhắc nhở' : 'Thêm nhắc nhở',
      bottom: BottomPrimary(text: _isEditing ? 'Lưu thay đổi' : 'Lưu nhắc nhở', onPressed: _save, loading: _saving),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LabeledInput(
            label: 'Tên hóa đơn',
            controller: _title,
            icon: Icons.bolt_rounded,
            hint: 'Ví dụ: Tiền điện',
            errorText: _titleError,
            onChanged: (_) {
              if (_titleError != null) setState(() => _titleError = null);
            },
          ),
          LabeledInput(label: 'Số tiền (tùy chọn)', controller: _amount, icon: Icons.attach_money_rounded, amount: true, hint: '0'),
          LabeledSelect(
            label: 'Ngày đến hạn',
            icon: Icons.calendar_today_outlined,
            value: formatDate(_due),
            showChevron: false,
            onTap: () async {
              final d = await pickDate(context, _due);
              if (d != null) setState(() => _due = d);
            },
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _repeat,
            activeThumbColor: AppColors.primary,
            onChanged: (v) => setState(() => _repeat = v),
            title: const Text('Lặp lại hàng tháng', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 8),
            TonalButton(text: 'Đánh dấu đã thanh toán', icon: Icons.check_rounded, onPressed: _markPaid),
            const SizedBox(height: 10),
            TextButtonDanger(label: 'Xóa nhắc nhở', onTap: _delete),
          ],
        ],
      ),
    );
  }
}
