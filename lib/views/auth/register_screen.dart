import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../repositories/auth_repository.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../main/main_navigation_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthController _controller = AuthController();

  bool _agreeTerms = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (!_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn cần đồng ý với Điều khoản sử dụng để đăng ký.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await _controller.register(
        fullName: _fullNameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        agreeTerms: _agreeTerms,
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => MainNavigationScreen(user: user)),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã có lỗi xảy ra: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Tạo tài khoản',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subtitle
                    const Text(
                      'Chỉ mất một phút để bắt đầu quản lý chi tiêu',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Họ và tên
                    CustomTextField(
                      label: 'Họ và tên',
                      hint: 'Nguyễn Văn A',
                      controller: _fullNameController,
                      prefixIcon: Icons.person_outline_rounded,
                      keyboardType: TextInputType.name,
                      validator: _controller.validateFullName,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 16),

                    // Email
                    CustomTextField(
                      label: 'Email',
                      hint: 'email@vidu.com',
                      controller: _emailController,
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: _controller.validateEmail,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 16),

                    // Mật khẩu
                    CustomTextField(
                      label: 'Mật khẩu',
                      hint: 'Tối thiểu 8 ký tự',
                      controller: _passwordController,
                      prefixIcon: Icons.lock_outline_rounded,
                      isPassword: true,
                      validator: _controller.validatePassword,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 16),

                    // Nhập lại mật khẩu
                    CustomTextField(
                      label: 'Nhập lại mật khẩu',
                      hint: 'Nhập lại mật khẩu',
                      controller: _confirmPasswordController,
                      prefixIcon: Icons.lock_outline_rounded,
                      isPassword: true,
                      textInputAction: TextInputAction.done,
                      validator: (val) => _controller.validateConfirmPassword(
                        val,
                        _passwordController.text,
                      ),
                      enabled: !_isLoading,
                      onFieldSubmitted: (_) => _handleRegister(),
                    ),
                    const SizedBox(height: 16),

                    // Checkbox Terms
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _agreeTerms,
                            activeColor: AppColors.primaryTeal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: _isLoading
                                ? null
                                : (val) {
                                    setState(() {
                                      _agreeTerms = val ?? false;
                                    });
                                  },
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Tôi đồng ý với Điều khoản sử dụng',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Primary Button "Đăng ký"
                    PrimaryButton(
                      text: 'Đăng ký',
                      onPressed: _handleRegister,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 20),

                    // Footer Text "Đã có tài khoản? Đăng nhập"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Đã có tài khoản? ',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text(
                            'Đăng nhập',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryTeal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
