import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/categories.dart';
import '../widgets/ui_kit.dart';

/// Lưới chọn danh mục (3 cột). Trả về nhãn danh mục được chọn.
class CategoryPickerScreen extends StatelessWidget {
  final bool isIncome;
  final String? selected;

  /// Nhãn không cho chọn (vd. danh mục đã có ngân sách).
  final Set<String> exclude;

  const CategoryPickerScreen({super.key, required this.isIncome, this.selected, this.exclude = const {}});

  @override
  Widget build(BuildContext context) {
    final list = [for (final c in (isIncome ? Categories.income : Categories.expense)) if (!exclude.contains(c.label)) c];
    return SubPage(
      title: 'Chọn danh mục',
      child: list.isEmpty
          ? const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: Text('Không còn danh mục để chọn', style: TextStyle(color: AppColors.textSecondary))),
            )
          : GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.0,
              children: [
                for (final c in list)
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(c.label),
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.label == selected ? AppColors.primary100 : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconBadge(
                            icon: c.icon,
                            size: 44,
                            color: c.code == 'an_uong' ? AppColors.warning700 : (c.code == 'suc_khoe' ? AppColors.expense : AppColors.primary),
                            background: c.code == 'an_uong'
                                ? AppColors.warning50
                                : (c.code == 'suc_khoe' ? AppColors.expense50 : AppColors.primary100),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(c.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
