import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/group_debt_controller.dart';
import '../../models/group_models.dart';
import '../widgets/common_widgets.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final GroupDebtController _controller = GroupDebtController();
  GroupDetail? _group;
  bool _isLoading = true;

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
      _isLoading = false;
    });
  }

  Future<void> _addExpense() async {
    final g = _group;
    if (g == null) return;
    final ok = await showAppSheet<bool>(
      context,
      builder: (_) => _ExpenseForm(controller: _controller, group: g),
    );
    if (ok == true) _load();
  }

  Future<void> _addMember() async {
    final g = _group;
    if (g == null) return;
    final ok = await showAppSheet<bool>(
      context,
      builder: (_) => _MemberForm(controller: _controller, groupId: g.id),
    );
    if (ok == true) _load();
  }

  Future<void> _settle(SettlementSuggestion s) async {
    final ok = await confirmDialog(
      context,
      title: 'Xác nhận thanh toán',
      message: '${s.fromName} đã trả ${formatVND(s.amount)} cho ${s.toName}?',
      confirmLabel: 'Đã trả',
    );
    if (!ok) return;
    await _controller.settle(widget.groupId, s);
    _load();
  }

  Future<void> _deleteExpense(GroupExpenseModel e) async {
    final ok = await confirmDialog(
      context,
      title: 'Xóa khoản chi',
      message: 'Xóa "${e.description}" (${formatVND(e.amount)})?',
      confirmLabel: 'Xóa',
      destructive: true,
    );
    if (!ok) return;
    await _controller.deleteGroupExpense(e.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final g = _group;
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: Text(g?.name ?? 'Nhóm'),
        actions: [
          IconButton(icon: const Icon(Icons.person_add_alt_1_outlined), onPressed: _addMember),
        ],
      ),
      floatingActionButton: g == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _addExpense,
              backgroundColor: AppColors.primaryTeal,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Thêm khoản chi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal))
          : g == null
              ? const EmptyState(icon: Icons.error_outline_rounded, message: 'Không tìm thấy nhóm')
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primaryTeal,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    children: [
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tổng chi phí: ${formatVND(g.totalExpense)}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 12),
                            for (final m in g.members)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Text(m.displayName, style: const TextStyle(fontSize: 14)),
                                    const Spacer(),
                                    Text(
                                      _balanceText(g.balances[m.id] ?? 0),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: (g.balances[m.id] ?? 0) < 0
                                            ? const Color(0xFFEF4444)
                                            : ((g.balances[m.id] ?? 0) > 0 ? AppColors.success : AppColors.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Công nợ nhóm',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 12),
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: g.suggestions.isEmpty
                            ? const EmptyState(icon: Icons.check_circle_outline_rounded, message: 'Không còn khoản nào cần thanh toán')
                            : Column(
                                children: [
                                  for (int i = 0; i < g.suggestions.length; i++) ...[
                                    ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      title: Text(
                                        '${g.suggestions[i].fromName} → ${g.suggestions[i].toName}',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(formatVND(g.suggestions[i].amount),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: g.suggestions[i].fromId == g.me?.id ? const Color(0xFFEF4444) : AppColors.textSecondary,
                                          )),
                                      trailing: TextButton(
                                        onPressed: () => _settle(g.suggestions[i]),
                                        child: const Text('Đã trả',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryTeal)),
                                      ),
                                    ),
                                    if (i < g.suggestions.length - 1) const Divider(height: 1, color: AppColors.border),
                                  ],
                                ],
                              ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Các khoản chi',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 12),
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: g.expenses.isEmpty
                            ? const EmptyState(icon: Icons.receipt_long_outlined, message: 'Chưa có khoản chi nào')
                            : Column(
                                children: [
                                  for (int i = 0; i < g.expenses.length; i++) ...[
                                    ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      title: Text(g.expenses[i].description,
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                      subtitle: Text(
                                        '${g.memberName(g.expenses[i].paidByMemberId)} trả · ${formatDate(g.expenses[i].date)}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                      trailing: Text(formatVND(g.expenses[i].amount),
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                      onLongPress: () => _deleteExpense(g.expenses[i]),
                                    ),
                                    if (i < g.expenses.length - 1) const Divider(height: 1, color: AppColors.border),
                                  ],
                                ],
                              ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Giữ lâu một khoản chi để xóa.',
                          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                    ],
                  ),
                ),
    );
  }

  String _balanceText(int v) {
    if (v == 0) return 'Cân bằng';
    return v > 0 ? 'Nhận lại ${formatVND(v)}' : 'Nợ ${formatVND(-v)}';
  }
}

class _ExpenseForm extends StatefulWidget {
  final GroupDebtController controller;
  final GroupDetail group;
  const _ExpenseForm({required this.controller, required this.group});

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _desc = TextEditingController();
  final _amount = TextEditingController();
  late String _paidBy = widget.group.me?.id ?? widget.group.members.first.id;
  late final Set<String> _participants = {for (final m in widget.group.members) m.id};
  String? _descError;
  String? _amountError;
  String? _partError;
  bool _saving = false;

  @override
  void dispose() {
    _desc.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final desc = _desc.text.trim();
    final amount = parseAmount(_amount.text);
    setState(() {
      _descError = desc.isEmpty ? 'Vui lòng nhập nội dung' : null;
      _amountError = amount <= 0 ? 'Vui lòng nhập số tiền lớn hơn 0' : null;
      _partError = _participants.isEmpty ? 'Chọn ít nhất một người' : null;
    });
    if (_descError != null || _amountError != null || _partError != null) return;

    setState(() => _saving = true);
    try {
      await widget.controller.addGroupExpense(
        groupId: widget.group.id,
        description: desc,
        amount: amount,
        paidBy: _paidBy,
        participants: _participants.toList(),
        date: DateTime.now(),
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
    final members = widget.group.members;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetHeader('Thêm khoản chi nhóm'),
        TextField(
          controller: _desc,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: 'Nội dung (VD: Khách sạn)', errorText: _descError),
        ),
        const SizedBox(height: 12),
        AmountField(controller: _amount, errorText: _amountError),
        const SizedBox(height: 16),
        const Text('Ai trả tiền?', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in members)
              ChoiceChip(
                label: Text(m.displayName),
                selected: _paidBy == m.id,
                onSelected: (_) => setState(() => _paidBy = m.id),
                selectedColor: AppColors.primaryTeal,
                backgroundColor: AppColors.lightMint,
                side: BorderSide.none,
                showCheckmark: false,
                labelStyle: TextStyle(color: _paidBy == m.id ? Colors.white : AppColors.primaryTeal, fontWeight: FontWeight.w600),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Chia đều cho', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in members)
              FilterChip(
                label: Text(m.displayName),
                selected: _participants.contains(m.id),
                onSelected: (v) => setState(() {
                  if (v) {
                    _participants.add(m.id);
                  } else {
                    _participants.remove(m.id);
                  }
                }),
                selectedColor: AppColors.primaryTeal,
                backgroundColor: AppColors.lightMint,
                side: BorderSide.none,
                showCheckmark: false,
                labelStyle: TextStyle(
                    color: _participants.contains(m.id) ? Colors.white : AppColors.primaryTeal, fontWeight: FontWeight.w600),
              ),
          ],
        ),
        if (_partError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_partError!, style: const TextStyle(fontSize: 12, color: AppColors.error)),
          ),
        SheetSubmit(label: 'Lưu khoản chi', onPressed: _save, isLoading: _saving),
      ],
    );
  }
}

class _MemberForm extends StatefulWidget {
  final GroupDebtController controller;
  final String groupId;
  const _MemberForm({required this.controller, required this.groupId});

  @override
  State<_MemberForm> createState() => _MemberFormState();
}

class _MemberFormState extends State<_MemberForm> {
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Vui lòng nhập tên');
      return;
    }
    await widget.controller.addMember(widget.groupId, name);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetHeader('Thêm thành viên'),
        TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: 'Tên thành viên', errorText: _error),
        ),
        SheetSubmit(label: 'Thêm', onPressed: _save),
      ],
    );
  }
}
