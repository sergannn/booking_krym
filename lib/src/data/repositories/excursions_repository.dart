import '../../core/api/api_client.dart';
import '../../core/api/api_helpers.dart';
import '../models/excursion.dart';

class ExcursionsRepository {
  ExcursionsRepository(this._client);

  final ApiClient _client;

  Future<List<Excursion>> fetchExcursions() async {
    final response = await _client.getJson('/api/excursions', authenticated: true);
    final data = response['data'] as List<dynamic>?;
    if (data == null) {
      return const [];
    }
    return data
        .map((json) => Excursion.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Excursion?> fetchExcursion(int id) async {
    final response = await _client.getJson('/api/excursions/$id', authenticated: true);
    final data = response['data'];
    if (data == null) {
      return null;
    }
    return Excursion.fromJson(data as Map<String, dynamic>);
  }
}
