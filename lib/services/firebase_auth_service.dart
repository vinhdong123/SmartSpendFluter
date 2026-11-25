import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../models/user_model.dart';

class FirebaseAuthService {
  FirebaseAuthService._();
  static final FirebaseAuthService instance = FirebaseAuthService._();

  bool get isFirebaseAvailable {
    try {
      fb.FirebaseAuth.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Register new user using Firebase Authentication
  Future<UserModel?> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    if (!isFirebaseAvailable) return null;

    final credential = await fb.FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final fbUser = credential.user;
    if (fbUser != null) {
      await fbUser.updateDisplayName(fullName.trim());
      return UserModel(
        uid: fbUser.uid,
        fullName: fullName.trim(),
        email: email.trim(),
        createdAt: DateTime.now(),
      );
    }
    return null;
  }

  /// Sign in using Firebase Authentication
  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    if (!isFirebaseAvailable) return null;

    final credential = await fb.FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final fbUser = credential.user;
    if (fbUser != null) {
      return UserModel(
        uid: fbUser.uid,
        fullName: fbUser.displayName ?? email.split('@').first,
        email: fbUser.email ?? email,
        createdAt: DateTime.now(),
      );
    }
    return null;
  }

  /// Gửi email đặt lại mật khẩu. Trả về false nếu không có Firebase hoặc không có tài khoản.
  Future<bool> sendPasswordReset(String email) async {
    if (!isFirebaseAvailable) return false;
    try {
      await fb.FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      return true;
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-email') return false;
      rethrow;
    }
  }

  /// Đổi mật khẩu cho người dùng Firebase đang đăng nhập (cần xác thực lại).
  /// Trả về false nếu hiện không có phiên Firebase.
  Future<bool> changePassword({required String currentPassword, required String newPassword}) async {
    if (!isFirebaseAvailable) return false;
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return false;
    final credential = fb.EmailAuthProvider.credential(email: user.email!, password: currentPassword);
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
    return true;
  }

  /// Sign out from Firebase
  Future<void> signOut() async {
    if (isFirebaseAvailable) {
      await fb.FirebaseAuth.instance.signOut();
    }
  }

  /// Get current Firebase user
  UserModel? getCurrentUser() {
    if (!isFirebaseAvailable) return null;
    final fbUser = fb.FirebaseAuth.instance.currentUser;
    if (fbUser == null) return null;
    return UserModel(
      uid: fbUser.uid,
      fullName: fbUser.displayName ?? fbUser.email?.split('@').first ?? 'User',
      email: fbUser.email ?? '',
      createdAt: DateTime.now(),
    );
  }
}
