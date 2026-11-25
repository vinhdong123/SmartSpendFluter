import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../controllers/settings_controller.dart';
import '../../models/recurring_model.dart';

/// Màn hình quản lý giao dịch định kỳ.
class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  final RecurringController _controller = RecurringController();
  List<RecurringModel> _items = [];
  bool _loading = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _controller.fetch();
      if (mounted) setState(() => _items = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(RecurringModel item, bool value) async {
    await _controller.setActive(item.id, value);
    _changed = true;
    await _load();
  }

  Future<void> _delete(RecurringModel item) async {
    await _controller.delete(item.id);
    _changed = true;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('Giao dịch định kỳ'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const Center(
                    child: Text(
                      'Chưa có giao dịch định kỳ nào',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final item = _items[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.scheduleLabel} · ${item.wallet}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.formattedAmount,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: item.isExpense ? AppColors.error : AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: item.active,
                              onChanged: (v) => _toggleActive(item, v),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                              onPressed: () => _delete(item),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
