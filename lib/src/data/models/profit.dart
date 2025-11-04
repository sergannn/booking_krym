import 'booking.dart';
import 'wallet.dart';

class ProfitInfo {
  const ProfitInfo({
    required this.user,
    required this.totalProfit,
    required this.breakdown,
    required this.totalsByType,
    required this.isPartner,
  });

  final WalletUser user;
  final double totalProfit;
  final List<ProfitItem> breakdown;
  final Map<PassengerType, ProfitTotals> totalsByType;
  final bool isPartner;

  factory ProfitInfo.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    return ProfitInfo(
      user: WalletUser.fromJson((userJson as Map<String, dynamic>?) ?? const {}),
      totalProfit: double.tryParse(json['total_profit'].toString()) ?? 0,
      breakdown: (json['breakdown'] as List<dynamic>? ?? const [])
          .map((item) => ProfitItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalsByType: _parseTotalsByType(
        json['totals_by_type'] as Map<String, dynamic>? ?? const {},
      ),
      isPartner: (json['is_partner'] as bool?) ??
          ((userJson is Map<String, dynamic>)
              ? (userJson['is_partner'] as bool? ?? false)
              : false),
    );
  }

  static Map<PassengerType, ProfitTotals> _parseTotalsByType(
    Map<String, dynamic> json,
  ) {
    final result = <PassengerType, ProfitTotals>{};
    for (final entry in json.entries) {
      final passengerType = PassengerTypeX.fromJson(entry.key);
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        result[passengerType] = ProfitTotals(
          sales: double.tryParse(value['sales']?.toString() ?? '') ?? 0,
          commission:
              double.tryParse(value['commission']?.toString() ?? '') ?? 0,
        );
      }
    }
    return result;
  }
}

class ProfitItem {
  const ProfitItem({
    required this.bookingId,
    required this.excursion,
    required this.passengerType,
    required this.price,
    required this.commissionPercent,
    required this.commissionAmount,
    required this.bookedAt,
  });

  final int bookingId;
  final ProfitExcursion excursion;
  final PassengerType passengerType;
  final double price;
  final double commissionPercent;
  final double commissionAmount;
  final DateTime bookedAt;

  factory ProfitItem.fromJson(Map<String, dynamic> json) {
    return ProfitItem(
      bookingId: json['booking_id'] as int,
      excursion: ProfitExcursion.fromJson(
        json['excursion'] as Map<String, dynamic>,
      ),
      passengerType: PassengerTypeX.fromJson(
        json['passenger_type'] as String? ?? '',
      ),
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0,
      commissionPercent:
          double.tryParse(json['commission_percent']?.toString() ?? '') ?? 0,
      commissionAmount:
          double.tryParse(json['commission_amount']?.toString() ?? '') ?? 0,
      bookedAt: DateTime.parse(json['booked_at'] as String),
    );
  }
}

class ProfitExcursion {
  const ProfitExcursion({
    required this.id,
    required this.title,
    required this.dateTime,
  });

  final int id;
  final String title;
  final DateTime dateTime;

  factory ProfitExcursion.fromJson(Map<String, dynamic> json) {
    return ProfitExcursion(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      dateTime: DateTime.parse(json['date_time'] as String),
    );
  }
}

class ProfitTotals {
  const ProfitTotals({
    required this.sales,
    required this.commission,
  });

  final double sales;
  final double commission;
}
