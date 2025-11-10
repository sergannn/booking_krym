import 'dart:typed_data';

import '../../core/api/api_client.dart';
import '../../core/api/api_helpers.dart';
import '../models/booking.dart';

class SeatBooking {
  const SeatBooking({
    required this.seatNumber,
    required this.passengerType,
  });

  final int seatNumber;
  final PassengerType passengerType;

  Map<String, dynamic> toJson() {
    return {
      'seat_number': seatNumber,
      'passenger_type': passengerType.apiValue,
    };
  }
}

class BookSeatPayload {
  BookSeatPayload({
    required this.excursionId,
    required this.customerName,
    required this.customerPhone,
    required this.stopId,
    // Новый формат: массив мест с типами пассажиров
    this.seats,
    // Старый формат (для обратной совместимости)
    this.seatNumbers,
    this.passengerType,
  }) : assert(
          (seats != null && seats.isNotEmpty) ||
              (seatNumbers != null &&
                  seatNumbers.isNotEmpty &&
                  passengerType != null),
          'Either seats or seatNumbers with passengerType must be provided',
        );

  final int excursionId;
  final String customerName;
  final String customerPhone;
  final int stopId;

  // Новый формат: массив мест с типами пассажиров
  final List<SeatBooking>? seats;

  // Старый формат (для обратной совместимости)
  final List<int>? seatNumbers;
  final PassengerType? passengerType;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'excursion_id': excursionId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'stop_id': stopId,
    };

    // Используем новый формат, если доступен
    if (seats != null && seats!.isNotEmpty) {
      json['seats'] = seats!.map((s) => s.toJson()).toList();
    } else if (seatNumbers != null &&
        seatNumbers!.isNotEmpty &&
        passengerType != null) {
      // Старый формат для обратной совместимости
      json['seat_numbers'] = seatNumbers!;
      json['passenger_type'] = passengerType!.apiValue;
    }

    return json;
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
        .map((item) => BookingItem.fromJson(item as Map<String, dynamic>))
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

  Future<void> cancelBooking(int bookingId, {required String reason}) async {
    await _client.deleteJson(
      '/api/bookings/$bookingId',
      authenticated: true,
      body: {
        'reason': reason,
      },
    );
  }

  /// Получает полный URL для скачивания PDF билета
  String getTicketPdfUrl(int bookingId) {
    // Получаем base URL из ApiClient
    final baseUrl = _client.baseUrl;
    final path = '/api/bookings/$bookingId/ticket-pdf';

    // Если baseUrl заканчивается на /, убираем его
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    // Строим полный URL
    return '$normalizedBase$path';
  }

  /// Скачивает PDF билет как байты (для сохранения/отправки на мобильных)
  Future<Uint8List> downloadTicketPdf(int bookingId) async {
    final response = await _client.get(
      '/api/bookings/$bookingId/ticket-pdf',
      authenticated: true,
      headers: {
        'Accept': 'application/pdf',
      },
    );
    return Uint8List.fromList(response.bodyBytes);
  }
}
