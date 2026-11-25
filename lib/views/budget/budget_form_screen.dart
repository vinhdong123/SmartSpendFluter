import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/categories.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/budget_controller.dart';
import '../../models/budget_models.dart';
import '../transaction/category_picker_screen.dart';
import '../widgets/common_widgets.dart';
import '../widgets/ui_kit.dart';

/// Đặt ngân sách mới (mặc định) hoặc sửa ngân sách danh mục ([editing]).
/// Pop(true) khi có thay đổi.
class BudgetFormScreen extends StatefulWidget {
  final BudgetItemModel? editing;
  const BudgetFormScreen({super.key, this.editing});

  @override
  State<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends State<BudgetFormScreen> {
  final BudgetController _controller = BudgetController();
  final _limit = TextEditingController();
  int _period = 1;
  String? _category;
  int _alertPct = 80;
  Set<String> _used = {};
  String? _error;
  bool _saving = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _category = e.label;
      _alertPct = [50, 70, 80, 90].contains(e.alertPct) ? e.alertPct : 80;
      _limit.text = formatNumber(e.limit);
    } else {
      _controller.fetchOverview(1).then((o) {
        if (mounted) setState(() => _used = {for (final i in o.items) i.label});
      });
    }
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  Future<void> _pickCategory() async {
    if (_isEditing) return;
    final label = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CategoryPickerScreen(isIncome: false, selected: _category, exclude: _used),
      ),
    );
    if (label != null) setState(() => _category = label);
  }

  Future<void> _save() async {
    final cat = _category;
    final amount = parseAmount(_limit.text);
    if (cat == null) {
      showSnack(context, 'Hãy chọn danh mục', isError: true);
      return;
    }
    if (amount <= 0) {
      setState(() => _error = 'Nhập hạn mức lớn hơn 0');
      return;
    }
    setState(() => _saving = true);
    final ok = await runGuarded(context, () => _controller.saveCategoryLimit(
          cat,
          _isEditing ? amount : _controller.toMonthly(_period, amount),
          alertPct: _alertPct,
        ));
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final e = widget.editing!;
    final ok = await confirmDialog(
      context,
      title: 'Xóa ngân sách ${e.label}?',
      message: 'Giao dịch vẫn được giữ nguyên, chỉ bỏ hạn mức.',
      confirmLabel: 'Xóa',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _controller.deleteCategoryLimit(e.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final cat = _category;
    return SubPage(
      title: _isEditing ? 'Sửa ngân sách' : 'Đặt ngân sách',
      bottom: BottomPrimary(text: _isEditing ? 'Lưu thay đổi' : 'Lưu ngân sách', onPressed: _save, loading: _saving),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isEditing) ...[
            SegmentedTabs(
              labels: const ['Tuần', 'Tháng', 'Năm'],
              selected: _period,
              onChanged: (i) => setState(() => _period = i),
            ),
          ],
          LabeledSelect(
            label: 'Danh mục',
            icon: cat == null ? Icons.label_outline_rounded : Categories.iconOf(cat),
            value: cat ?? 'Chọn danh mục',
            onTap: _isEditing ? null : _pickCategory,
          ),
          LabeledInput(
            label: _isEditing ? 'Hạn mức tháng' : 'Hạn mức',
            controller: _limit,
            icon: Icons.attach_money_rounded,
            amount: true,
            hint: '0',
            errorText: _error,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          if (!_isEditing && _period != 1)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _period == 0
                    ? 'Hạn mức theo tuần sẽ được quy đổi sang tháng (×${(DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day / 7).toStringAsFixed(1)}).'
                    : 'Hạn mức theo năm sẽ được chia đều cho 12 tháng.',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          const FieldLabel('Cảnh báo khi dùng đến'),
          ChipChoice<int>(
            values: const [50, 70, 80, 90],
            selected: _alertPct,
            labelOf: (v) => '$v%',
            onSelected: (v) => setState(() => _alertPct = v),
          ),
          const SizedBox(height: 16),
          if (_isEditing)
            TextButtonDanger(label: 'Xóa ngân sách', onTap: _delete)
          else
            InfoBanner(
              icon: Icons.notifications_none_rounded,
              title: 'Cảnh báo sớm',
              subtitle: 'Bạn sẽ nhận thông báo khi chi tiêu chạm $_alertPct% hạn mức',
            ),
        ],
      ),
    );
  }
}

/// Nút xóa nền đỏ nhạt.
class TextButtonDanger extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const TextButtonDanger({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.delete_outline_rounded),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.expense50,
            foregroundColor: AppColors.expense,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
}
