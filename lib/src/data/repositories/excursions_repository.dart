import '../../core/api/api_client.dart';
import '../../core/api/api_helpers.dart';
import '../models/excursion.dart';

class ExcursionsRepository {
  ExcursionsRepository(this._client);

  final ApiClient _client;

  Future<List<Excursion>> fetchExcursions() async {
    final response =
        await _client.getJson('/api/excursions', authenticated: true);
    final data = response['data'] as List<dynamic>?;
    if (data == null) {
      return const [];
    }
    return data
        .map((json) => Excursion.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Excursion?> fetchExcursion(int id) async {
    final response =
        await _client.getJson('/api/excursions/$id', authenticated: true);
    final data = response['data'];
    if (data == null) {
      return null;
    }
    return Excursion.fromJson(data as Map<String, dynamic>);
  }

  Future<Excursion> createExcursion({
    required String title,
    required String description,
    required DateTime dateTime,
    required double price,
    required int maxSeats,
    required bool isActive,
  }) async {
    final response = await _client.postJson(
      '/api/excursions',
      authenticated: true,
      body: {
        'title': title,
        'description': description,
        'date_time': dateTime.toIso8601String(),
        'price': price,
        'max_seats': maxSeats,
        'is_active': isActive,
      },
    );
    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw const FormatException(
          'Неверный ответ сервера при создании экскурсии');
    }
    return Excursion.fromJson(data);
  }
}
