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
    required this.tariffs,
    this.staffPrices = const [],
  });

  final int id;
  final String title;
  final String description;
  final DateTime date;
  final String time;
  final DateTime dateTime;
  final double? price;
  final int maxSeats;
  final int bookedSeatsCount;
  final int availableSeatsCount;
  final List<ExcursionStaff> assignedStaff;
  final List<BusSeat> busSeats;
  final Map<String, ExcursionTariff> tariffs;
  final List<StaffPrice> staffPrices;

  bool get isPast => dateTime.isBefore(DateTime.now());

  factory Excursion.fromJson(Map<String, dynamic> json) {
    final seatsJson = json['bus_seats'] as List<dynamic>?;
    final staffJson = json['assigned_staff'] as List<dynamic>?;
    final pricesJson = json['prices'] as List<dynamic>?;
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
    return Excursion(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      date: date,
      time: json['time'] as String? ?? '',
      dateTime: dateTime,
      price: json['price'] != null
          ? double.tryParse(json['price'].toString())
          : null,
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
      tariffs: _parseTariffs(
        pricesJson,
        json['price'] != null
            ? double.tryParse(json['price'].toString()) ?? 0.0
            : 0.0,
      ),
      staffPrices: _parseStaffPrices(json['staff_prices'] as List<dynamic>?),
    );
  }

  static List<StaffPrice> _parseStaffPrices(List<dynamic>? staffPricesJson) {
    if (staffPricesJson == null || staffPricesJson.isEmpty) {
      return [];
    }
    return staffPricesJson
        .map((item) => StaffPrice.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Map<String, ExcursionTariff> _parseTariffs(
    List<dynamic>? pricesJson,
    double defaultPrice,
  ) {
    final defaultTariff = ExcursionTariff(
      price: defaultPrice,
      sellerCommissionPercent: 10,
      partnerCommissionPercent: 10,
      priceWithoutEntry: defaultPrice,
      priceWithEntry: defaultPrice,
    );

    if (pricesJson == null || pricesJson.isEmpty) {
      return {
        'adult': defaultTariff,
        'child': defaultTariff,
        'senior': defaultTariff,
        'disabled': defaultTariff,
      };
    }

    final map = <String, ExcursionTariff>{
      'adult': defaultTariff,
      'child': defaultTariff,
      'senior': defaultTariff,
      'disabled': defaultTariff,
    };

    for (final item in pricesJson) {
      final json = item as Map<String, dynamic>?;
      if (json == null) {
        continue;
      }
      final type = json['passenger_type'] as String?;
      if (type == null || type.isEmpty) {
        continue;
      }

      final priceValue =
          double.tryParse(json['price']?.toString() ?? '') ?? defaultPrice;
      final seller = double.tryParse(
            json['seller_commission_percent']?.toString() ?? '',
          ) ??
          10;
      final partner = double.tryParse(
            json['partner_commission_percent']?.toString() ?? '',
          ) ??
          10;
      final priceWithoutEntry = json['price_without_entry'] != null
          ? double.tryParse(json['price_without_entry']?.toString() ?? '')
          : null;
      final priceWithEntry = json['price_with_entry'] != null
          ? double.tryParse(json['price_with_entry']?.toString() ?? '')
          : null;

      map[type] = ExcursionTariff(
        price: priceValue,
        sellerCommissionPercent: seller,
        partnerCommissionPercent: partner,
        priceWithoutEntry: priceWithoutEntry ?? priceValue,
        priceWithEntry: priceWithEntry ?? priceValue,
      );
    }

    return map;
  }

  double priceFor(String passengerType) {
    return tariffs[passengerType]?.price ?? price ?? 0.0;
  }
}

class ExcursionTariff {
  const ExcursionTariff({
    required this.price,
    required this.sellerCommissionPercent,
    required this.partnerCommissionPercent,
    this.priceWithoutEntry,
    this.priceWithEntry,
  });

  final double price;
  final double sellerCommissionPercent;
  final double partnerCommissionPercent;
  final double? priceWithoutEntry;
  final double? priceWithEntry;
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

class StaffPrice {
  const StaffPrice({
    required this.staffType,
    required this.minPassengers,
    this.maxPassengers,
    required this.price,
  });

  final String staffType; // driver | guide
  final int minPassengers;
  final int? maxPassengers;
  final double price;

  factory StaffPrice.fromJson(Map<String, dynamic> json) {
    return StaffPrice(
      staffType: json['staff_type'] as String,
      minPassengers: json['min_passengers'] as int,
      maxPassengers: json['max_passengers'] as int?,
      price: double.tryParse(json['price'].toString()) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'staff_type': staffType,
      'min_passengers': minPassengers,
      'max_passengers': maxPassengers,
      'price': price,
    };
  }
}
