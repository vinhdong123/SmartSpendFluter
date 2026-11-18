import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../controllers/report_controller.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final ReportController _controller = ReportController();
  int _selectedPeriod = 1; // 0: Tuần, 1: Tháng, 2: Năm
  bool _isLoading = true;

  final List<Map<String, dynamic>> _categoryReports = const [
    {
      'category': 'Ăn uống',
      'share': '50% tổng chi',
      'amount': '2.760.000đ',
      'icon': Icons.restaurant_rounded,
      'bgColor': Color(0xFFFEF3C7),
      'iconColor': Color(0xFFD97706),
    },
    {
      'category': 'Mua sắm',
      'share': '25%',
      'amount': '1.400.000đ',
      'icon': Icons.shopping_bag_outlined,
      'bgColor': AppColors.lightMint,
      'iconColor': AppColors.primaryTeal,
    },
    {
      'category': 'Di chuyển',
      'share': '15%',
      'amount': '800.000đ',
      'icon': Icons.directions_car_outlined,
      'bgColor': AppColors.lightMint,
      'iconColor': AppColors.primaryTeal,
    },
  ];

  final List<Map<String, dynamic>> _chartMonths = const [
    {'label': 'T6', 'value': 0.45, 'isCurrent': false},
    {'label': 'T7', 'value': 0.65, 'isCurrent': false},
    {'label': 'T8', 'value': 0.40, 'isCurrent': false},
    {'label': 'T9', 'value': 0.80, 'isCurrent': false},
    {'label': 'T10', 'value': 0.55, 'isCurrent': false},
    {'label': 'T11', 'value': 0.70, 'isCurrent': true},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _controller.fetchCategoryBreakdown();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Báo cáo',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.file_download_outlined, color: AppColors.textPrimary),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.tune_rounded, color: AppColors.textPrimary),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Period Switcher (Tuần / Tháng / Năm)
                Container(
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2F1ED),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildPeriodTab(0, 'Tuần'),
                      _buildPeriodTab(1, 'Tháng'),
                      _buildPeriodTab(2, 'Năm'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Bar Chart Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chi tiêu 6 tháng gần nhất',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Custom Bar Chart
                      SizedBox(
                        height: 140,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final month in _chartMonths)
                              Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    width: 28,
                                    height: 100 * (month['value'] as double),
                                    decoration: BoxDecoration(
                                      color: (month['isCurrent'] as bool)
                                          ? AppColors.primaryTeal
                                          : const Color(0xFFD1EBE6),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    month['label'] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: (month['isCurrent'] as bool)
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: (month['isCurrent'] as bool)
                                          ? AppColors.primaryTeal
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Category Breakdown Section
                const Text(
                  'Theo danh mục',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                // Category Breakdown Card Container
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(child: CircularProgressIndicator(color: AppColors.primaryTeal)),
                        )
                      : Column(
                          children: [
                            for (int i = 0; i < _categoryReports.length; i++) ...[
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _categoryReports[i]['bgColor'] as Color,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _categoryReports[i]['icon'] as IconData,
                                    color: _categoryReports[i]['iconColor'] as Color,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  _categoryReports[i]['category'] as String,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  _categoryReports[i]['share'] as String,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                trailing: Text(
                                  _categoryReports[i]['amount'] as String,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (i < _categoryReports.length - 1)
                                const Divider(height: 1, indent: 64, color: AppColors.border),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 24),

                // Export Report Button (Light Mint)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lightMint,
                      foregroundColor: AppColors.primaryTeal,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.file_download_outlined, size: 20),
                    label: const Text(
                      'Xuất báo cáo',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodTab(int index, String label) {
    final isSelected = _selectedPeriod == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = index),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryTeal : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
