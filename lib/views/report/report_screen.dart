import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/categories.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/report_controller.dart';
import '../widgets/common_widgets.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final ReportController _controller = ReportController();
  int _selectedPeriod = 1; // 0: Tuần, 1: Tháng, 2: Năm
  bool _isLoading = true;
  ReportData? _data;

  static const _warmBg = Color(0xFFFEF3C7);
  static const _warmFg = Color(0xFFD97706);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await _controller.load(_selectedPeriod);
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showSnack(context, 'Không tải được dữ liệu: $e', isError: true);
    }
  }

  String get _chartTitle => _selectedPeriod == 0
      ? 'Chi tiêu 7 ngày gần nhất'
      : (_selectedPeriod == 2 ? 'Chi tiêu 5 năm gần nhất' : 'Chi tiêu 6 tháng gần nhất');

  String get _periodWord => _selectedPeriod == 0 ? 'tuần này' : (_selectedPeriod == 2 ? 'năm nay' : 'tháng này');

  Future<void> _export() async {
    try {
      final csv = await _controller.buildCsv(_selectedPeriod);
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      showSnack(context, 'Đã sao chép báo cáo $_periodWord (CSV) vào clipboard. Dán vào Excel / Google Sheets để mở.');
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Không thể xuất báo cáo: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

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
                      'Báo cáo',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.file_download_outlined, color: AppColors.textPrimary),
                      onPressed: _export,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                SegmentedTabs(
                  labels: ReportController.periodNames,
                  selected: _selectedPeriod,
                  onChanged: (i) {
                    setState(() {
                      _selectedPeriod = i;
                      _isLoading = true;
                    });
                    _loadData();
                  },
                ),
                const SizedBox(height: 20),

                if (_isLoading || data == null)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primaryTeal)),
                  )
                else ...[
                  // Summary
                  Row(
                    children: [
                      Expanded(child: _buildSummaryCard('Thu nhập $_periodWord', data.income, AppColors.success)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSummaryCard('Chi tiêu $_periodWord', data.expense, const Color(0xFFEF4444))),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildChart(data),
                  const SizedBox(height: 24),

                  const Text(
                    'Theo danh mục',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: data.categories.isEmpty
                        ? const EmptyState(
                            icon: Icons.pie_chart_outline_rounded,
                            message: 'Chưa có khoản chi nào trong khoảng thời gian này.',
                          )
                        : Column(
                            children: [
                              for (int i = 0; i < data.categories.length; i++) ...[
                                _buildCategoryTile(data.categories[i].label, data.categories[i].total, data.totalCategoryExpense, i == 0),
                                if (i < data.categories.length - 1)
                                  const Divider(height: 1, indent: 64, color: AppColors.border),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _export,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.lightMint,
                        foregroundColor: AppColors.primaryTeal,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.file_download_outlined, size: 20),
                      label: const Text('Xuất báo cáo (CSV)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, int value, Color color) {
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(
            formatVND(value),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(ReportData data) {
    final maxValue = data.series.fold<int>(0, (m, p) => p.value > m ? p.value : m);
    const maxBar = 100.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _chartTitle,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 20),
          if (maxValue == 0)
            const SizedBox(
              height: 120,
              child: Center(
                child: Text('Chưa có dữ liệu chi tiêu', style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            SizedBox(
              height: 160,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final p in data.series)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          p.value == 0 ? '' : compactVND(p.value),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: p.isCurrent ? FontWeight.bold : FontWeight.w500,
                            color: p.isCurrent ? AppColors.primaryTeal : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 26,
                          height: p.value == 0 ? 3 : (maxBar * p.value / maxValue).clamp(3.0, maxBar),
                          decoration: BoxDecoration(
                            color: p.isCurrent ? AppColors.primaryTeal : const Color(0xFFD1EBE6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          p.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: p.isCurrent ? FontWeight.bold : FontWeight.w500,
                            color: p.isCurrent ? AppColors.primaryTeal : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(String label, int total, int sum, bool highlight) {
    final pct = sum <= 0 ? 0 : ((total / sum) * 100).round();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: highlight ? _warmBg : AppColors.lightMint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Categories.iconOf(label),
          color: highlight ? _warmFg : AppColors.primaryTeal,
          size: 20,
        ),
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      ),
      subtitle: Text(
        highlight ? '$pct% tổng chi' : '$pct%',
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
      trailing: Text(
        formatVND(total),
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      ),
    );
  }
}
