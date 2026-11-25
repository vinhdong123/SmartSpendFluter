import 'package:material_ui/material_ui.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/group_debt_controller.dart';
import '../../models/wallet_model.dart';
import '../widgets/common_widgets.dart';
import '../widgets/ui_kit.dart';

class AddDebtScreen extends StatefulWidget {
  const AddDebtScreen({super.key});

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  final GroupDebtController _controller = GroupDebtController();
  final _person = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _borrowed = true;
  DateTime? _due;
  List<WalletModel> _wallets = [];
  String? _wallet; // null: không ghi vào ví
  String? _personError;
  String? _amountError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller.fetchWallets().then((w) {
      if (mounted) setState(() => _wallets = w);
    });
  }

  @override
  void dispose() {
    _person.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final person = _person.text.trim();
    final amount = parseAmount(_amount.text);
    setState(() {
      _personError = person.isEmpty ? 'Nhập tên người liên quan' : null;
      _amountError = amount <= 0 ? 'Nhập số tiền lớn hơn 0' : null;
    });
    if (person.isEmpty || amount <= 0) return;
    setState(() => _saving = true);
    final ok = await runGuarded(
      context,
      () => _controller.addDebt(
        counterparty: person,
        isBorrowed: _borrowed,
        amount: amount,
        dueOn: _due,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        walletName: _wallet,
      ),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: 'Thêm khoản nợ',
      bottom: BottomPrimary(text: 'Lưu khoản nợ', onPressed: _save, loading: _saving),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedTabs(
            labels: const ['Tôi nợ', 'Tôi cho vay'],
            selected: _borrowed ? 0 : 1,
            onChanged: (i) => setState(() => _borrowed = i == 0),
          ),
          LabeledInput(label: 'Người liên quan', controller: _person, icon: Icons.person_outline_rounded, hint: 'Ví dụ: Anh Tuấn', errorText: _personError),
          LabeledInput(label: 'Số tiền', controller: _amount, icon: Icons.attach_money_rounded, amount: true, hint: '0', errorText: _amountError),
          LabeledSelect(
            label: 'Hạn trả',
            icon: Icons.calendar_today_outlined,
            value: _due == null ? 'Không đặt hạn' : formatDate(_due!),
            showChevron: false,
            onTap: () async {
              final d = await pickDate(context, _due ?? DateTime.now().add(const Duration(days: 30)), first: DateTime.now());
              if (d != null) setState(() => _due = d);
            },
          ),
          LabeledInput(label: 'Ghi chú', controller: _note, icon: Icons.notes_rounded, hint: 'Ví dụ: Mượn đóng học phí'),
          LabeledSelect(
            label: _borrowed ? 'Tiền vay nhập vào ví (tùy chọn)' : 'Tiền cho vay trừ từ ví (tùy chọn)',
            icon: Icons.account_balance_wallet_outlined,
            value: _wallet ?? 'Không ghi vào ví',
            onTap: _wallets.isEmpty
                ? null
                : () async {
                    final p = await showPickerSheet<String?>(
                      context,
                      title: 'Chọn ví',
                      selected: _wallet,
                      options: [
                        const PickerOption<String?>('Không ghi vào ví', null),
                        for (final w in _wallets) PickerOption<String?>(w.name, w.name, icon: w.icon),
                      ],
                    );
                    if (p != null) setState(() => _wallet = p.value);
                  },
          ),
        ],
      ),
    );
  }
}
