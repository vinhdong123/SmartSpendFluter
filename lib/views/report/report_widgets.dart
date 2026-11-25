import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/report_models.dart';

/// Biểu đồ cột đơn giản: cột hiện tại đậm, các cột còn lại nhạt.
class BarChartMini extends StatelessWidget {
  final List<SeriesPoint> points;
  final double height;
  const BarChartMini({super.key, required this.points, this.height = 150});

  @override
  Widget build(BuildContext context) {
    final maxValue = points.fold<int>(0, (m, p) => p.value > m ? p.value : m);
    final barArea = height - 40;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final p in points)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (p.isCurrent && p.value > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(compactVND(p.value),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      ),
                    Container(
                      height: maxValue == 0 ? 6 : (p.value / maxValue * (barArea - 18)).clamp(6.0, barArea),
                      decoration: BoxDecoration(
                        color: p.isCurrent ? AppColors.primary : AppColors.primary100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(p.label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String chartTitle(ReportFilter f) {
  final what = f.type == 2 ? 'Thu nhập' : 'Chi tiêu';
  switch (f.chartPeriod) {
    case 0:
      return '$what 7 ngày gần nhất';
    case 2:
      return '$what 5 năm gần nhất';
    default:
      return '$what 6 tháng gần nhất';
  }
}

/// 10.5 -> "10,5"; 8.0 -> "8".
String percentText(double v) {
  final s = v.abs().toStringAsFixed(1);
  return (s.endsWith('.0') ? s.substring(0, s.length - 2) : s).replaceAll('.', ',');
}
