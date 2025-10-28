import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import 'models/booking.dart';
import 'models/excursion.dart';
import 'models/stop.dart';
import 'models/user_role_info.dart';
import 'models/user_summary.dart';
import 'repositories/auth_repository.dart';
import 'repositories/excursions_repository.dart';
import 'repositories/bookings_repository.dart';
import 'repositories/assignments_repository.dart';
import 'repositories/stops_repository.dart';
import 'repositories/users_repository.dart';
import 'repositories/wallet_repository.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient.instance;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return AuthRepository(client);
});

final excursionsRepositoryProvider = Provider<ExcursionsRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ExcursionsRepository(client);
});

final bookingsRepositoryProvider = Provider<BookingsRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return BookingsRepository(client);
});

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return UsersRepository(client);
});

final stopsRepositoryProvider = Provider<StopsRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return StopsRepository(client);
});

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return WalletRepository(client);
});

final assignmentsRepositoryProvider = Provider<AssignmentsRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return AssignmentsRepository(client);
});

final excursionsFutureProvider = FutureProvider<List<Excursion>>((ref) {
  final repository = ref.watch(excursionsRepositoryProvider);
  return repository.fetchExcursions();
});

final bookingsFutureProvider = FutureProvider<List<BookingGroup>>((ref) {
  final repository = ref.watch(bookingsRepositoryProvider);
  return repository.fetchBookings();
});

final stopsFutureProvider = FutureProvider<List<Stop>>((ref) {
  final repository = ref.watch(stopsRepositoryProvider);
  return repository.fetchStops();
});

final allUsersFutureProvider = FutureProvider<List<UserSummary>>((ref) {
  final repository = ref.watch(usersRepositoryProvider);
  return repository.fetchUsers();
});

final userRolesFutureProvider = FutureProvider<List<UserRoleInfo>>((ref) {
  final repository = ref.watch(usersRepositoryProvider);
  return repository.fetchRoles();
});
