import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/budget_controller.dart';
import '../../models/budget_models.dart';
import '../../models/transaction_model.dart';
import '../transaction/transaction_detail_screen.dart';
import '../widgets/ui_kit.dart';
import 'budget_form_screen.dart';

/// Theo dõi ngân sách của một danh mục trong tháng.
class BudgetDetailScreen extends StatefulWidget {
  final BudgetItemModel item;
  const BudgetDetailScreen({super.key, required this.item});

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends State<BudgetDetailScreen> {
  final BudgetController _controller = BudgetController();
  late BudgetItemModel _item = widget.item;
  List<TransactionModel> _txs = [];
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final overview = await _controller.fetchOverview(1);
    final fresh = overview.items.where((i) => i.id == _item.id).toList();
    final txs = await _controller.monthTransactions(_item.label);
    if (!mounted) return;
    setState(() {
      if (fresh.isNotEmpty) _item = fresh.first;
      _txs = txs;
    });
  }

  Future<void> _edit() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => BudgetFormScreen(editing: _item)),
    );
    if (result == true) {
      _changed = true;
      // Có thể đã bị xóa -> kiểm tra còn tồn tại không.
      final overview = await _controller.fetchOverview(1);
      if (!overview.items.any((i) => i.id == _item.id)) {
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = (lastDay - now.day).clamp(1, 31);
    final remaining = item.limit - item.spent;
    final over = remaining < 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: SubPage(
        title: 'Ngân sách ${item.label}',
        actions: [SquareIconButton(icon: Icons.edit_outlined, onTap: _edit)],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Đã chi tháng ${now.month}', style: const TextStyle(fontSize: 14, color: Color(0xCCFFFFFF))),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('${formatVND(item.spent)} / ${formatVND(item.limit)}',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  const SizedBox(height: 14),
                  AppProgressBar(
                    value: item.limit <= 0 ? 0 : item.spent / item.limit,
                    color: over ? const Color(0xFFFF8F8F) : AppColors.accent,
                    background: AppColors.primary100,
                    height: 10,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    over
                        ? 'Đã vượt ${formatVND(-remaining)} · $daysLeft ngày nữa hết tháng'
                        : 'Còn ${formatVND(remaining)} · $daysLeft ngày nữa hết tháng',
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            InfoBanner(
              icon: Icons.warning_amber_rounded,
              tone: over ? BannerTone.danger : (item.isWarning ? BannerTone.warning : BannerTone.primary),
              title: 'Gợi ý',
              subtitle: over
                  ? 'Đã vượt hạn mức, hãy hạn chế chi thêm cho ${item.label.toLowerCase()}'
                  : remaining == 0
                      ? 'Đã chạm hạn mức, nên dừng chi thêm trong tháng'
                      : 'Chi tối đa ${formatVND(remaining ~/ daysLeft)}/ngày để không vượt hạn mức',
            ),
            const SectionTitle('Giao dịch thuộc ngân sách'),
            if (_txs.isEmpty)
              const OutlineCard(
                child: Text('Chưa có giao dịch nào trong tháng này.', style: TextStyle(color: AppColors.textSecondary)),
              )
            else
              ListCard(
                children: [
                  for (final t in _txs)
                    TxRow(
                      tx: t,
                      onTap: () async {
                        final c = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(builder: (_) => TransactionDetailScreen(transaction: t)),
                        );
                        if (c == true) {
                          _changed = true;
                          _load();
                        }
                      },
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
