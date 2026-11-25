import 'package:material_ui/material_ui.dart';
import '../../controllers/auth_controller.dart';
import '../../repositories/auth_repository.dart';
import '../widgets/common_widgets.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/ui_kit.dart';
import '../main/main_navigation_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final AuthController _controller = AuthController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      final user = await _controller.register(
        fullName: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        agreeTerms: true,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => MainNavigationScreen(user: user)),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Đã có lỗi xảy ra: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SubPage(
        title: 'Tạo tài khoản',
        bottom: BottomPrimary(text: 'Tạo tài khoản', onPressed: _handleRegister, loading: _isLoading),
        child: Column(
          children: [
            CustomTextField(
              label: 'Họ và tên',
              hint: 'Nguyễn Văn A',
              controller: _nameController,
              prefixIcon: Icons.person_outline_rounded,
              keyboardType: TextInputType.name,
              validator: _controller.validateFullName,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              label: 'Email',
              hint: 'ban@email.com',
              controller: _emailController,
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: _controller.validateEmail,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              label: 'Mật khẩu',
              hint: 'Tối thiểu 8 ký tự',
              controller: _passwordController,
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: true,
              validator: _controller.validatePassword,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              label: 'Xác nhận mật khẩu',
              hint: 'Nhập lại mật khẩu',
              controller: _confirmController,
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: true,
              textInputAction: TextInputAction.done,
              validator: (v) => _controller.validateConfirmPassword(v, _passwordController.text),
              enabled: !_isLoading,
              onFieldSubmitted: (_) => _handleRegister(),
            ),
            const SizedBox(height: 18),
            const InfoBanner(
              icon: Icons.cloud_outlined,
              title: 'Dữ liệu lưu trên máy trước',
              subtitle: 'Đăng ký để sao lưu và đồng bộ lên đám mây',
            ),
          ],
        ),
      ),
    );
  }
}
