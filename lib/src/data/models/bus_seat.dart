class BusSeat {
  const BusSeat({
    required this.id,
    required this.seatNumber,
    required this.status,
    this.bookedBy,
    this.bookedAt,
  });

  final int id;
  final int seatNumber;
  final String status;
  final int? bookedBy;
  final DateTime? bookedAt;

  factory BusSeat.fromJson(Map<String, dynamic> json) {
    return BusSeat(
      id: json['id'] as int,
      seatNumber: json['seat_number'] as int,
      status: json['status'] as String,
      bookedBy: json['booked_by'] as int?,
      bookedAt: json['booked_at'] == null
          ? null
          : DateTime.parse(json['booked_at'] as String),
    );
  }
}
