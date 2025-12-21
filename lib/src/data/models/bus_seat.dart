class BusSeat {
  const BusSeat({
    required this.id,
    required this.seatNumber,
    required this.status,
    this.bookedBy,
    this.bookedAt,
    this.booking,
  });

  final int id;
  final int seatNumber;
  final String status;
  final int? bookedBy;
  final DateTime? bookedAt;
  final BusSeatBooking? booking;

  factory BusSeat.fromJson(Map<String, dynamic> json) {
    return BusSeat(
      id: (json['id'] as num?)?.toInt() ?? 0,
      seatNumber: (json['seat_number'] as num?)?.toInt() ?? 0,
      status: json['status'] as String,
      bookedBy: json['booked_by'] as int?,
      bookedAt: json['booked_at'] == null
          ? null
          : DateTime.parse(json['booked_at'] as String),
      booking: json['booking'] == null
          ? null
          : BusSeatBooking.fromJson(json['booking'] as Map<String, dynamic>),
    );
  }
}

class BusSeatBooking {
  const BusSeatBooking({
    required this.customerName,
    required this.customerPhone,
    required this.passengerType,
    this.stopId,
    this.stopTitle,
    this.stopOrder,
  });

  final String customerName;
  final String customerPhone;
  final String passengerType;
  final int? stopId;
  final String? stopTitle;
  final int? stopOrder;

  factory BusSeatBooking.fromJson(Map<String, dynamic> json) {
    return BusSeatBooking(
      customerName: json['customer_name'] as String? ?? '',
      customerPhone: json['customer_phone'] as String? ?? '',
      passengerType: json['passenger_type'] as String? ?? '',
      stopId: (json['stop_id'] as num?)?.toInt(),
      stopTitle: json['stop_title'] as String?,
      stopOrder: (json['stop_order'] as num?)?.toInt(),
    );
  }
}
