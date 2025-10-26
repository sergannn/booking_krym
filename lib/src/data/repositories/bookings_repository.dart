import '../../core/api/api_client.dart';
import '../../core/api/api_helpers.dart';
import '../models/booking.dart';

class BookingsRepository {
  BookingsRepository(this._client);

  final ApiClient _client;

  Future<List<BookingGroup>> fetchBookings() async {
    final response = await _client.getJson('/api/bookings', authenticated: true);
    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) {
      return const [];
    }
    return data.entries
        .map((entry) => BookingGroup.fromJson(entry))
        .toList();
  }

  Future<BookingResponse> bookSeats({
    required int excursionId,
    required List<int> seatNumbers,
  }) async {
    final response = await _client.postJson(
      '/api/bookings',
      authenticated: true,
      body: {
        'excursion_id': excursionId,
        'seat_numbers': seatNumbers,
      },
    );
    return BookingResponse.fromJson(response);
  }

  Future<void> cancelBooking(int bookingId) async {
    await _client.deleteJson('/api/bookings/$bookingId', authenticated: true);
  }
}
