import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../repositories/auth_repository.dart';
import '../widgets/common_widgets.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../main/main_navigation_screen.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthController _controller = AuthController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      final user = await _controller.login(email: _emailController.text, password: _passwordController.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MainNavigationScreen(user: user)));
    } on AuthException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Đã có lỗi xảy ra: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleGoogleSignIn() {
    showSnack(context, 'Đăng nhập Google cần cấu hình thêm (SHA-1 trong Firebase). Hiện hãy dùng email và mật khẩu.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Chào mừng trở lại',
                          style: TextStyle(fontSize: 28, height: 1.3, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      const Text('Đăng nhập để đồng bộ dữ liệu của bạn',
                          style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
                      const SizedBox(height: 18),
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
                        hint: 'Nhập mật khẩu',
                        controller: _passwordController,
                        prefixIcon: Icons.lock_outline_rounded,
                        isPassword: true,
                        textInputAction: TextInputAction.done,
                        validator: _controller.validatePassword,
                        enabled: !_isLoading,
                        onFieldSubmitted: (_) => _handleLogin(),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => ForgotPasswordScreen(initialEmail: _emailController.text)),
                                  ),
                          child: const Text('Quên mật khẩu?',
                              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                        ),
                      ),
                      GoogleSignInButton(onPressed: _handleGoogleSignIn, isLoading: _isLoading),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                          child: const Text('Chưa có tài khoản? Đăng ký',
                              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: PrimaryButton(text: 'Đăng nhập', onPressed: _handleLogin, isLoading: _isLoading),
            ),
          ],
        ),
      ),
    );
  }
}
