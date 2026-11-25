import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/group_debt_controller.dart';
import '../../models/group_models.dart';
import '../widgets/common_widgets.dart' hide pickDate;
import '../widgets/ui_kit.dart';

class AddGroupExpenseScreen extends StatefulWidget {
  final GroupDetail group;
  const AddGroupExpenseScreen({super.key, required this.group});

  @override
  State<AddGroupExpenseScreen> createState() => _AddGroupExpenseScreenState();
}

class _AddGroupExpenseScreenState extends State<AddGroupExpenseScreen> {
  final GroupDebtController _controller = GroupDebtController();
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  late String _payerId = (widget.group.me ?? widget.group.members.first).id;
  late final Set<String> _included = {for (final m in widget.group.members) m.id};
  late final Map<String, TextEditingController> _custom = {
    for (final m in widget.group.members) m.id: TextEditingController(),
  };
  int _mode = 0; // 0 chia đều, 1 theo số tiền, 2 theo %
  DateTime _date = DateTime.now();
  String? _amountError;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    for (final c in _custom.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _total => parseAmount(_amount.text);

  /// Số tiền mỗi người khi chia đều.
  Map<String, int> _equalShares() {
    final ids = widget.group.members.where((m) => _included.contains(m.id)).map((m) => m.id).toList();
    if (ids.isEmpty) return {};
    final base = _total ~/ ids.length;
    final rem = _total % ids.length;
    return {for (var i = 0; i < ids.length; i++) ids[i]: base + (i < rem ? 1 : 0)};
  }

  /// Trả về (shares, lỗi). Với chia đều, shares chỉ dùng để hiển thị.
  ({Map<String, int> shares, String? error}) _compute() {
    final total = _total;
    if (_mode == 0) {
      final s = _equalShares();
      return (shares: s, error: s.isEmpty ? 'Chọn ít nhất một người tham gia' : null);
    }
    if (_mode == 1) {
      final s = <String, int>{};
      for (final m in widget.group.members) {
        final v = parseAmount(_custom[m.id]!.text);
        if (v > 0) s[m.id] = v;
      }
      final sum = s.values.fold<int>(0, (a, b) => a + b);
      if (sum != total) return (shares: s, error: 'Tổng chia ${formatVND(sum)} chưa bằng ${formatVND(total)}');
      return (shares: s, error: null);
    }
    final pct = <String, int>{};
    for (final m in widget.group.members) {
      final v = int.tryParse(_custom[m.id]!.text.trim()) ?? 0;
      if (v > 0) pct[m.id] = v;
    }
    final pctSum = pct.values.fold<int>(0, (a, b) => a + b);
    if (pctSum != 100) return (shares: const {}, error: 'Tổng phần trăm là $pctSum%, cần đúng 100%');
    final s = <String, int>{};
    var assigned = 0;
    for (final e in pct.entries) {
      s[e.key] = total * e.value ~/ 100;
      assigned += s[e.key]!;
    }
    // Phần dư do làm tròn cộng cho người đầu tiên.
    final first = pct.keys.first;
    s[first] = s[first]! + (total - assigned);
    return (shares: s, error: null);
  }

  Future<void> _save() async {
    final total = _total;
    final desc = _desc.text.trim();
    if (total <= 0) {
      setState(() => _amountError = 'Nhập số tiền lớn hơn 0');
      return;
    }
    if (desc.isEmpty) {
      showSnack(context, 'Nhập nội dung khoản chi', isError: true);
      return;
    }
    final r = _compute();
    if (r.error != null) {
      showSnack(context, r.error!, isError: true);
      return;
    }
    setState(() => _saving = true);
    final ok = await runGuarded(
      context,
      () => _controller.addGroupExpense(
        groupId: widget.group.id,
        description: desc,
        amount: total,
        paidBy: _payerId,
        participants: r.shares.keys.toList(),
        date: _date,
        shares: _mode == 0 ? null : r.shares,
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
    final g = widget.group;
    final equal = _mode == 0 ? _equalShares() : const <String, int>{};
    return SubPage(
      title: 'Thêm chi phí nhóm',
      bottom: BottomPrimary(text: 'Lưu chi phí', onPressed: _save, loading: _saving),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LabeledInput(
            label: 'Số tiền',
            controller: _amount,
            icon: Icons.attach_money_rounded,
            amount: true,
            hint: '0',
            errorText: _amountError,
            onChanged: (_) => setState(() => _amountError = null),
          ),
          LabeledInput(label: 'Nội dung', controller: _desc, icon: Icons.notes_rounded, hint: 'Ví dụ: Khách sạn 2 đêm'),
          LabeledSelect(
            label: 'Người trả',
            icon: Icons.person_outline_rounded,
            value: g.memberName(_payerId),
            onTap: () async {
              final p = await showPickerSheet<String>(
                context,
                title: 'Ai đã trả?',
                selected: _payerId,
                options: [for (final m in g.members) PickerOption(m.displayName, m.id, icon: Icons.person_outline_rounded)],
              );
              if (p != null) setState(() => _payerId = p.value);
            },
          ),
          LabeledSelect(
            label: 'Ngày',
            icon: Icons.calendar_today_outlined,
            value: formatDate(_date),
            showChevron: false,
            onTap: () async {
              final d = await pickDate(context, _date, last: DateTime.now());
              if (d != null) setState(() => _date = d);
            },
          ),
          const FieldLabel('Cách chia'),
          SegmentedTabs(
            labels: const ['Chia đều', 'Theo số tiền', 'Theo %'],
            selected: _mode,
            onChanged: (i) => setState(() => _mode = i),
          ),
          const SizedBox(height: 14),
          ListCard(
            children: [
              for (final m in g.members)
                ListRow(
                  onTap: _mode == 0
                      ? () => setState(() => _included.contains(m.id) ? _included.remove(m.id) : _included.add(m.id))
                      : null,
                  leading: _mode == 0
                      ? IconBadge(
                          icon: _included.contains(m.id) ? Icons.check_rounded : Icons.person_outline_rounded,
                          size: 48,
                          color: _included.contains(m.id) ? Colors.white : AppColors.textSecondary,
                          background: _included.contains(m.id) ? AppColors.primary : AppColors.primary100,
                        )
                      : const IconBadge(icon: Icons.person_outline_rounded, size: 48),
                  title: m.displayName,
                  trailing: _mode == 0
                      ? Text(_included.contains(m.id) ? formatVND(equal[m.id] ?? 0) : '—',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))
                      : SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _custom[m.id],
                            textAlign: TextAlign.right,
                            keyboardType: TextInputType.number,
                            inputFormatters: _mode == 1 ? [ThousandsSeparatorFormatter()] : [FilteringTextInputFormatter.digitsOnly],
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: '0',
                              suffixText: _mode == 1 ? 'đ' : '%',
                            ),
                          ),
                        ),
                ),
            ],
          ),
          if (_mode == 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Chạm vào từng người để thêm / bỏ khỏi khoản chia',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
          if (_mode != 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _mode == 1
                    ? 'Đã chia: ${formatVND(g.members.fold<int>(0, (s, m) => s + parseAmount(_custom[m.id]!.text)))} / ${formatVND(_total)}'
                    : 'Đã chia: ${g.members.fold<int>(0, (s, m) => s + (int.tryParse(_custom[m.id]!.text.trim()) ?? 0))}% / 100%',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}
