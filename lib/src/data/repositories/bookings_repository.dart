import '../../core/api/api_client.dart';
import '../../core/api/api_helpers.dart';
import '../models/booking.dart';

class BookingsRepository {
  BookingsRepository(this._client);

  final ApiClient _client;

  Future<List<BookingItem>> fetchBookings() async {
    final response = await _client.getJson('/api/bookings', authenticated: true);
    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) {
      return const [];
    }
    final items = <BookingItem>[];
    for (final entry in data.entries) {
      final seats = (entry.value['seats'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
      for (final seat in seats) {
        items.add(BookingItem.fromJson({
          ...seat,
          'excursion': entry.value['excursion'] as Map<String, dynamic>,
        }));
      }
    }
    return items;
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
