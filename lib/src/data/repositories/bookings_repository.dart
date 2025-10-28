import '../../core/api/api_client.dart';
import '../../core/api/api_helpers.dart';
import '../models/booking.dart';

class BookSeatPayload {
  const BookSeatPayload({
    required this.excursionId,
    required this.seatNumbers,
    required this.price,
    required this.customerName,
    required this.customerPhone,
    required this.passengerType,
    required this.stopId,
  });

  final int excursionId;
  final List<int> seatNumbers;
  final double price;
  final String customerName;
  final String customerPhone;
  final PassengerType passengerType;
  final int stopId;

  Map<String, dynamic> toJson() {
    return {
      'excursion_id': excursionId,
      'seat_numbers': seatNumbers,
      'price': price,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'passenger_type': passengerType.apiValue,
      'stop_id': stopId,
    };
  }
}

class BookingsRepository {
  BookingsRepository(this._client);

  final ApiClient _client;

  Future<List<BookingGroup>> fetchBookings() async {
    final response =
        await _client.getJson('/api/bookings', authenticated: true);
    final items = response['bookings'] as List<dynamic>? ?? const [];
    final bookingItems = items
        .map((item) =>
            BookingItem.fromJson(item as Map<String, dynamic>))
        .toList();
    return groupBookingsByExcursion(bookingItems);
  }

  Future<BookingResponse> bookSeats(BookSeatPayload payload) async {
    final response = await _client.postJson(
      '/api/bookings',
      authenticated: true,
      body: payload.toJson(),
    );
    return BookingResponse.fromJson(response);
  }

  Future<void> cancelBooking(int bookingId) async {
    await _client.deleteJson('/api/bookings/$bookingId', authenticated: true);
  }
}
