import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/api_helpers.dart';
import '../models/user.dart';

class AuthRepository {
  AuthRepository(this._client);

  final ApiClient _client;

  User? _cachedUser;

  Future<User?> loadPersistedUser() async {
    final token = await _client.readStoredToken();
    if (token == null || token.isEmpty) {
      return null;
    }
    return fetchCurrentUser();
  }

  Future<User?> signIn(String email, String password) async {
    try {
      final response = await _client.postJson('/api/auth/login', body: {
        'email': email.trim(),
        'password': password.trim(),
      });
      final token = response['token'] as String?;
      final userJson = response['user'] as Map<String, dynamic>?;
      if (token == null || userJson == null) {
        return null;
      }
      await _client.storeToken(token);
      _cachedUser = User.fromJson(userJson);
      return _cachedUser;
    } on ApiException {
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _client.post('/api/auth/logout', authenticated: true);
    } catch (_) {
      // ignore network errors on logout
    }
    await _client.clearToken();
    _cachedUser = null;
  }

  Future<User?> fetchCurrentUser() async {
    try {
      final response = await _client.getJson('/api/auth/me', authenticated: true);
      final userJson = response['user'] as Map<String, dynamic>?;
      if (userJson == null) {
        return null;
      }
      _cachedUser = User.fromJson(userJson);
      return _cachedUser;
    } on ApiException catch (_) {
      await _client.clearToken();
      return null;
    }
  }
}
