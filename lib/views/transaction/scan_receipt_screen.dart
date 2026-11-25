import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../widgets/common_widgets.dart';
import '../widgets/custom_button.dart';
import '../widgets/ui_kit.dart';

/// Chụp hoặc chọn ảnh hóa đơn. Trả về đường dẫn ảnh (hoặc null nếu hủy).
class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _path;
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final file = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (file != null && mounted) setState(() => _path = file.path);
    } catch (e) {
      if (mounted) showSnack(context, 'Không thể mở ${source == ImageSource.camera ? 'camera' : 'thư viện'}: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    return SubPage(
      title: 'Quét hóa đơn',
      closeIcon: true,
      scroll: false,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (path == null) ...[
            PrimaryButton(text: 'Chụp ảnh', onPressed: _busy ? null : () => _pick(ImageSource.camera)),
            const SizedBox(height: 10),
            OutlineAppButton(text: 'Chọn từ thư viện', onPressed: _busy ? null : () => _pick(ImageSource.gallery)),
          ] else ...[
            PrimaryButton(text: 'Dùng ảnh này', onPressed: () => Navigator.of(context).pop(path)),
            const SizedBox(height: 10),
            OutlineAppButton(text: 'Chụp / chọn lại', onPressed: _busy ? null : () => setState(() => _path = null)),
          ],
        ],
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(color: const Color(0xFF1A3430), borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: path != null
            ? Image.file(File(path), fit: BoxFit.contain)
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, color: Colors.white, size: 72),
                  SizedBox(height: 12),
                  Text('Đặt hóa đơn vào khung', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
      ),
    );
  }
}
