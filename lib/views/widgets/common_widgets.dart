import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import 'custom_button.dart';

/// Thanh chuyển tab dạng viên thuốc (Tuần/Tháng/Năm, Nhóm/Khoản nợ...).
class SegmentedTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.primary100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected == i ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected == i ? FontWeight.bold : FontWeight.w500,
                      color: selected == i ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Khung thẻ trắng bo góc.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: box,
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(color: AppColors.lightMint, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.primaryTeal, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryTeal),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

void showSnack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? AppColors.error : AppColors.textPrimary,
      ),
    );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Đồng ý',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: destructive ? AppColors.expense50 : AppColors.primary100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                destructive ? Icons.delete_outline_rounded : Icons.help_outline_rounded,
                color: destructive ? AppColors.expense : AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Hủy', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: destructive ? AppColors.expense50 : AppColors.primary,
                        foregroundColor: destructive ? AppColors.expense : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

/// Bottom sheet cuộn được, tự né bàn phím.
Future<T?> showAppSheet<T>(BuildContext context, {required Widget Function(BuildContext) builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: builder(ctx),
        ),
      ),
    ),
  );
}

class SheetHeader extends StatelessWidget {
  final String title;
  const SheetHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class PickerOption<T> {
  final String label;
  final T value;
  final IconData? icon;
  const PickerOption(this.label, this.value, {this.icon});
}

/// Chọn một mục trong danh sách. Trả về null nếu người dùng đóng sheet.
Future<PickerOption<T>?> showPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<PickerOption<T>> options,
  T? selected,
}) {
  return showAppSheet<PickerOption<T>>(
    context,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SheetHeader(title),
        for (final o in options)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: o.icon == null ? null : Icon(o.icon, color: AppColors.primaryTeal),
            title: Text(
              o.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: o.value == selected ? FontWeight.bold : FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            trailing: o.value == selected
                ? const Icon(Icons.check_rounded, color: AppColors.primaryTeal)
                : null,
            onTap: () => Navigator.of(ctx).pop(o),
          ),
      ],
    ),
  );
}

/// Ô nhập số tiền có dấu chấm ngăn cách hàng nghìn.
class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? errorText;
  final bool autofocus;

  const AmountField({
    super.key,
    required this.controller,
    this.label = 'Số tiền',
    this.errorText,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [ThousandsSeparatorFormatter()],
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'đ',
        errorText: errorText,
      ),
    );
  }
}

/// Dialog nhập một số tiền. Trả về null nếu hủy.
Future<int?> showAmountDialog(
  BuildContext context, {
  required String title,
  String? message,
  int? initial,
  int? max,
  String confirmLabel = 'Lưu',
  bool allowZero = false,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _AmountDialog(
      title: title,
      message: message,
      initial: initial,
      max: max,
      confirmLabel: confirmLabel,
      allowZero: allowZero,
    ),
  );
}

class _AmountDialog extends StatefulWidget {
  final String title;
  final String? message;
  final int? initial;
  final int? max;
  final String confirmLabel;
  final bool allowZero;

  const _AmountDialog({
    required this.title,
    required this.message,
    required this.initial,
    required this.max,
    required this.confirmLabel,
    required this.allowZero,
  });

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial == null || widget.initial == 0 ? '' : formatNumber(widget.initial!),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = parseAmount(_controller.text);
    if (value <= 0 && !widget.allowZero) {
      setState(() => _error = 'Vui lòng nhập số tiền lớn hơn 0');
      return;
    }
    if (widget.max != null && value > widget.max!) {
      setState(() => _error = 'Tối đa ${formatVND(widget.max!)}');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message != null) ...[
            Text(widget.message!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
          ],
          AmountField(controller: _controller, autofocus: true, errorText: _error),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            widget.confirmLabel,
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryTeal),
          ),
        ),
      ],
    );
  }
}

/// Dãy ChoiceChip chọn một giá trị.
class ChipSelector extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  const ChipSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(o),
            selected: selected == o,
            onSelected: (_) => onSelected(o),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.primary100,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            labelStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected == o ? Colors.white : AppColors.textPrimary,
            ),
            showCheckmark: false,
          ),
      ],
    );
  }
}

/// Nút "Lưu" chuẩn trong sheet.
class SheetSubmit extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  const SheetSubmit({super.key, required this.label, required this.onPressed, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: PrimaryButton(text: label, onPressed: onPressed, isLoading: isLoading),
    );
  }
}

Future<DateTime?> pickDate(
  BuildContext context, {
  DateTime? initial,
  DateTime? first,
  DateTime? last,
}) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: first ?? DateTime(now.year - 5),
    lastDate: last ?? DateTime(now.year + 5),
  );
}
