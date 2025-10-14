import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../local_database.dart';
import '../models.dart';

class AuthRepository {
  AuthRepository(this._database);

  final LocalDatabase _database;

  static const _userKey = 'current_user_id';

  Future<UserProfile?> loadPersistedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userKey);
    if (userId == null || userId.isEmpty) {
      return null;
    }
    return _database.usersBox.get(userId);
  }

  Future<UserProfile?> signIn(String login, String password) async {
    final users = _database.usersBox.values;
    final matched = users.firstWhereOrNull(
      (user) => user.login == login.trim() && user.password == password.trim(),
    );
    if (matched == null) {
      return null;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, matched.id);
    return matched;
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  Future<UserProfile?> refreshUser(String userId) async {
    return _database.usersBox.get(userId);
  }
}
