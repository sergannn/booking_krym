import 'dart:convert';

import 'api_client.dart';

extension HttpResponseJson on ApiClient {
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    final response = await post(path, body: body, authenticated: authenticated);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
    bool authenticated = false,
  }) async {
    final response = await get(path, query: query, authenticated: authenticated);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    bool authenticated = false,
  }) async {
    final response = await delete(path, authenticated: authenticated);
    if (response.body.isEmpty) {
      return const {};
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
