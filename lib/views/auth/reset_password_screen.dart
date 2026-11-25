import 'package:material_ui/material_ui.dart';
import '../../controllers/auth_controller.dart';
import '../../repositories/auth_repository.dart';
import '../widgets/common_widgets.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/ui_kit.dart';

/// Đặt lại mật khẩu cho tài khoản tạo ngoại tuyến trên máy này (liên kết hiệu lực 30 phút).
class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final AuthController _controller = AuthController();
  bool _loading = false;
  Duration? _remaining;

  @override
  void initState() {
    super.initState();
    _controller.resetLinkRemaining(widget.email).then((d) {
      if (mounted) setState(() => _remaining = d);
    });
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await _controller.resetPasswordLocal(widget.email, _password.text);
      if (!mounted) return;
      showSnack(context, 'Đã đặt lại mật khẩu. Hãy đăng nhập bằng mật khẩu mới.');
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Đã có lỗi xảy ra: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _remaining != null;
    return Form(
      key: _formKey,
      child: SubPage(
        title: 'Đặt lại mật khẩu',
        bottom: BottomPrimary(text: 'Đặt lại mật khẩu', onPressed: valid ? _submit : null, loading: _loading),
        child: Column(
          children: [
            CustomTextField(
              label: 'Mật khẩu mới',
              hint: 'Tối thiểu 8 ký tự',
              controller: _password,
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: true,
              validator: _controller.validatePassword,
              enabled: !_loading,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              label: 'Xác nhận mật khẩu mới',
              hint: 'Nhập lại mật khẩu',
              controller: _confirm,
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: true,
              textInputAction: TextInputAction.done,
              validator: (v) => _controller.validateConfirmPassword(v, _password.text),
              enabled: !_loading,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 18),
            InfoBanner(
              icon: valid ? Icons.check_rounded : Icons.error_outline_rounded,
              tone: valid ? BannerTone.success : BannerTone.danger,
              title: valid ? 'Liên kết hợp lệ' : 'Liên kết đã hết hạn',
              subtitle: valid
                  ? 'Liên kết sẽ hết hạn sau ${_remaining!.inMinutes + 1} phút'
                  : 'Quay lại và yêu cầu liên kết mới',
            ),
          ],
        ),
      ),
    );
  }
}
