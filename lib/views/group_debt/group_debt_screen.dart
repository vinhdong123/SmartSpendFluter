import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/group_debt_controller.dart';
import '../../models/debt_model.dart';
import '../../models/group_models.dart';
import '../../models/wallet_model.dart';
import '../widgets/common_widgets.dart';
import '../widgets/custom_button.dart';
import 'group_detail_screen.dart';

class GroupDebtScreen extends StatefulWidget {
  const GroupDebtScreen({super.key});

  @override
  State<GroupDebtScreen> createState() => _GroupDebtScreenState();
}

class _GroupDebtScreenState extends State<GroupDebtScreen> {
  final GroupDebtController _controller = GroupDebtController();
  int _selectedTab = 0; // 0: Nhóm, 1: Khoản nợ
  bool _isLoading = true;
  List<GroupDetail> _groups = [];
  List<DebtModel> _debts = [];
  List<WalletModel> _wallets = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool pull = true}) async {
    try {
      final groups = await _controller.fetchGroups();
      final debts = await _controller.fetchDebts();
      final wallets = await _controller.fetchWallets();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _debts = debts;
        _wallets = wallets;
        _isLoading = false;
      });
      if (pull && _controller.canShareGroups) {
        final r = await _controller.syncGroups();
        if (!mounted) return;
        if (r.error != null) {
          if (!r.error!.contains('kết nối')) showSnack(context, 'Chưa đồng bộ được nhóm: ${r.error}', isError: true);
        } else if (r.changed) {
          _loadData(pull: false);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showSnack(context, 'Không tải được dữ liệu: $e', isError: true);
    }
  }

  Future<void> _createGroup() async {
    final ok = await showAppSheet<bool>(context, builder: (_) => _GroupForm(controller: _controller));
    if (ok == true) _loadData();
  }

  Future<void> _addDebt() async {
    final ok = await showAppSheet<bool>(
      context,
      builder: (_) => _DebtForm(controller: _controller, wallets: _wallets),
    );
    if (ok == true) _loadData();
  }

  void _onAdd() => _selectedTab == 0 ? _createGroup() : _addDebt();

  Future<void> _openGroup(GroupDetail g) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: g.id)));
    _loadData();
  }

  Future<void> _openDebt(DebtModel d) async {
    final changed = await showAppSheet<bool>(
      context,
      builder: (_) => _DebtSheet(controller: _controller, debt: d, wallets: _wallets),
    );
    if (changed == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primaryTeal,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Nhóm & Nợ',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add_rounded, color: AppColors.textPrimary, size: 20),
                        padding: EdgeInsets.zero,
                        onPressed: _onAdd,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SegmentedTabs(
                  labels: const ['Nhóm', 'Khoản nợ'],
                  selected: _selectedTab,
                  onChanged: (i) => setState(() => _selectedTab = i),
                ),
                const SizedBox(height: 20),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primaryTeal)),
                  )
                else if (_selectedTab == 0)
                  ..._buildGroups()
                else
                  ..._buildDebts(),
                const SizedBox(height: 24),
                PrimaryButton(
                  text: _selectedTab == 0 ? 'Tạo nhóm mới' : 'Thêm khoản nợ',
                  onPressed: _onAdd,
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroups() {
    if (_groups.isEmpty) {
      return [
        AppCard(
          child: EmptyState(
            icon: Icons.people_outline_rounded,
            message: 'Chưa có nhóm nào.\nTạo nhóm để chia tiền chuyến đi, bữa ăn chung...',
            actionLabel: 'Tạo nhóm',
            onAction: _createGroup,
          ),
        ),
      ];
    }
    return [
      for (final g in _groups)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            onTap: () => _openGroup(g),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.lightMint, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.people_outline_rounded, color: AppColors.primaryTeal, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${g.members.length} thành viên · Tổng chi ${formatVND(g.totalExpense)}',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
                  ],
                ),
                const SizedBox(height: 12),
                _balanceBanner(g.myBalance),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _balanceBanner(int balance) {
    final owes = balance < 0;
    final even = balance == 0;
    final color = even ? AppColors.textSecondary : (owes ? const Color(0xFFEF4444) : AppColors.success);
    final bg = even ? AppColors.surfaceLight : (owes ? const Color(0xFFFFF1F2) : AppColors.lightMint);
    final text = even
        ? 'Đã cân bằng công nợ'
        : (owes ? 'Bạn đang nợ ${formatVND(-balance)}' : 'Bạn được nhận lại ${formatVND(balance)}');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(even ? Icons.check_circle_outline_rounded : (owes ? Icons.warning_amber_rounded : Icons.savings_outlined), color: color, size: 20),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  List<Widget> _buildDebts() {
    if (_debts.isEmpty) {
      return [
        AppCard(
          child: EmptyState(
            icon: Icons.handshake_outlined,
            message: 'Chưa có khoản nợ nào.\nGhi lại tiền bạn vay hoặc cho vay để không bị quên.',
            actionLabel: 'Thêm khoản nợ',
            onAction: _addDebt,
          ),
        ),
      ];
    }
    final owe = _debts.where((d) => d.isBorrowed).fold<int>(0, (s, d) => s + d.remaining);
    final owed = _debts.where((d) => !d.isBorrowed).fold<int>(0, (s, d) => s + d.remaining);
    return [
      Row(
        children: [
          Expanded(child: _debtTotal('Bạn nợ', owe, const Color(0xFFEF4444))),
          const SizedBox(width: 12),
          Expanded(child: _debtTotal('Được nợ', owed, AppColors.success)),
        ],
      ),
      const SizedBox(height: 16),
      for (final d in _debts)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            radius: 18,
            onTap: () => _openDebt(d),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        d.isBorrowed ? 'Nợ ${d.counterparty}' : '${d.counterparty} nợ bạn',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ),
                    Text(
                      d.isSettled ? 'Đã tất toán' : formatVND(d.remaining),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: d.isSettled ? AppColors.textHint : (d.isBorrowed ? const Color(0xFFEF4444) : AppColors.success),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: d.ratio,
                    minHeight: 6,
                    backgroundColor: AppColors.lightMint,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryTeal),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Đã ${d.isBorrowed ? 'trả' : 'thu'} ${formatVND(d.paid)} / ${formatVND(d.principal)}'
                  '${d.dueOn == null ? '' : ' · Hạn ${formatDate(d.dueOn!)}'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: d.isOverdue ? AppColors.error : AppColors.textSecondary,
                    fontWeight: d.isOverdue ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _debtTotal(String label, int value, Color color) {
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(formatVND(value), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _GroupForm extends StatefulWidget {
  final GroupDebtController controller;
  const _GroupForm({required this.controller});

  @override
  State<_GroupForm> createState() => _GroupFormState();
}

class _GroupFormState extends State<_GroupForm> {
  final _name = TextEditingController();
  final _members = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _members.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Vui lòng nhập tên nhóm');
      return;
    }
    final members = _members.text.split(RegExp(r'[,\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await widget.controller.createGroup(name, members);
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
        const SheetHeader('Tạo nhóm mới'),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: 'Tên nhóm (VD: Du lịch Đà Lạt)', errorText: _error),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _members,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Thành viên khác (cách nhau bằng dấu phẩy)',
            hintText: 'Minh, Lan, Hùng',
          ),
        ),
        const SizedBox(height: 6),
        const Text('Bạn sẽ tự động là thành viên của nhóm.', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
        SheetSubmit(label: 'Tạo nhóm', onPressed: _save, isLoading: _saving),
      ],
    );
  }
}

class _DebtForm extends StatefulWidget {
  final GroupDebtController controller;
  final List<WalletModel> wallets;
  const _DebtForm({required this.controller, required this.wallets});

  @override
  State<_DebtForm> createState() => _DebtFormState();
}

class _DebtFormState extends State<_DebtForm> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _isBorrowed = true;
  DateTime? _due;
  bool _recordTx = true;
  late String _wallet = widget.wallets.isEmpty ? '' : widget.wallets.first.name;
  String? _nameError;
  String? _amountError;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final picked = await pickDate(context, initial: _due ?? now, first: now, last: DateTime(now.year + 10));
    if (picked != null) setState(() => _due = picked);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final amount = parseAmount(_amount.text);
    setState(() {
      _nameError = name.isEmpty ? 'Vui lòng nhập tên người vay/cho vay' : null;
      _amountError = amount <= 0 ? 'Vui lòng nhập số tiền lớn hơn 0' : null;
    });
    if (_nameError != null || _amountError != null) return;

    setState(() => _saving = true);
    try {
      await widget.controller.addDebt(
        counterparty: name,
        isBorrowed: _isBorrowed,
        amount: amount,
        dueOn: _due,
        note: _note.text,
        walletName: _recordTx && _wallet.isNotEmpty ? _wallet : null,
      );
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
        const SheetHeader('Thêm khoản nợ'),
        SegmentedTabs(
          labels: const ['Tôi đi vay', 'Tôi cho vay'],
          selected: _isBorrowed ? 0 : 1,
          onChanged: (i) => setState(() => _isBorrowed = i == 0),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: _isBorrowed ? 'Vay của ai?' : 'Cho ai vay?', errorText: _nameError),
        ),
        const SizedBox(height: 12),
        AmountField(controller: _amount, errorText: _amountError),
        const SizedBox(height: 12),
        TextField(controller: _note, decoration: const InputDecoration(labelText: 'Ghi chú (tuỳ chọn)')),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined, color: AppColors.textSecondary),
          title: Text(_due == null ? 'Thêm ngày đến hạn (tuỳ chọn)' : 'Hạn: ${formatDate(_due!)}'),
          trailing: _due == null
              ? null
              : IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => setState(() => _due = null)),
          onTap: _pickDue,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppColors.primaryTeal,
          title: const Text('Ghi vào giao dịch', style: TextStyle(fontSize: 14)),
          subtitle: Text(
            _isBorrowed ? 'Cộng tiền vay vào ví' : 'Trừ tiền cho vay khỏi ví',
            style: const TextStyle(fontSize: 12),
          ),
          value: _recordTx,
          onChanged: (v) => setState(() => _recordTx = v),
        ),
        if (_recordTx && widget.wallets.isNotEmpty)
          ChipSelector(
            options: [for (final w in widget.wallets) w.name],
            selected: _wallet,
            onSelected: (v) => setState(() => _wallet = v),
          ),
        SheetSubmit(label: 'Lưu khoản nợ', onPressed: _save, isLoading: _saving),
      ],
    );
  }
}

class _DebtSheet extends StatefulWidget {
  final GroupDebtController controller;
  final DebtModel debt;
  final List<WalletModel> wallets;
  const _DebtSheet({required this.controller, required this.debt, required this.wallets});

  @override
  State<_DebtSheet> createState() => _DebtSheetState();
}

class _DebtSheetState extends State<_DebtSheet> {
  final _amount = TextEditingController();
  List<DebtPaymentModel> _payments = [];
  late String _wallet = widget.wallets.isEmpty ? '' : widget.wallets.first.name;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _loadPayments() async {
    final list = await widget.controller.fetchPayments(widget.debt.id);
    if (!mounted) return;
    setState(() => _payments = list);
  }

  Future<void> _pay() async {
    final d = widget.debt;
    final amount = parseAmount(_amount.text);
    if (amount <= 0 || amount > d.remaining) {
      setState(() => _error = 'Nhập số tiền từ 1đ đến ${formatVND(d.remaining)}');
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
      await widget.controller.payDebt(d, amount, _wallet);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, 'Lỗi: $e', isError: true);
    }
  }

  Future<void> _hide() async {
    final ok = await confirmDialog(
      context,
      title: 'Ẩn khoản nợ',
      message: 'Ẩn khoản nợ này khỏi danh sách? Các giao dịch đã ghi vẫn được giữ.',
      confirmLabel: 'Ẩn',
    );
    if (!ok) return;
    await widget.controller.archiveDebt(widget.debt.id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.debt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SheetHeader(d.isBorrowed ? 'Nợ ${d.counterparty}' : '${d.counterparty} nợ bạn'),
        Text(
          'Gốc ${formatVND(d.principal)} · Còn lại ${formatVND(d.remaining)}'
          '${d.dueOn == null ? '' : ' · Hạn ${formatDate(d.dueOn!)}'}',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        if (d.note != null) Text(d.note!, style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
        const SizedBox(height: 16),
        if (_payments.isNotEmpty) ...[
          Text(d.isBorrowed ? 'Các lần đã trả' : 'Các lần đã thu', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          for (final p in _payments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Text(formatDate(p.date), style: const TextStyle(color: AppColors.textSecondary)),
                  const Spacer(),
                  Text(formatVND(p.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          const SizedBox(height: 12),
        ],
        if (d.isSettled)
          Center(
            child: TextButton(
              onPressed: _hide,
              child: const Text('Ẩn khoản nợ đã tất toán', style: TextStyle(color: AppColors.textSecondary)),
            ),
          )
        else ...[
          AmountField(
            controller: _amount,
            label: d.isBorrowed ? 'Số tiền trả' : 'Số tiền thu về',
            errorText: _error,
          ),
          const SizedBox(height: 12),
          ChipSelector(
            options: [for (final w in widget.wallets) w.name],
            selected: _wallet,
            onSelected: (v) => setState(() => _wallet = v),
          ),
          SheetSubmit(label: d.isBorrowed ? 'Ghi nhận trả nợ' : 'Ghi nhận thu nợ', onPressed: _pay, isLoading: _saving),
        ],
      ],
    );
  }
}
