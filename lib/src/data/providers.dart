import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import 'models/booking.dart';
import 'models/excursion.dart';
import 'repositories/auth_repository.dart';
import 'repositories/excursions_repository.dart';
import 'repositories/bookings_repository.dart';

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

final excursionsFutureProvider = FutureProvider<List<Excursion>>((ref) {
  final repository = ref.watch(excursionsRepositoryProvider);
  return repository.fetchExcursions();
});

final bookingsFutureProvider = FutureProvider<List<BookingGroup>>((ref) {
  final repository = ref.watch(bookingsRepositoryProvider);
  return repository.fetchBookings();
});
