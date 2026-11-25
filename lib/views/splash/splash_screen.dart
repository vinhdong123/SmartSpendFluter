import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../controllers/splash_controller.dart';
import '../auth/login_screen.dart';
import '../main/main_navigation_screen.dart';
import '../widgets/custom_button.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final SplashController _controller = SplashController();
  bool _loading = false;

  Future<void> _handleStart() async {
    setState(() => _loading = true);
    final user = await _controller.checkExistingSession();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => user != null ? MainNavigationScreen(user: user) : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 98,
                      height: 98,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 46),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'SmartSpend',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Quản lý chi tiêu thông minh, dùng được cả khi không có mạng',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, height: 1.4, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              PrimaryButton(text: 'Bắt đầu', onPressed: _handleStart, isLoading: _loading),
            ],
          ),
        ),
      ),
    );
  }
}
