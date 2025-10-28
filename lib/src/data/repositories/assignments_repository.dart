import '../../core/api/api_client.dart';
import '../../core/api/api_helpers.dart';

class AssignmentsRepository {
  AssignmentsRepository(this._client);

  final ApiClient _client;

  Future<void> assignStaff({
    required int excursionId,
    required List<Map<String, dynamic>> assignments,
  }) async {
    await _client.postJson(
      '/api/excursions/$excursionId/assign',
      authenticated: true,
      body: {
        'assignments': assignments,
      },
    );
  }

  Future<void> unassignStaff({
    required int excursionId,
    required int userId,
  }) async {
    await _client.deleteJson(
      '/api/excursions/$excursionId/assign/$userId',
      authenticated: true,
    );
  }
}
