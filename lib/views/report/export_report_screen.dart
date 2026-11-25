import 'dart:io';

import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../controllers/report_controller.dart';
import '../../models/report_models.dart';
import '../../services/export_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/custom_button.dart';
import '../widgets/ui_kit.dart';

class ExportReportScreen extends StatefulWidget {
  final ReportFilter filter;
  const ExportReportScreen({super.key, required this.filter});

  @override
  State<ExportReportScreen> createState() => _ExportReportScreenState();
}

class _ExportReportScreenState extends State<ExportReportScreen> {
  final ReportController _controller = ReportController();
  bool _pdf = true;
  late ReportFilter _period = widget.filter;
  bool _busy = false;

  Future<void> _pickPeriod() async {
    final months = _controller.recentMonths();
    final picked = await showPickerSheet<ReportFilter>(
      context,
      title: 'Kỳ báo cáo',
      options: [
        PickerOption('Quý này', _period.copyWith(range: ReportRange.quarter)),
        PickerOption('Năm nay', _period.copyWith(range: ReportRange.year)),
        for (final m in months)
          PickerOption(
            'Tháng ${m.month}/${m.year}',
            _period.copyWith(range: ReportRange.custom, customFrom: m, customTo: DateTime(m.year, m.month + 1, 0)),
          ),
      ],
    );
    if (picked != null) setState(() => _period = picked.value);
  }

  String get _periodLabel {
    if (_period.range == ReportRange.custom) {
      final b = _period.bounds();
      final last = DateTime(b.to.year, b.to.month, b.to.day - 1);
      if (b.from.day == 1 && last.day == DateTime(b.from.year, b.from.month + 1, 0).day && b.from.month == last.month) {
        return 'Tháng ${b.from.month}/${b.from.year}';
      }
    }
    return _period.rangeLabel;
  }

  Future<void> _export({required bool persist}) async {
    setState(() => _busy = true);
    try {
      final data = await _controller.load(_period);
      final file = await ExportService.instance.build(
        pdf: _pdf,
        periodLabel: _periodLabel,
        income: data.income,
        expense: data.expense,
        categories: data.categories,
        transactions: data.transactions,
        persist: persist,
      );
      if (!mounted) return;
      if (persist) showSnack(context, 'Đã lưu: ${File(file.path).uri.pathSegments.last}');
      await ExportService.instance.share(file, _periodLabel);
    } catch (e) {
      if (mounted) showSnack(context, 'Không thể xuất báo cáo: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _format(String title, String sub, IconData icon, bool pdf) {
    final selected = _pdf == pdf;
    return ListRow(
      onTap: () => setState(() => _pdf = pdf),
      leading: IconBadge(
        icon: icon,
        size: 48,
        color: pdf ? AppColors.expense : AppColors.income,
        background: pdf ? AppColors.expense50 : AppColors.income50,
      ),
      title: title,
      subtitle: sub,
      trailing: selected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: 'Xuất báo cáo',
      bottom: BottomPrimary(text: 'Xuất & chia sẻ', onPressed: _busy ? null : () => _export(persist: true), loading: _busy),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FieldLabel('Định dạng'),
          ListCard(
            children: [
              _format('PDF', 'Dễ đọc, phù hợp để in', Icons.picture_as_pdf_outlined, true),
              _format('Excel (.xlsx)', 'Phân tích thêm trong bảng tính', Icons.table_chart_outlined, false),
            ],
          ),
          LabeledSelect(label: 'Kỳ báo cáo', icon: Icons.calendar_today_outlined, value: _periodLabel, onTap: _pickPeriod),
          if (_period.isFiltered)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Áp dụng bộ lọc: ${[if (_period.wallet != null) _period.wallet!, if (_period.type != 0) _period.typeLabel].join(' · ')}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          const SizedBox(height: 16),
          TonalButton(
            text: 'Chia sẻ qua ứng dụng khác',
            icon: Icons.share_outlined,
            onPressed: _busy ? null : () => _export(persist: false),
          ),
        ],
      ),
    );
  }
}
