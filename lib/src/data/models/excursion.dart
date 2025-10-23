import 'bus_seat.dart';

class Excursion {
  const Excursion({
    required this.id,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.price,
    required this.maxSeats,
    required this.bookedSeatsCount,
    required this.availableSeatsCount,
    required this.busSeats,
  });

  final int id;
  final String title;
  final String description;
  final DateTime dateTime;
  final double price;
  final int maxSeats;
  final int bookedSeatsCount;
  final int availableSeatsCount;
  final List<BusSeat> busSeats;

  factory Excursion.fromJson(Map<String, dynamic> json) {
    final seatsJson = json['bus_seats'] as List<dynamic>?;
    return Excursion(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      dateTime: DateTime.parse(json['date_time'] as String),
      price: double.parse(json['price'].toString()),
      maxSeats: json['max_seats'] as int,
      bookedSeatsCount: json['booked_seats_count'] as int? ?? 0,
      availableSeatsCount: json['available_seats_count'] as int? ?? 0,
      busSeats: seatsJson == null
          ? const []
          : seatsJson
              .map((seat) => BusSeat.fromJson(seat as Map<String, dynamic>))
              .toList(),
    );
  }
}
