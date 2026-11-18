import '../models/user_model.dart';
import '../services/firebase_auth_service.dart';
import '../services/local_storage_service.dart';

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository._();
  static final AuthRepository instance = AuthRepository._();

  final FirebaseAuthService _firebaseAuth = FirebaseAuthService.instance;
  final LocalStorageService _localStorage = LocalStorageService.instance;

  /// Perform Registration (Firebase + Local Storage)
  Future<UserModel> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedName = fullName.trim();

    // Check if user exists locally
    final isLocalExists = await _localStorage.isLocalUserExists(normalizedEmail);
    if (isLocalExists) {
      throw const AuthException('Email này đã được đăng ký trên thiết bị.');
    }

    UserModel? user;

    // 1. Try Firebase Auth
    try {
      user = await _firebaseAuth.signUp(
        fullName: normalizedName,
        email: normalizedEmail,
        password: password,
      );
    } catch (e) {
      // Firebase throws e.g. email-already-in-use or weak-password
      final errorStr = e.toString();
      if (errorStr.contains('email-already-in-use')) {
        throw const AuthException('Email này đã được sử dụng ở Firebase.');
      } else if (errorStr.contains('weak-password')) {
        throw const AuthException('Mật khẩu quá yếu.');
      }
      // If Firebase core not initialized or network error, fallback to local creation
    }

    // 2. Create User Model if Firebase was bypassed/unavailable
    user ??= UserModel(
      uid: 'local_${DateTime.now().millisecondsSinceEpoch}',
      fullName: normalizedName,
      email: normalizedEmail,
      createdAt: DateTime.now(),
    );

    // 3. Save to Local Storage (both database record and active session)
    await _localStorage.saveLocalUser(user, password);
    await _localStorage.saveUserSession(user);

    return user;
  }

  /// Perform Login (Firebase + Local Storage)
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    // Demo account fallback check
    if (normalizedEmail == 'demo@smartspend.vn' && password == '12345678') {
      final demoUser = UserModel(
        uid: 'demo_user_id',
        fullName: 'Nguyễn Văn Demo',
        email: normalizedEmail,
        createdAt: DateTime.now(),
      );
      await _localStorage.saveUserSession(demoUser);
      return demoUser;
    }

    UserModel? user;

    // 1. Try Firebase Authentication first
    try {
      user = await _firebaseAuth.signIn(
        email: normalizedEmail,
        password: password,
      );
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('user-not-found') || errorStr.contains('wrong-password') || errorStr.contains('invalid-credential')) {
        throw const AuthException('Email hoặc mật khẩu không chính xác.');
      }
    }

    // 2. If Firebase did not return a user, fallback to Local Storage authentication
    user ??= await _localStorage.loginLocal(normalizedEmail, password);

    if (user == null) {
      throw const AuthException('Email hoặc mật khẩu không chính xác.');
    }

    // 3. Save active session to Local Storage
    await _localStorage.saveUserSession(user);

    return user;
  }

  /// Get current session
  Future<UserModel?> getSavedSession() async {
    // Check local session
    final localSession = await _localStorage.getUserSession();
    if (localSession != null) {
      return localSession;
    }
    // Check firebase session
    return _firebaseAuth.getCurrentUser();
  }

  /// Logout
  Future<void> logout() async {
    await _firebaseAuth.signOut();
    await _localStorage.clearUserSession();
  }
}
