class BookingGroup {
  const BookingGroup({
    required this.excursion,
    required this.seats,
  });

  final BookingExcursion excursion;
  final List<BookingSeat> seats;

  factory BookingGroup.fromJson(MapEntry<String, dynamic> entry) {
    final value = entry.value as Map<String, dynamic>;
    final excursion = BookingExcursion.fromJson(value['excursion'] as Map<String, dynamic>);
    final seats = (value['seats'] as List<dynamic>? ?? const [])
        .map((json) => BookingSeat.fromJson(json as Map<String, dynamic>))
        .toList();
    return BookingGroup(excursion: excursion, seats: seats);
  }
}

class BookingExcursion {
  const BookingExcursion({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.price,
  });

  final int id;
  final String title;
  final DateTime dateTime;
  final double price;

  factory BookingExcursion.fromJson(Map<String, dynamic> json) {
    return BookingExcursion(
      id: json['id'] as int,
      title: json['title'] as String,
      dateTime: DateTime.parse(json['date_time'] as String),
      price: double.parse(json['price'].toString()),
    );
  }
}

class BookingSeat {
  const BookingSeat({
    required this.id,
    required this.seatNumber,
    required this.bookedAt,
  });

  final int id;
  final int seatNumber;
  final DateTime bookedAt;

  factory BookingSeat.fromJson(Map<String, dynamic> json) {
    return BookingSeat(
      id: json['id'] as int,
      seatNumber: json['seat_number'] as int,
      bookedAt: DateTime.parse(json['booked_at'] as String),
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
