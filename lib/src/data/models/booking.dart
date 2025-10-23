class BookingItem {
  const BookingItem({
    required this.id,
    required this.excursionId,
    required this.excursionTitle,
    required this.excursionDate,
    required this.seatNumber,
    required this.bookedAt,
  });

  final int id;
  final int excursionId;
  final String excursionTitle;
  final DateTime excursionDate;
  final int seatNumber;
  final DateTime bookedAt;

  factory BookingItem.fromJson(Map<String, dynamic> json) {
    final excursion = json['excursion'] as Map<String, dynamic>;
    return BookingItem(
      id: json['id'] as int,
      excursionId: excursion['id'] as int,
      excursionTitle: excursion['title'] as String,
      excursionDate: DateTime.parse(excursion['date_time'] as String),
      seatNumber: json['seat_number'] as int,
      bookedAt: DateTime.parse(json['booked_at'] as String),
    );
  }
}

class BookedSeat {
  const BookedSeat({
    required this.id,
    required this.seatNumber,
    required this.bookedAt,
  });

  final int id;
  final int seatNumber;
  final DateTime bookedAt;

  factory BookedSeat.fromJson(Map<String, dynamic> json) {
    return BookedSeat(
      id: json['id'] as int,
      seatNumber: json['seat_number'] as int,
      bookedAt: DateTime.parse(json['booked_at'] as String),
    );
  }
}

class BookingResponse {
  const BookingResponse({required this.message, required this.bookedSeats, this.errors});

  final String message;
  final List<BookedSeat> bookedSeats;
  final List<String>? errors;

  factory BookingResponse.fromJson(Map<String, dynamic> json) {
    final seats = (json['booked_seats'] as List<dynamic>?)
            ?.map((seat) => BookedSeat.fromJson(seat as Map<String, dynamic>))
            .toList() ??
        const [];
    return BookingResponse(
      message: json['message'] as String? ?? '',
      bookedSeats: seats,
      errors: (json['errors'] as List<dynamic>?)?.cast<String>(),
    );
  }
}
