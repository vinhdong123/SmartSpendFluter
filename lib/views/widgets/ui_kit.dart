import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/transaction_model.dart';
import 'common_widgets.dart';
import 'custom_button.dart';

/// Nút vuông bo góc có viền (chuông, bộ lọc, quay lại...). Vùng chạm 44x44.
class SquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final bool dot;

  const SquareIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = AppColors.textPrimary,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            if (dot)
              Positioned(
                top: 9,
                right: 10,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: AppColors.expense,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Trang con chuẩn: [<] Tiêu đề ... [hành động], nội dung cuộn, nút cố định phía dưới.
class SubPage extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final Widget child;
  final Widget? bottom;
  final bool closeIcon;
  final Color background;
  final bool scroll;

  const SubPage({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.bottom,
    this.closeIcon = false,
    this.background = Colors.white,
    this.scroll = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  SquareIconButton(
                    icon: closeIcon ? Icons.close_rounded : Icons.chevron_left_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ),
                  for (final a in actions) ...[const SizedBox(width: 8), a],
                ],
              ),
            ),
            Expanded(
              child: scroll
                  ? SingleChildScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      child: child,
                    )
                  : Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0), child: child),
            ),
            if (bottom != null)
              Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: bottom),
          ],
        ),
      ),
    );
  }
}

/// Nhãn nhỏ phía trên ô nhập.
class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 14),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
    );
  }
}

/// Ô nhập có nhãn phía trên và icon đầu dòng.
class LabeledInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String? hint;
  final TextInputType keyboardType;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool amount;
  final int maxLines;
  final TextCapitalization capitalization;
  final bool enabled;

  const LabeledInput({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    this.hint,
    this.keyboardType = TextInputType.text,
    this.errorText,
    this.onChanged,
    this.amount = false,
    this.maxLines = 1,
    this.capitalization = TextCapitalization.sentences,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          onChanged: onChanged,
          textCapitalization: capitalization,
          keyboardType: amount ? TextInputType.number : keyboardType,
          inputFormatters: amount ? [ThousandsSeparatorFormatter()] : null,
          style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            prefixIcon: Icon(icon, size: 20),
            suffixText: amount ? 'đ' : null,
          ),
        ),
      ],
    );
  }
}

/// Hộp chọn (mở bảng chọn khi chạm): icon + giá trị + mũi tên.
class LabeledSelect extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final VoidCallback? onTap;
  final bool showChevron;

  const LabeledSelect({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
                ),
                if (showChevron && onTap != null)
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Ô vuông bo góc chứa icon (nền nhạt, icon đậm).
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  const IconBadge({
    super.key,
    required this.icon,
    this.color = AppColors.primary,
    this.background = AppColors.primary100,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(size > 48 ? 16 : 12)),
      child: Icon(icon, color: color, size: size * 0.48),
    );
  }
}

enum BannerTone { primary, warning, danger, success, savings }

/// Khung thông báo màu nhạt (icon + tiêu đề + mô tả).
class InfoBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final BannerTone tone;
  final VoidCallback? onTap;

  const InfoBanner({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.tone = BannerTone.primary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    late Color bg, fg, sub;
    switch (tone) {
      case BannerTone.warning:
        bg = AppColors.warning50;
        fg = AppColors.warning700;
        sub = AppColors.textSecondary;
      case BannerTone.danger:
        bg = AppColors.expense50;
        fg = AppColors.expense;
        sub = AppColors.textSecondary;
      case BannerTone.success:
        bg = AppColors.income50;
        fg = AppColors.income;
        sub = AppColors.textSecondary;
      case BannerTone.savings:
        bg = AppColors.savings50;
        fg = AppColors.savings600;
        sub = AppColors.textSecondary;
      case BannerTone.primary:
        bg = AppColors.primary100;
        fg = AppColors.primary;
        sub = AppColors.textSecondary;
    }
    final titleColor = tone == BannerTone.primary || tone == BannerTone.success || tone == BannerTone.savings
        ? AppColors.textPrimary
        : fg;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(icon, color: fg, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: titleColor)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: TextStyle(fontSize: 13, color: sub)),
                  ],
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right_rounded, color: fg),
          ],
        ),
      ),
    );
  }
}

/// Thanh tiến độ bo tròn.
class AppProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final Color background;
  final double height;

  const AppProgressBar({
    super.key,
    required this.value,
    this.color = AppColors.primary,
    this.background = AppColors.primary100,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: background,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(color: color),
        ),
      ),
    );
  }
}

/// Màu thanh ngân sách: xanh -> vàng khi gần hạn mức -> đỏ khi vượt.
Color budgetColor(int percent, {bool over = false}) {
  if (over) return AppColors.expense;
  if (percent >= 80) return AppColors.accent;
  return AppColors.primary;
}

/// Thẻ nhỏ "nhãn + giá trị" (Thu / Chi...).
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const StatCard({super.key, required this.label, required this.value, this.valueColor = AppColors.textPrimary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: valueColor)),
        ],
      ),
    );
  }
}

/// Thẻ trắng viền mảnh, bo 16.
class OutlineCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final VoidCallback? onTap;

  const OutlineCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      ),
    );
  }
}

/// Một dòng trong thẻ danh sách: [icon] tiêu đề / phụ đề ... trailing.
class ListRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const ListRow({super.key, required this.leading, required this.title, this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  if (subtitle != null)
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

/// Thẻ chứa nhiều dòng, ngăn cách bằng đường kẻ.
class ListCard extends StatelessWidget {
  final List<Widget> children;
  const ListCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return OutlineCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

/// Dòng giao dịch dùng ở Trang chủ, Lịch sử, Ngân sách.
class TxRow extends StatelessWidget {
  final TransactionModel tx;
  final VoidCallback? onTap;

  const TxRow({super.key, required this.tx, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = tx.isExpense ? AppColors.expense : AppColors.income;
    return ListRow(
      onTap: onTap,
      leading: IconBadge(
        icon: tx.categoryIcon,
        color: color,
        background: tx.isExpense ? AppColors.expense50 : AppColors.income50,
        size: 48,
      ),
      title: tx.title,
      subtitle: tx.category,
      trailing: Text(tx.formattedAmount,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// Tiêu đề nhóm nhỏ màu mờ.
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
    );
  }
}

/// Tiêu đề mục đậm (H2 nhỏ).
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Lựa chọn một giá trị bằng chip (vd. loại ví, ngưỡng cảnh báo).
class ChipChoice<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  const ChipChoice({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values)
          GestureDetector(
            onTap: () => onSelected(v),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: v == selected ? AppColors.primary : AppColors.primary100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                labelOf(v),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: v == selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Chọn ngày (trả về null nếu hủy).
Future<DateTime?> pickDate(BuildContext context, DateTime initial, {DateTime? first, DateTime? last}) {
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first ?? DateTime(2000),
    lastDate: last ?? DateTime(2100),
  );
}

/// Trang chủ nhập một thao tác lưu: chạy [action], hiện lỗi nếu có.
Future<bool> runGuarded(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
    return true;
  } catch (e) {
    if (context.mounted) {
      final text = e.toString().replaceFirst(RegExp(r'^(Exception|Bad state|Invalid argument\(s\)): ?'), '');
      showSnack(context, text, isError: true);
    }
    return false;
  }
}

/// Nút chính cố định cuối trang.
class BottomPrimary extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;

  const BottomPrimary({super.key, required this.text, required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) => PrimaryButton(text: text, onPressed: onPressed, isLoading: loading);
}
