import 'package:material_ui/material_ui.dart';
import '../../core/constants/categories.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/transaction_controller.dart';
import '../../models/tx_filter.dart';
import '../../models/wallet_model.dart';
import '../widgets/ui_kit.dart';

/// Tìm kiếm & lọc giao dịch theo từ khóa, thời gian, ví, danh mục. Trả về [TxFilter].
class SearchFilterScreen extends StatefulWidget {
  final TxFilter initial;
  const SearchFilterScreen({super.key, required this.initial});

  @override
  State<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends State<SearchFilterScreen> {
  late final TextEditingController _query = TextEditingController(text: widget.initial.query);
  late TxFilter _f = widget.initial;
  String _timeChoice = 'Tháng này';
  List<WalletModel> _wallets = [];

  static const _times = ['Hôm nay', '7 ngày', 'Tháng này', 'Tùy chọn'];

  @override
  void initState() {
    super.initState();
    _timeChoice = _detectTime();
    TransactionController().fetchWallets().then((w) {
      if (mounted) setState(() => _wallets = w);
    });
  }

  String _detectTime() {
    final f = widget.initial;
    if (!f.hasRange) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (isSameDay(f.from!, today) && isSameDay(f.to!, today)) return 'Hôm nay';
    if (isSameDay(f.to!, today) && today.difference(f.from!).inDays == 6) return '7 ngày';
    if (f.isMonthRange && f.from!.month == now.month && f.from!.year == now.year) return 'Tháng này';
    return 'Tùy chọn';
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _selectTime(String t) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (t == 'Tùy chọn') {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDateRange: _f.hasRange ? DateTimeRange(start: _f.from!, end: _f.to!) : null,
      );
      if (range == null) return;
      setState(() {
        _timeChoice = t;
        _f = _f.copyWith(from: range.start, to: range.end);
      });
      return;
    }
    setState(() {
      _timeChoice = t;
      if (t == 'Hôm nay') {
        _f = _f.copyWith(from: today, to: today);
      } else if (t == '7 ngày') {
        _f = _f.copyWith(from: DateTime(today.year, today.month, today.day - 6), to: today);
      } else {
        _f = _f.copyWith(from: DateTime(now.year, now.month, 1), to: DateTime(now.year, now.month + 1, 0));
      }
    });
  }

  void _apply() {
    Navigator.of(context).pop(_f.copyWith(query: _query.text));
  }

  void _reset() {
    setState(() {
      _query.clear();
      _timeChoice = '';
      _f = const TxFilter();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cats = Categories.allLabels;
    return SubPage(
      title: 'Tìm kiếm & lọc',
      actions: [
        TextButton(onPressed: _reset, child: const Text('Đặt lại')),
      ],
      bottom: BottomPrimary(text: 'Áp dụng bộ lọc', onPressed: _apply),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LabeledInput(label: 'Từ khóa', controller: _query, icon: Icons.search_rounded, hint: 'Tên giao dịch, ghi chú...'),
          const FieldLabel('Thời gian'),
          ChipChoice<String>(values: _times, selected: _timeChoice, labelOf: (v) => v, onSelected: _selectTime),
          if (_f.hasRange && _timeChoice == 'Tùy chọn')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_f.rangeLabel, style: const TextStyle(fontSize: 13)),
            ),
          const FieldLabel('Ví'),
          ChipChoice<String>(
            values: ['Tất cả', for (final w in _wallets) w.name],
            selected: _f.wallet ?? 'Tất cả',
            labelOf: (v) => v,
            onSelected: (v) => setState(() => _f = v == 'Tất cả' ? _f.copyWith(clearWallet: true) : _f.copyWith(wallet: v)),
          ),
          const FieldLabel('Danh mục'),
          ChipChoice<String>(
            values: ['Tất cả', ...cats],
            selected: _f.category ?? 'Tất cả',
            labelOf: (v) => v,
            onSelected: (v) =>
                setState(() => _f = v == 'Tất cả' ? _f.copyWith(clearCategory: true) : _f.copyWith(category: v)),
          ),
        ],
      ),
    );
  }
}
