import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_database.dart';
import 'models.dart';
import 'repositories/auth_repository.dart';

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  return LocalDatabase.instance;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return AuthRepository(db);
});

final usersProvider = Provider<List<UserProfile>>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return db.usersBox.values.toList();
});
