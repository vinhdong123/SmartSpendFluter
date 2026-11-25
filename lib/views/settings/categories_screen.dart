import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/categories.dart';
import '../../controllers/settings_controller.dart';
import '../budget/budget_form_screen.dart' show TextButtonDanger;
import '../widgets/common_widgets.dart';
import '../widgets/ui_kit.dart';

/// Quản lý danh mục thu / chi. Pop(true) khi có thay đổi.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  int _tab = 0;
  bool _changed = false;

  Future<void> _open({CategoryInfo? category}) async {
    final r = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CategoryFormScreen(isIncome: _tab == 1, category: category)),
    );
    if (r == true) _changed = true;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final list = _tab == 0 ? Categories.expense : Categories.income;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: SubPage(
        title: 'Quản lý danh mục',
        bottom: BottomPrimary(text: 'Thêm danh mục', onPressed: () => _open()),
        child: Column(
          children: [
            SegmentedTabs(labels: const ['Chi tiêu', 'Thu nhập'], selected: _tab, onChanged: (i) => setState(() => _tab = i)),
            const SizedBox(height: 14),
            ListCard(
              children: [
                for (final c in list)
                  ListRow(
                    onTap: c.code == 'khac' ? null : () => _open(category: c),
                    leading: IconBadge(
                      icon: c.icon,
                      size: 48,
                      color: c.code == 'an_uong' ? AppColors.warning700 : (c.code == 'suc_khoe' ? AppColors.expense : AppColors.primary),
                      background: c.code == 'an_uong' ? AppColors.warning50 : (c.code == 'suc_khoe' ? AppColors.expense50 : AppColors.primary100),
                    ),
                    title: c.label,
                    trailing: c.code == 'khac'
                        ? const Text('Mặc định', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
                        : const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryFormScreen extends StatefulWidget {
  final bool isIncome;
  final CategoryInfo? category;
  const CategoryFormScreen({super.key, required this.isIncome, this.category});

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final CategoryController _controller = CategoryController();
  late bool _income = widget.isIncome;
  late final TextEditingController _name = TextEditingController(text: widget.category?.label ?? '');
  late String _iconKey = widget.category?.iconKey ?? 'more';
  String? _error;
  bool _saving = false;

  bool get _isEditing => widget.category != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Nhập tên danh mục');
      return;
    }
    if (Categories.labelExists(name, exceptCode: widget.category?.code)) {
      setState(() => _error = 'Danh mục này đã tồn tại');
      return;
    }
    setState(() => _saving = true);
    final ok = await runGuarded(context, () async {
      if (_isEditing) {
        await _controller.update(widget.category!, name, _iconKey);
      } else {
        await _controller.add(name, _income, _iconKey == 'more' ? 'money' : _iconKey);
      }
    });
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final c = widget.category!;
    final ok = await confirmDialog(
      context,
      title: 'Xóa danh mục ${c.label}?',
      message: 'Giao dịch thuộc danh mục này sẽ chuyển sang "Khác".',
      confirmLabel: 'Xóa',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final done = await runGuarded(context, () => _controller.delete(c));
    if (done && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: _isEditing ? 'Sửa danh mục' : 'Thêm danh mục',
      bottom: BottomPrimary(text: _isEditing ? 'Lưu thay đổi' : 'Lưu danh mục', onPressed: _save, loading: _saving),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isEditing)
            SegmentedTabs(labels: const ['Chi tiêu', 'Thu nhập'], selected: _income ? 1 : 0, onChanged: (i) => setState(() => _income = i == 1)),
          LabeledInput(
            label: 'Tên danh mục',
            controller: _name,
            icon: Icons.sell_outlined,
            hint: 'Ví dụ: Thú cưng',
            errorText: _error,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const FieldLabel('Chọn biểu tượng'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final key in CategoryIcons.pickable)
                GestureDetector(
                  onTap: () => setState(() => _iconKey = key),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _iconKey == key ? AppColors.primary : AppColors.primary100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(CategoryIcons.byKey(key), color: _iconKey == key ? Colors.white : AppColors.primary),
                  ),
                ),
            ],
          ),
          if (_isEditing) ...[
            const SizedBox(height: 20),
            TextButtonDanger(label: 'Xóa danh mục', onTap: _delete),
          ],
        ],
      ),
    );
  }
}
