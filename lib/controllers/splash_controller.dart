import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

class SplashController {
  final AuthRepository _repository = AuthRepository.instance;

  /// Check if there is an active session stored locally or in Firebase
  Future<UserModel?> checkExistingSession() async {
    try {
      return await _repository.getSavedSession();
    } catch (_) {
      return null;
    }
  }
}
