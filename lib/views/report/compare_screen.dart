import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/report_controller.dart';
import '../../models/report_models.dart';
import '../widgets/common_widgets.dart';
import '../widgets/ui_kit.dart';
import 'report_widgets.dart';

class CompareScreen extends StatefulWidget {
  final String? wallet;
  const CompareScreen({super.key, this.wallet});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  final ReportController _controller = ReportController();
  int _mode = 0;
  CompareResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await _controller.compare(_mode, wallet: widget.wallet);
    if (mounted) setState(() => _result = r);
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return SubPage(
      title: 'So sánh các kỳ',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedTabs(
            labels: const ['Tháng', 'Quý', 'Năm'],
            selected: _mode,
            onChanged: (i) {
              setState(() => _mode = i);
              _load();
            },
          ),
          const SizedBox(height: 14),
          if (r == null)
            const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
          else ...[
            Row(
              children: [
                Expanded(child: StatCard(label: r.currentLabel, value: formatVND(r.current))),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: r.previousLabel, value: formatVND(r.previous), valueColor: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 14),
            _banner(r),
            const SizedBox(height: 14),
            OutlineCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Theo danh mục',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  if (r.deltas.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Chưa có chi tiêu để so sánh', style: TextStyle(color: AppColors.textSecondary)),
                    )
                  else
                    for (final c in r.deltas.take(10)) _deltaRow(c),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _banner(CompareResult r) {
    if (r.previous <= 0 && r.current <= 0) {
      return const InfoBanner(icon: Icons.info_outline_rounded, title: 'Chưa có dữ liệu chi tiêu', subtitle: 'Hãy ghi lại giao dịch để so sánh');
    }
    if (r.previous <= 0) {
      return InfoBanner(
        icon: Icons.info_outline_rounded,
        title: 'Chưa có dữ liệu ${r.previousLabel.toLowerCase()}',
        subtitle: 'Chi tiêu ${r.currentLabel.toLowerCase()}: ${formatVND(r.current)}',
      );
    }
    final down = r.difference <= 0;
    return InfoBanner(
      icon: down ? Icons.trending_down_rounded : Icons.trending_up_rounded,
      tone: down ? BannerTone.success : BannerTone.danger,
      title: r.difference == 0 ? 'Chi tiêu không đổi' : 'Chi tiêu ${down ? 'giảm' : 'tăng'} ${percentText(r.percent ?? 0)}%',
      subtitle: r.difference == 0
          ? 'Bằng ${r.previousLabel.toLowerCase()}'
          : '${down ? 'Tiết kiệm được' : 'Chi nhiều hơn'} ${formatVND(r.difference.abs())} so với ${r.previousLabel.toLowerCase()}',
    );
  }

  Widget _deltaRow(CategoryDelta c) {
    final p = c.percent;
    late String text;
    late Color color;
    if (p == null) {
      text = 'Mới';
      color = AppColors.expense;
    } else if (p.abs() < 0.05) {
      text = '0%';
      color = AppColors.textSecondary;
    } else if (p > 0) {
      text = '▲ +${percentText(p)}%';
      color = AppColors.expense;
    } else {
      text = '▼ -${percentText(p)}%';
      color = AppColors.income;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(c.label, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary))),
          Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
