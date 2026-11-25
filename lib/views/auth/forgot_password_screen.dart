import 'package:material_ui/material_ui.dart';
import '../../controllers/auth_controller.dart';
import '../../repositories/auth_repository.dart';
import '../widgets/common_widgets.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/ui_kit.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email = TextEditingController(text: widget.initialEmail);
  final AuthController _controller = AuthController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final result = await _controller.requestPasswordReset(_email.text);
      if (!mounted) return;
      if (result.emailed) {
        showSnack(context, 'Đã gửi liên kết đặt lại mật khẩu tới ${_email.text.trim()}. Hãy kiểm tra hộp thư.');
      }
      if (result.canResetHere) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: _email.text.trim())),
        );
      } else if (mounted) {
        Navigator.of(context).pop();
      }
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
    return Form(
      key: _formKey,
      child: SubPage(
        title: 'Quên mật khẩu',
        bottom: BottomPrimary(text: 'Gửi liên kết đặt lại', onPressed: _send, loading: _loading),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập email đã đăng ký, chúng tôi sẽ gửi liên kết để đặt lại mật khẩu.',
              style: TextStyle(fontSize: 15, height: 1.4, color: Color(0xFF526B66)),
            ),
            const SizedBox(height: 14),
            CustomTextField(
              label: 'Email',
              hint: 'ban@email.com',
              controller: _email,
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              validator: _controller.validateEmail,
              enabled: !_loading,
              onFieldSubmitted: (_) => _send(),
            ),
          ],
        ),
      ),
    );
  }
}
