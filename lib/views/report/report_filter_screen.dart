import 'package:material_ui/material_ui.dart';
import '../../controllers/transaction_controller.dart';
import '../../models/report_models.dart';
import '../../models/wallet_model.dart';
import '../widgets/ui_kit.dart';

/// Bộ lọc báo cáo (thời gian, ví, loại giao dịch). Trả về [ReportFilter].
class ReportFilterScreen extends StatefulWidget {
  final ReportFilter initial;
  const ReportFilterScreen({super.key, required this.initial});

  @override
  State<ReportFilterScreen> createState() => _ReportFilterScreenState();
}

class _ReportFilterScreenState extends State<ReportFilterScreen> {
  late ReportFilter _f = widget.initial;
  List<WalletModel> _wallets = [];

  static const _ranges = <ReportRange, String>{
    ReportRange.week: 'Tuần này',
    ReportRange.month: 'Tháng này',
    ReportRange.quarter: 'Quý này',
    ReportRange.year: 'Năm nay',
    ReportRange.custom: 'Tùy chọn',
  };

  @override
  void initState() {
    super.initState();
    TransactionController().fetchWallets().then((w) {
      if (mounted) setState(() => _wallets = w);
    });
  }

  Future<void> _pickRange(ReportRange r) async {
    if (r != ReportRange.custom) {
      setState(() => _f = _f.copyWith(range: r));
      return;
    }
    final b = _f.bounds();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: b.from, end: DateTime(b.to.year, b.to.month, b.to.day - 1)),
    );
    if (range == null) return;
    setState(() => _f = _f.copyWith(range: ReportRange.custom, customFrom: range.start, customTo: range.end));
  }

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: 'Bộ lọc báo cáo',
      closeIcon: true,
      actions: [
        TextButton(onPressed: () => setState(() => _f = const ReportFilter()), child: const Text('Đặt lại')),
      ],
      bottom: BottomPrimary(text: 'Áp dụng', onPressed: () => Navigator.of(context).pop(_f)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FieldLabel('Khoảng thời gian'),
          ChipChoice<ReportRange>(
            values: _ranges.keys.toList(),
            selected: _f.range,
            labelOf: (r) => _ranges[r]!,
            onSelected: _pickRange,
          ),
          if (_f.range == ReportRange.custom)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(_f.rangeLabel, style: const TextStyle(fontSize: 13))),
          const FieldLabel('Ví'),
          ChipChoice<String>(
            values: ['Tất cả', for (final w in _wallets) w.name],
            selected: _f.wallet ?? 'Tất cả',
            labelOf: (v) => v,
            onSelected: (v) => setState(() => _f = v == 'Tất cả' ? _f.copyWith(clearWallet: true) : _f.copyWith(wallet: v)),
          ),
          const FieldLabel('Loại giao dịch'),
          ChipChoice<int>(
            values: const [0, 1, 2],
            selected: _f.type,
            labelOf: (v) => v == 0 ? 'Tất cả' : (v == 1 ? 'Chi tiêu' : 'Thu nhập'),
            onSelected: (v) => setState(() => _f = _f.copyWith(type: v)),
          ),
        ],
      ),
    );
  }
}
