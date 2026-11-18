import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'sqlite_database_service.dart';

class LocalStorageService {
  LocalStorageService._();
  static final LocalStorageService instance = LocalStorageService._();

  static const String _currentUserKey = 'current_user_session';
  final SQLiteDatabaseService _sqlite = SQLiteDatabaseService.instance;

  /// Save current logged-in user session locally
  Future<void> saveUserSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
  }

  /// Get current logged-in user session
  Future<UserModel?> getUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_currentUserKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return null;
    }
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Clear logged-in user session
  Future<void> clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
  }

  /// Save user credential into SQLite Database
  Future<void> saveLocalUser(UserModel user, String password) async {
    await _sqlite.insertUser(user, password);
  }

  /// Authenticate against SQLite Database
  Future<UserModel?> loginLocal(String email, String password) async {
    return await _sqlite.getUserByEmailAndPassword(email, password);
  }

  /// Check if user exists in SQLite Database
  Future<bool> isLocalUserExists(String email) async {
    return await _sqlite.isUserExists(email);
  }
}
