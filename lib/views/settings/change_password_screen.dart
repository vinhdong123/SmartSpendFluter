import 'package:material_ui/material_ui.dart';
import '../../controllers/auth_controller.dart';
import '../../repositories/auth_repository.dart';
import '../widgets/common_widgets.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/ui_kit.dart';

class ChangePasswordScreen extends StatefulWidget {
  final String email;
  const ChangePasswordScreen({super.key, required this.email});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  final AuthController _controller = AuthController();
  bool _loading = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await _controller.changePassword(email: widget.email, currentPassword: _current.text, newPassword: _new.text);
      if (!mounted) return;
      showSnack(context, 'Đã cập nhật mật khẩu');
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
    return Form(
      key: _formKey,
      child: SubPage(
        title: 'Đổi mật khẩu',
        bottom: BottomPrimary(text: 'Cập nhật mật khẩu', onPressed: _submit, loading: _loading),
        child: Column(
          children: [
            CustomTextField(
              label: 'Mật khẩu hiện tại',
              hint: 'Nhập mật khẩu hiện tại',
              controller: _current,
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: true,
              validator: (v) => (v == null || v.isEmpty) ? 'Nhập mật khẩu hiện tại' : null,
              enabled: !_loading,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              label: 'Mật khẩu mới',
              hint: 'Tối thiểu 8 ký tự',
              controller: _new,
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
              validator: (v) => _controller.validateConfirmPassword(v, _new.text),
              enabled: !_loading,
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
    );
  }
}
