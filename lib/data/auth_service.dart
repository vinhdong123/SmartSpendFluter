class AuthUser {
  const AuthUser({required this.fullName, required this.email});

  final String fullName;
  final String email;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return '?';
    }
    return parts.last.substring(0, 1).toUpperCase();
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final Map<String, _Account> _accounts = {
    'demo@smartspend.vn': const _Account(
      fullName: 'Người dùng Demo',
      password: '123456',
    ),
  };

  AuthUser? _currentUser;

  AuthUser? get currentUser => _currentUser;

  bool get isSignedIn => _currentUser != null;

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final normalizedEmail = email.trim().toLowerCase();
    final account = _accounts[normalizedEmail];
    if (account == null || account.password != password) {
      throw const AuthException('Email hoặc mật khẩu không chính xác.');
    }

    return _currentUser = AuthUser(
      fullName: account.fullName,
      email: normalizedEmail,
    );
  }

  Future<AuthUser> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final normalizedEmail = email.trim().toLowerCase();
    if (_accounts.containsKey(normalizedEmail)) {
      throw const AuthException('Email này đã được đăng ký.');
    }

    final normalizedName = fullName.trim();
    _accounts[normalizedEmail] = _Account(
      fullName: normalizedName,
      password: password,
    );

    return _currentUser = AuthUser(
      fullName: normalizedName,
      email: normalizedEmail,
    );
  }

  void logout() {
    _currentUser = null;
  }
}

class _Account {
  const _Account({required this.fullName, required this.password});

  final String fullName;
  final String password;
}
