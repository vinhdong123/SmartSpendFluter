import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../controllers/wallet_goal_controller.dart';
import '../../models/wallet_model.dart';
import '../widgets/common_widgets.dart';

class WalletsScreen extends StatefulWidget {
  const WalletsScreen({super.key});

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  final WalletController _controller = WalletController();
  List<WalletModel> _wallets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _controller.fetchWallets();
    if (!mounted) return;
    setState(() {
      _wallets = list;
      _isLoading = false;
    });
  }

  Future<void> _addWallet() async {
    final created = await showAppSheet<bool>(
      context,
      builder: (ctx) => _WalletForm(controller: _controller),
    );
    if (created == true) _load();
  }

  Future<void> _editInitialBalance(WalletModel w) async {
    final value = await showAmountDialog(
      context,
      title: 'Số dư ban đầu – ${w.name}',
      message: 'Số tiền bạn đang có trong ví trước khi bắt đầu ghi chép. Số dư hiện tại = số dư ban đầu + thu − chi.',
      initial: w.initialBalance,
      allowZero: true,
    );
    if (value == null) return;
    await _controller.setInitialBalance(w.id, value);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final total = _wallets.fold<int>(0, (sum, w) => sum + w.balance);
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Ví của tôi'),
        actions: [IconButton(icon: const Icon(Icons.add_rounded), onPressed: _addWallet)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tổng số dư', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
                      const SizedBox(height: 6),
                      Text(
                        formatVND(total),
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (int i = 0; i < _wallets.length; i++) ...[
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.lightMint,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(_wallets[i].icon, color: AppColors.primaryTeal, size: 20),
                          ),
                          title: Text(
                            _wallets[i].name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          subtitle: Text(
                            '${WalletModel.typeLabel(_wallets[i].type)} · ban đầu ${formatVND(_wallets[i].initialBalance)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          trailing: Text(
                            formatVND(_wallets[i].balance),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _wallets[i].balance < 0 ? AppColors.error : AppColors.textPrimary,
                            ),
                          ),
                          onTap: () => _editInitialBalance(_wallets[i]),
                        ),
                        if (i < _wallets.length - 1) const Divider(height: 1, indent: 64, color: AppColors.border),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Chạm vào ví để chỉnh số dư ban đầu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ],
            ),
    );
  }
}

class _WalletForm extends StatefulWidget {
  final WalletController controller;
  const _WalletForm({required this.controller});

  @override
  State<_WalletForm> createState() => _WalletFormState();
}

class _WalletFormState extends State<_WalletForm> {
  final _name = TextEditingController();
  final _initial = TextEditingController();
  String _type = 'cash';
  String? _nameError;
  bool _saving = false;

  static const _types = {'Tiền mặt': 'cash', 'Ví điện tử': 'ewallet', 'Ngân hàng': 'bank'};

  @override
  void dispose() {
    _name.dispose();
    _initial.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Vui lòng nhập tên ví');
      return;
    }
    if (await widget.controller.nameExists(name)) {
      setState(() => _nameError = 'Tên ví đã tồn tại');
      return;
    }
    setState(() {
      _nameError = null;
      _saving = true;
    });
    try {
      await widget.controller.addWallet(name, _type, parseAmount(_initial.text));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, 'Lỗi: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedLabel = _types.entries.firstWhere((e) => e.value == _type).key;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetHeader('Thêm ví'),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: 'Tên ví', errorText: _nameError),
        ),
        const SizedBox(height: 12),
        ChipSelector(
          options: _types.keys.toList(),
          selected: selectedLabel,
          onSelected: (v) => setState(() => _type = _types[v]!),
        ),
        const SizedBox(height: 12),
        AmountField(controller: _initial, label: 'Số dư ban đầu'),
        SheetSubmit(label: 'Thêm ví', onPressed: _save, isLoading: _saving),
      ],
    );
  }
}
