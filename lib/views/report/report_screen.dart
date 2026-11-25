import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/categories.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/report_controller.dart';
import '../../models/report_models.dart';
import '../widgets/common_widgets.dart';
import '../widgets/custom_button.dart';
import '../widgets/ui_kit.dart';
import 'analysis_screen.dart';
import 'export_report_screen.dart';
import 'report_filter_screen.dart';
import 'report_widgets.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final ReportController _controller = ReportController();
  ReportFilter _filter = const ReportFilter();
  ReportData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await _controller.load(_filter);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Không tải được báo cáo: $e', isError: true);
    }
  }

  void _setFilter(ReportFilter f) {
    setState(() => _filter = f);
    _load();
  }

  Future<void> _openFilter() async {
    final f = await Navigator.of(context).push<ReportFilter>(
      MaterialPageRoute(builder: (_) => ReportFilterScreen(initial: _filter), fullscreenDialog: true),
    );
    if (f != null) _setFilter(f);
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final isIncome = _filter.type == 2;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Báo cáo',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  ),
                  SquareIconButton(
                    icon: Icons.file_download_outlined,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExportReportScreen(filter: _filter))),
                  ),
                  const SizedBox(width: 10),
                  SquareIconButton(icon: Icons.filter_alt_outlined, onTap: _openFilter, dot: _filter.isFiltered),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedTabs(
                labels: ReportController.periodNames,
                selected: _filter.tabIndex,
                onChanged: (i) => _setFilter(_filter.copyWith(range: const [ReportRange.week, ReportRange.month, ReportRange.year][i])),
              ),
            ),
            Expanded(
              child: _loading || d == null
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                        children: [
                          Row(
                            children: [
                              Expanded(child: StatCard(label: 'Thu · ${_filter.rangeLabel}', value: formatVND(d.income), valueColor: AppColors.income)),
                              const SizedBox(width: 12),
                              Expanded(child: StatCard(label: 'Chi · ${_filter.rangeLabel}', value: formatVND(d.expense), valueColor: AppColors.expense)),
                            ],
                          ),
                          if (_filter.isFiltered)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Đang lọc: ${[if (_filter.wallet != null) _filter.wallet!, if (_filter.type != 0) _filter.typeLabel].join(' · ')}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ),
                          const SizedBox(height: 14),
                          OutlineCard(
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AnalysisScreen(initial: _filter))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(chartTitle(_filter),
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                    ),
                                    const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                BarChartMini(points: d.series),
                              ],
                            ),
                          ),
                          SectionTitle('Theo danh mục'),
                          if (d.categories.isEmpty)
                            const OutlineCard(child: EmptyState(icon: Icons.pie_chart_outline_rounded, message: 'Chưa có dữ liệu trong kỳ này'))
                          else
                            ListCard(
                              children: [
                                for (final c in d.categories.take(8))
                                  ListRow(
                                    leading: IconBadge(
                                      icon: Categories.iconOf(c.label),
                                      size: 48,
                                      color: isIncome ? AppColors.income : (c.label == 'Ăn uống' ? AppColors.warning700 : AppColors.primary),
                                      background: isIncome ? AppColors.income50 : (c.label == 'Ăn uống' ? AppColors.warning50 : AppColors.primary100),
                                    ),
                                    title: c.label,
                                    subtitle: '${d.totalCategory == 0 ? 0 : (c.total * 100 / d.totalCategory).round()}% tổng ${isIncome ? 'thu' : 'chi'}',
                                    trailing: Text(formatVND(c.total),
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                  ),
                              ],
                            ),
                          const SizedBox(height: 14),
                          TonalButton(
                            text: 'Xuất báo cáo',
                            icon: Icons.file_download_outlined,
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExportReportScreen(filter: _filter))),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
