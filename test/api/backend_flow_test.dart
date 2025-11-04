import 'package:test/test.dart';

import 'package:booking_app/src/core/api/api_client.dart';
import 'package:booking_app/src/core/api/api_helpers.dart';
import 'package:booking_app/src/core/api/api_exception.dart';
import 'package:booking_app/src/data/repositories/auth_repository.dart';
import 'package:booking_app/src/data/repositories/wallet_repository.dart';
import 'package:booking_app/src/data/repositories/users_repository.dart';
import 'package:booking_app/src/data/repositories/bookings_repository.dart';
import 'package:booking_app/src/data/models/booking.dart';

class _InMemoryTokenProvider implements TokenProvider {
  String? _token;

  @override
  Future<void> clearToken() async {
    _token = null;
  }

  @override
  Future<String?> getToken() async => _token;

  @override
  Future<void> saveToken(String token) async {
    _token = token;
  }
}

void main() {
  const baseUrl = 'https://excursion.panfilius.ru/api';

  group('Backend flow smoke', () {
    ApiClient createClient() {
      final client = ApiClient.create();
      client.configure(
        baseUrl: baseUrl,
        tokenProvider: _InMemoryTokenProvider(),
      );
      return client;
    }

    test('seller profit matches 10% if sales exist', () async {
      const email = 'anna@excursion.ru';
      const password = 'password';

      final client = createClient();
      final authRepository = AuthRepository(client);
      final walletRepository = WalletRepository(client);

      final user = await authRepository.signIn(email, password);
      expect(user, isNotNull, reason: 'Seller credentials must be valid');

      final sales = await walletRepository.fetchSales(user!.id);
      final profit = await walletRepository.fetchProfit(user.id);

      if (sales.totalSales > 0) {
        final expected = double.parse((sales.totalSales * 0.1).toStringAsFixed(2));
        final actual = double.parse(profit.totalProfit.toStringAsFixed(2));
        expect(actual, equals(expected));
        expect(profit.isPartner, isFalse);
      } else {
        expect(profit.totalProfit, equals(0));
        expect(profit.breakdown, isEmpty);
      }
    });

    test('partner profit flag is true and commission values present', () async {
      const adminEmail = 'admin@excursion.ru';
      const adminPassword = 'password';

      final adminClient = createClient();
      final authRepository = AuthRepository(adminClient);
      final usersRepository = UsersRepository(adminClient);
      final walletRepository = WalletRepository(adminClient);

      final admin = await authRepository.signIn(adminEmail, adminPassword);
      expect(admin, isNotNull, reason: 'Admin credentials must be valid');

      final partnerEmail = 'partner-api-${DateTime.now().millisecondsSinceEpoch}@example.com';
      final partner = await usersRepository.createUser(
        name: 'API Partner',
        email: partnerEmail,
        password: 'password',
        roleId: 4,
      );

      final partnerClient = createClient();
      final partnerAuth = AuthRepository(partnerClient);
      final partnerUser = await partnerAuth.signIn(partnerEmail, 'password');
      expect(partnerUser, isNotNull, reason: 'Partner user should log in');

      final profit = await walletRepository.fetchProfit(partnerUser!.id);

      expect(profit.isPartner, isTrue);
      if (profit.breakdown.isNotEmpty) {
        for (final item in profit.breakdown) {
          final expected = double.parse(
            (item.price * item.commissionPercent / 100).toStringAsFixed(2),
          );
          final actual = double.parse(item.commissionAmount.toStringAsFixed(2));
          expect(actual, equals(expected));
        }
      }

      await usersRepository.deleteUser(partner.id);
    });

    test('admin can fetch excursions and ensure schedule present', () async {
      const email = 'admin@excursion.ru';
      const password = 'password';

      final client = createClient();
      final authRepository = AuthRepository(client);

      final user = await authRepository.signIn(email, password);
      expect(user, isNotNull, reason: 'Admin credentials must be valid');

      final response = await client.getJson('/api/excursions', authenticated: true);
      final excursions = response['data'] as List<dynamic>?;
      expect(excursions, isNotNull, reason: 'Excursion list should be present');
      expect(excursions!.length, greaterThan(0), reason: 'Auto-schedule must create excursions');
    });

    test('admin create/delete user updates list', () async {
      const email = 'admin@excursion.ru';
      const password = 'password';

      final client = createClient();
      final authRepository = AuthRepository(client);
      final usersRepository = UsersRepository(client);

      final admin = await authRepository.signIn(email, password);
      expect(admin, isNotNull);

      final before = await usersRepository.fetchUsers();
      final newUserEmail = 'api-test-${DateTime.now().millisecondsSinceEpoch}@example.com';

      final created = await usersRepository.createUser(
        name: 'API Test User',
        email: newUserEmail,
        password: 'password',
        roleId: 2, // seller role
      );

      final afterCreate = await usersRepository.fetchUsers();
      expect(afterCreate.length, before.length + 1);
      expect(afterCreate.any((user) => user.email == newUserEmail), isTrue);

      await usersRepository.deleteUser(created.id);

      final afterDelete = await usersRepository.fetchUsers();
      expect(afterDelete.length, before.length);
      expect(afterDelete.any((user) => user.email == newUserEmail), isFalse);
    });

    test('cancellation guard under 24h returns 422', () async {
      const email = 'admin@excursion.ru';
      const password = 'password';

      final client = createClient();
      final authRepository = AuthRepository(client);
      final bookingsRepository = BookingsRepository(client);

      final user = await authRepository.signIn(email, password);
      expect(user, isNotNull);

      final bookings = await bookingsRepository.fetchBookings();
      final nearExcursion = bookings
          .expand((group) => group.bookings)
          .firstWhere(
            (booking) => booking.excursion.dateTime.difference(DateTime.now()).inHours < 24,
            orElse: () => throw TestFailure('No booking within 24h to test cancellation guard'),
          );

      expect(
        () async => bookingsRepository.cancelBooking(nearExcursion.id, reason: 'Тест <24 ч'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 422)),
      );
    });

    test('booking creates wallet transaction and cancellation reverts', () async {
      const email = 'anna@excursion.ru';
      const password = 'password';

      final client = createClient();
      final authRepository = AuthRepository(client);
      final walletRepository = WalletRepository(client);
      final bookingsRepository = BookingsRepository(client);

      final seller = await authRepository.signIn(email, password);
      expect(seller, isNotNull);

      final excursionsJson = await client.getJson('/api/excursions', authenticated: true);
      final excursions = excursionsJson['data'] as List<dynamic>? ?? const [];
      final targetExcursion = excursions.firstWhere(
        (item) => (item['available_seats_count'] as int?) != null &&
            (item['available_seats_count'] as int) > 0,
      ) as Map<String, dynamic>;

      final excursionId = targetExcursion['id'] as int;
      final availableSeats = targetExcursion['bus_seats'] as List<dynamic>? ?? const [];
      final seatNumber = (availableSeats.firstWhere(
        (seat) => seat['status'] == 'available',
      ) as Map<String, dynamic>)['seat_number'] as int;

      final stopResponse = await client.getJson('/api/stops', authenticated: true);
      final stops = stopResponse['stops'] as List<dynamic>? ?? const [];
      final stopId = (stops.first as Map<String, dynamic>)['id'] as int;

      final walletBefore = await walletRepository.fetchWallet(seller!.id);

      await bookingsRepository.bookSeats(
        BookSeatPayload(
          excursionId: excursionId,
          seatNumbers: [seatNumber],
          customerName: 'API Тест',
          customerPhone: '+7 999 000-00-00',
          passengerType: PassengerType.adult,
          stopId: stopId,
        ),
      );

      final walletAfterBooking = await walletRepository.fetchWallet(seller.id);
      expect(walletAfterBooking.balance, greaterThanOrEqualTo(walletBefore.balance));

      final bookings = await bookingsRepository.fetchBookings();
      final createdBooking = bookings
          .expand((group) => group.bookings)
          .firstWhere((booking) => booking.seat.seatNumber == seatNumber);

      await bookingsRepository.cancelBooking(createdBooking.id, reason: 'API автотест');

      final walletAfterCancel = await walletRepository.fetchWallet(seller.id);
      expect(
        double.parse(walletAfterCancel.balance.toStringAsFixed(2)),
        closeTo(double.parse(walletBefore.balance.toStringAsFixed(2)), 0.01),
      );
    });
  });
}
