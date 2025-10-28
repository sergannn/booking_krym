import 'bus_seat.dart';

class Excursion {
  const Excursion({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.time,
    required this.dateTime,
    required this.price,
    required this.maxSeats,
    required this.bookedSeatsCount,
    required this.availableSeatsCount,
    required this.assignedStaff,
    required this.busSeats,
  });

  final int id;
  final String title;
  final String description;
  final DateTime date;
  final String time;
  final DateTime dateTime;
  final double price;
  final int maxSeats;
  final int bookedSeatsCount;
  final int availableSeatsCount;
  final List<ExcursionStaff> assignedStaff;
  final List<BusSeat> busSeats;

  bool get isPast => dateTime.isBefore(DateTime.now());

  factory Excursion.fromJson(Map<String, dynamic> json) {
    final seatsJson = json['bus_seats'] as List<dynamic>?;
    final staffJson = json['assigned_staff'] as List<dynamic>?;
    final dateTime = DateTime.parse(json['date_time'] as String);
    return Excursion(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? dateTime,
      time: json['time'] as String? ?? '',
      dateTime: dateTime,
      price: double.parse(json['price'].toString()),
      maxSeats: json['max_seats'] as int,
      bookedSeatsCount: json['booked_seats_count'] as int? ?? 0,
      availableSeatsCount: json['available_seats_count'] as int? ?? 0,
      assignedStaff: staffJson == null
          ? const []
          : staffJson
              .map((item) =>
                  ExcursionStaff.fromJson(item as Map<String, dynamic>))
              .toList(),
      busSeats: seatsJson == null
          ? const []
          : seatsJson
              .map((seat) => BusSeat.fromJson(seat as Map<String, dynamic>))
              .toList(),
    );
  }
}

class ExcursionStaff {
  const ExcursionStaff({
    required this.id,
    required this.name,
    required this.email,
    required this.roleInExcursion,
  });

  final int id;
  final String name;
  final String email;
  final String roleInExcursion; // driver | guide

  factory ExcursionStaff.fromJson(Map<String, dynamic> json) {
    return ExcursionStaff(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      roleInExcursion: json['role_in_excursion'] as String? ?? '',
    );
  }
}
