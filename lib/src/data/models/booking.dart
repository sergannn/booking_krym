import 'package:collection/collection.dart';

import 'stop.dart';

class BookingGroup {
  const BookingGroup({
    required this.excursion,
    required this.bookings,
  });

  final BookingExcursion excursion;
  final List<BookingItem> bookings;

  factory BookingGroup.fromList(List<BookingItem> items) {
    final first = items.first;
    return BookingGroup(
      excursion: first.excursion,
      bookings: items,
    );
  }
}

class BookingExcursion {
  const BookingExcursion({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.dateTime,
    required this.price,
  });

  final int id;
  final String title;
  final DateTime date;
  final String time;
  final DateTime dateTime;
  final double price;

  factory BookingExcursion.fromJson(Map<String, dynamic> json) {
    final dateTime = DateTime.parse(json['date_time'] as String);
    // Создаем date в том же часовом поясе, что и dateTime
    final date = DateTime(
        dateTime.year,
        dateTime.month,
        dateTime.day,
        dateTime.hour,
        dateTime.minute,
        dateTime.second,
        dateTime.millisecond,
        dateTime.microsecond);
    return BookingExcursion(
      id: json['id'] as int,
      title: json['title'] as String,
      date: date,
      time: json['time'] as String? ?? '',
      dateTime: dateTime,
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0,
    );
  }
}

class BookingItem {
  const BookingItem({
    required this.id,
    required this.excursion,
    required this.seat,
    required this.price,
    required this.customerName,
    required this.customerPhone,
    required this.passengerType,
    required this.stop,
    required this.bookedAt,
  });

  final int id;
  final BookingExcursion excursion;
  final BookingSeat seat;
  final double price;
  final String customerName;
  final String customerPhone;
  final PassengerType passengerType;
  final Stop? stop;
  final DateTime bookedAt;

  factory BookingItem.fromJson(Map<String, dynamic> json) {
    BookingSeat parseSeat() {
      final seatJson = json['bus_seat'];
      if (seatJson is Map<String, dynamic>) {
        return BookingSeat.fromJson(seatJson);
      }
      final seatNumberRaw = json['seat_number'];
      final seatNumber = seatNumberRaw is int
          ? seatNumberRaw
          : int.tryParse(seatNumberRaw?.toString() ?? '') ?? 0;
      final seatId = json['bus_seat_id'] as int? ?? 0;
      return BookingSeat(id: seatId, seatNumber: seatNumber);
    }

    DateTime parseBookedAt() {
      final raw = json['booked_at'] ?? json['created_at'];
      if (raw is String && raw.isNotEmpty) {
        return DateTime.parse(raw);
      }
      return DateTime.now();
    }

    return BookingItem(
      id: json['id'] as int,
      excursion:
          BookingExcursion.fromJson(json['excursion'] as Map<String, dynamic>),
      seat: parseSeat(),
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0,
      customerName: json['customer_name'] as String? ?? '',
      customerPhone: json['customer_phone']?.toString() ?? '',
      passengerType:
          PassengerTypeX.fromJson(json['passenger_type'] as String? ?? ''),
      stop: json['stop'] == null
          ? null
          : Stop.fromJson(json['stop'] as Map<String, dynamic>),
      bookedAt: parseBookedAt(),
    );
  }
}

class BookingSeat {
  const BookingSeat({
    required this.id,
    required this.seatNumber,
  });

  final int id;
  final int seatNumber;

  factory BookingSeat.fromJson(Map<String, dynamic> json) {
    return BookingSeat(
      id: json['id'] as int,
      seatNumber: json['seat_number'] is int
          ? json['seat_number'] as int
          : int.tryParse(json['seat_number'].toString()) ?? 0,
    );
  }
}

class BookingResponse {
  const BookingResponse({required this.message, this.errors});

  final String message;
  final List<String>? errors;

  factory BookingResponse.fromJson(Map<String, dynamic> json) {
    return BookingResponse(
      message: json['message'] as String? ?? '',
      errors: (json['errors'] as List<dynamic>?)?.cast<String>(),
    );
  }
}

enum PassengerType { adult, child, senior, disabled }

extension PassengerTypeX on PassengerType {
  String get apiValue => name;

  String get label {
    switch (this) {
      case PassengerType.adult:
        return 'Взрослый';
      case PassengerType.child:
        return 'Детский';
      case PassengerType.senior:
        return 'Пенсионер';
      case PassengerType.disabled:
        return 'Инвалид';
    }
  }

  static PassengerType fromJson(String value) {
    return PassengerType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => PassengerType.adult,
    );
  }
}

List<BookingGroup> groupBookingsByExcursion(List<BookingItem> items) {
  final grouped = groupBy(items, (item) => item.excursion.id);
  return grouped.values.map(BookingGroup.fromList).toList();
}
