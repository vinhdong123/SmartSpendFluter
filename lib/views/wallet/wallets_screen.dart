import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/wallet_goal_controller.dart';
import '../../models/wallet_model.dart';
import '../budget/budget_form_screen.dart' show TextButtonDanger;
import '../widgets/common_widgets.dart';
import '../widgets/ui_kit.dart';

/// Quản lý ví. Pop(true) khi có thay đổi.
class WalletsScreen extends StatefulWidget {
  const WalletsScreen({super.key});

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  final WalletController _controller = WalletController();
  List<WalletModel> _wallets = [];
  bool _loading = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final w = await _controller.fetchWallets();
    if (!mounted) return;
    setState(() {
      _wallets = w;
      _loading = false;
    });
  }

  Future<void> _open([WalletModel? wallet]) async {
    final result = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => WalletFormScreen(wallet: wallet)));
    if (result == true) _changed = true;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final total = _wallets.fold<int>(0, (s, w) => s + w.balance);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: SubPage(
        title: 'Quản lý ví',
        bottom: BottomPrimary(text: 'Thêm ví', onPressed: () => _open()),
        child: _loading
            ? const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tổng số dư các ví', style: TextStyle(fontSize: 14, color: Color(0xCCFFFFFF))),
                        const SizedBox(height: 4),
                        Text(formatVND(total),
                            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  ListCard(
                    children: [
                      for (final w in _wallets)
                        ListRow(
                          onTap: () => _open(w),
                          leading: IconBadge(icon: w.icon, size: 48),
                          title: w.name,
                          subtitle: WalletModel.typeLabel(w.type),
                          trailing: Text(formatVND(w.balance),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: w.balance < 0 ? AppColors.expense : AppColors.textPrimary,
                              )),
                        ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('Chạm vào ví để sửa hoặc xóa', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Thêm ví (wallet == null) hoặc sửa ví.
class WalletFormScreen extends StatefulWidget {
  final WalletModel? wallet;
  const WalletFormScreen({super.key, this.wallet});

  @override
  State<WalletFormScreen> createState() => _WalletFormScreenState();
}

class _WalletFormScreenState extends State<WalletFormScreen> {
  final WalletController _controller = WalletController();
  late final TextEditingController _name = TextEditingController(text: widget.wallet?.name ?? '');
  late final TextEditingController _balance =
      TextEditingController(text: widget.wallet == null ? '' : formatNumber(widget.wallet!.balance));
  late String _type = widget.wallet?.type ?? 'cash';
  String? _nameError;
  bool _saving = false;

  bool get _isEditing => widget.wallet != null;

  static const _types = ['cash', 'bank', 'ewallet'];

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Nhập tên ví');
      return;
    }
    final w = widget.wallet;
    if ((w == null || w.name.toLowerCase() != name.toLowerCase()) && await _controller.nameExists(name)) {
      setState(() => _nameError = 'Tên ví đã tồn tại');
      return;
    }
    final amount = parseAmount(_balance.text);
    // Giữ nguyên số dư (kể cả số âm) nếu người dùng không sửa ô này.
    final unchanged = w != null && _balance.text == formatNumber(w.balance);
    final value = unchanged ? w.balance : amount;
    setState(() => _saving = true);
    final ok = await runGuarded(context, () async {
      if (w == null) {
        await _controller.addWallet(name, _type, amount);
      } else {
        await _controller.updateWallet(w.id, name, _type, value);
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
    final w = widget.wallet!;
    final ok = await confirmDialog(
      context,
      title: 'Xóa ví ${w.name}?',
      message: 'Các giao dịch thuộc ví này sẽ được đánh dấu đã xóa và không còn tính vào số dư.',
      confirmLabel: 'Xóa',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final done = await runGuarded(context, () => _controller.deleteWallet(w.id));
    if (done && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: _isEditing ? 'Sửa ví' : 'Thêm ví',
      bottom: BottomPrimary(text: _isEditing ? 'Lưu thay đổi' : 'Lưu ví', onPressed: _save, loading: _saving),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LabeledInput(
            label: 'Tên ví',
            controller: _name,
            icon: Icons.account_balance_wallet_outlined,
            hint: 'Ví dụ: Ví MoMo',
            errorText: _nameError,
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          const FieldLabel('Loại ví'),
          ChipChoice<String>(values: _types, selected: _type, labelOf: WalletModel.typeLabel, onSelected: (v) => setState(() => _type = v)),
          LabeledInput(
            label: _isEditing ? 'Số dư hiện tại' : 'Số dư ban đầu',
            controller: _balance,
            icon: Icons.attach_money_rounded,
            amount: true,
            hint: '0',
          ),
          if (_isEditing) ...[
            const SizedBox(height: 16),
            TextButtonDanger(label: 'Xóa ví', onTap: _delete),
          ],
        ],
      ),
    );
  }
}
