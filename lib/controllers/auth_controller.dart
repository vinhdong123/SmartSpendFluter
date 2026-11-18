import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

class AuthController {
  final AuthRepository _repository = AuthRepository.instance;

  // Form Validation Logic
  String? validateFullName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) {
      return 'Vui lòng nhập họ và tên';
    }
    if (name.length < 2) {
      return 'Họ và tên quá ngắn';
    }
    return null;
  }

  String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Vui lòng nhập email';
    }
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegExp.hasMatch(email)) {
      return 'Email không hợp lệ (ví dụ: email@vidu.com)';
    }
    return null;
  }

  String? validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }
    if (password.length < 8) {
      return 'Tối thiểu 8 ký tự';
    }
    return null;
  }

  String? validateConfirmPassword(String? value, String originalPassword) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập lại mật khẩu';
    }
    if (value != originalPassword) {
      return 'Mật khẩu nhập lại không khớp';
    }
    return null;
  }

  /// Execute Login
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    return await _repository.login(
      email: email,
      password: password,
    );
  }

  /// Execute Register
  Future<UserModel> register({
    required String fullName,
    required String email,
    required String password,
    required bool agreeTerms,
  }) async {
    if (!agreeTerms) {
      throw const AuthException('Bạn cần đồng ý với Điều khoản sử dụng để đăng ký.');
    }
    return await _repository.register(
      fullName: fullName,
      email: email,
      password: password,
    );
  }

  /// Logout
  Future<void> logout() async {
    await _repository.logout();
  }
}
