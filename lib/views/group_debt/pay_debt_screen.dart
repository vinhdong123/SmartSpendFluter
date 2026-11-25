import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/group_debt_controller.dart';
import '../../models/debt_model.dart';
import '../../models/wallet_model.dart';
import '../widgets/common_widgets.dart' hide pickDate;
import '../widgets/ui_kit.dart';

/// Thanh toán / thu nợ một khoản. Pop(true) khi có thay đổi.
class PayDebtScreen extends StatefulWidget {
  final DebtModel debt;
  const PayDebtScreen({super.key, required this.debt});

  @override
  State<PayDebtScreen> createState() => _PayDebtScreenState();
}

class _PayDebtScreenState extends State<PayDebtScreen> {
  final GroupDebtController _controller = GroupDebtController();
  final _amount = TextEditingController();
  late DebtModel _debt = widget.debt;
  List<DebtPaymentModel> _payments = [];
  List<WalletModel> _wallets = [];
  String? _wallet;
  DateTime _date = DateTime.now();
  String? _error;
  bool _saving = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final debts = await _controller.fetchDebts();
    final payments = await _controller.fetchPayments(_debt.id);
    final wallets = await _controller.fetchWallets();
    if (!mounted) return;
    setState(() {
      final fresh = debts.where((d) => d.id == _debt.id).toList();
      if (fresh.isNotEmpty) _debt = fresh.first;
      _payments = payments;
      _wallets = wallets;
      _wallet ??= wallets.isEmpty ? null : wallets.first.name;
    });
  }

  Future<void> _save() async {
    final amount = parseAmount(_amount.text);
    if (amount <= 0) {
      setState(() => _error = 'Nhập số tiền lớn hơn 0');
      return;
    }
    if (amount > _debt.remaining) {
      setState(() => _error = 'Tối đa ${formatVND(_debt.remaining)}');
      return;
    }
    if (_wallet == null) {
      showSnack(context, 'Chưa có ví nào', isError: true);
      return;
    }
    setState(() => _saving = true);
    final ok = await runGuarded(context, () => _controller.payDebt(_debt, amount, _wallet!, _date));
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      _changed = true;
      _amount.clear();
      showSnack(context, 'Đã ghi nhận ${formatVND(amount)}');
      await _load();
    }
  }

  Future<void> _remove() async {
    final ok = await confirmDialog(
      context,
      title: 'Xóa khoản này khỏi danh sách?',
      message: 'Các giao dịch đã ghi nhận vẫn được giữ lại.',
      confirmLabel: 'Xóa',
      destructive: true,
    );
    if (!ok) return;
    await _controller.archiveDebt(_debt.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final d = _debt;
    final borrowed = d.isBorrowed;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: SubPage(
        title: borrowed ? 'Thanh toán nợ' : 'Thu nợ',
        actions: [SquareIconButton(icon: Icons.delete_outline_rounded, onTap: _remove)],
        bottom: d.isSettled
            ? null
            : BottomPrimary(text: borrowed ? 'Ghi nhận thanh toán' : 'Ghi nhận thu nợ', onPressed: _save, loading: _saving),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlineCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconBadge(
                        icon: Icons.person_outline_rounded,
                        color: borrowed ? AppColors.expense : AppColors.income,
                        background: borrowed ? AppColors.expense50 : AppColors.income50,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(borrowed ? 'Nợ ${d.counterparty}' : 'Cho ${d.counterparty} vay',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            Text(d.dueOn == null ? 'Không có hạn' : 'Hạn ${formatDate(d.dueOn!)}',
                                style: TextStyle(fontSize: 13, color: d.isOverdue ? AppColors.expense : AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AppProgressBar(value: d.ratio, color: AppColors.primary),
                  const SizedBox(height: 10),
                  _line('Gốc', formatVND(d.principal), AppColors.textPrimary),
                  _line(borrowed ? 'Đã trả' : 'Đã thu', formatVND(d.paid), AppColors.income),
                  _line('Còn lại', formatVND(d.remaining), d.remaining == 0 ? AppColors.income : AppColors.expense),
                ],
              ),
            ),
            if (d.isSettled)
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: InfoBanner(icon: Icons.check_rounded, tone: BannerTone.success, title: 'Đã tất toán', subtitle: 'Khoản này không còn dư nợ'),
              )
            else ...[
              LabeledInput(
                label: borrowed ? 'Số tiền trả lần này' : 'Số tiền thu lần này',
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
                label: borrowed ? 'Trả từ ví' : 'Nhận vào ví',
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
                  final p = await pickDate(context, _date, last: DateTime.now());
                  if (p != null) setState(() => _date = p);
                },
              ),
            ],
            const SectionLabel('Lịch sử thanh toán'),
            if (_payments.isEmpty)
              const OutlineCard(child: Text('Chưa có lần thanh toán nào.', style: TextStyle(color: AppColors.textSecondary)))
            else
              ListCard(
                children: [
                  for (var i = 0; i < _payments.length; i++)
                    ListRow(
                      leading: const IconBadge(icon: Icons.check_rounded, color: AppColors.income, background: AppColors.income50, size: 48),
                      title: 'Lần ${_payments.length - i}',
                      subtitle: formatDate(_payments[i].date),
                      trailing: Text(formatVND(_payments[i].amount),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
            const Spacer(),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      );
}
