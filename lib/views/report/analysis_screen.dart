import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../controllers/report_controller.dart';
import '../../models/report_models.dart';
import '../widgets/common_widgets.dart';
import '../widgets/ui_kit.dart';
import 'compare_screen.dart';
import 'report_filter_screen.dart';
import 'report_widgets.dart';

/// Phân tích chi tiêu: phân bổ theo danh mục + xu hướng.
class AnalysisScreen extends StatefulWidget {
  final ReportFilter initial;
  const AnalysisScreen({super.key, required this.initial});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final ReportController _controller = ReportController();
  late ReportFilter _filter = widget.initial;
  ReportData? _data;

  static const _colors = [AppColors.accent, AppColors.primary, AppColors.savings600, Color(0xFFB8C7C2)];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await _controller.load(_filter);
    if (mounted) setState(() => _data = d);
  }

  Future<void> _openFilter() async {
    final f = await Navigator.of(context).push<ReportFilter>(
      MaterialPageRoute(builder: (_) => ReportFilterScreen(initial: _filter), fullscreenDialog: true),
    );
    if (f != null) {
      setState(() => _filter = f);
      _load();
    }
  }

  /// Top 3 danh mục + "Khác" gộp phần còn lại.
  List<(String, int)> _allocation(ReportData d) {
    final total = d.totalCategory;
    if (total == 0) return [];
    final top = d.categories.take(3).toList();
    final rest = d.categories.skip(3).fold<int>(0, (s, c) => s + c.total);
    return [
      for (final c in top) (c.label, (c.total * 100 / total).round()),
      if (rest > 0) ('Khác', (rest * 100 / total).round()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return SubPage(
      title: 'Phân tích ${_filter.type == 2 ? 'thu nhập' : 'chi tiêu'}',
      actions: [SquareIconButton(icon: Icons.filter_alt_outlined, onTap: _openFilter, dot: _filter.isFiltered)],
      bottom: BottomPrimary(
        text: 'So sánh các kỳ',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CompareScreen(wallet: _filter.wallet))),
      ),
      child: Column(
        children: [
          SegmentedTabs(
            labels: ReportController.periodNames,
            selected: _filter.tabIndex,
            onChanged: (i) {
              setState(() => _filter = _filter.copyWith(range: const [ReportRange.week, ReportRange.month, ReportRange.year][i]));
              _load();
            },
          ),
          const SizedBox(height: 14),
          if (d == null)
            const Padding(padding: EdgeInsets.only(top: 40), child: CircularProgressIndicator(color: AppColors.primary))
          else ...[
            OutlineCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Phân bổ theo danh mục · ${_filter.rangeLabel}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  if (_allocation(d).isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Chưa có dữ liệu trong kỳ này', style: TextStyle(color: AppColors.textSecondary)),
                    )
                  else
                    for (final (i, e) in _allocation(d).indexed) ...[
                      Row(
                        children: [
                          Expanded(child: Text(e.$1, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary))),
                          Text('${e.$2}%', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      AppProgressBar(value: e.$2 / 100, color: _colors[i.clamp(0, 3)]),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            OutlineCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chartTitle(_filter).replaceFirst('Chi tiêu', 'Xu hướng').replaceFirst('Thu nhập', 'Xu hướng thu nhập'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 14),
                  BarChartMini(points: d.series),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
