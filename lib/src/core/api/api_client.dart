import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

abstract class TokenProvider {
  Future<String?> getToken();
  Future<void> saveToken(String token);
  Future<void> clearToken();
}

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  late String _baseUrl;
  late TokenProvider _tokenProvider;
  final http.Client _client = http.Client();

  void configure({required String baseUrl, required TokenProvider tokenProvider}) {
    _baseUrl = baseUrl;
    _tokenProvider = tokenProvider;
  }

  Uri _buildUri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse(_baseUrl).replace(
      path: path.startsWith('/') ? path : '/$path',
      queryParameters: query?.map((key, value) => MapEntry(key, '$value')),
    );
  }

  Map<String, String> _baseHeaders([Map<String, String>? extra]) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (extra != null) ...extra,
    };
  }

  Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    final headers = await _headers(authenticated: authenticated);
    final response = await _client.post(
      _buildUri(path),
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    );
    _throwIfNeeded(response);
    return response;
  }

  Future<http.Response> get(
    String path, {
    Map<String, dynamic>? query,
    bool authenticated = false,
  }) async {
    final headers = await _headers(authenticated: authenticated);
    final response = await _client.get(
      _buildUri(path, query),
      headers: headers,
    );
    _throwIfNeeded(response);
    return response;
  }

  Future<http.Response> delete(
    String path, {
    bool authenticated = false,
  }) async {
    final headers = await _headers(authenticated: authenticated);
    final response = await _client.delete(
      _buildUri(path),
      headers: headers,
    );
    _throwIfNeeded(response);
    return response;
  }

  Future<Map<String, String>> _headers({required bool authenticated}) async {
    final headers = _baseHeaders();
    if (authenticated) {
      final token = await _tokenProvider.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<void> storeToken(String token) => _tokenProvider.saveToken(token);

  Future<void> clearToken() => _tokenProvider.clearToken();

  Future<String?> readStoredToken() => _tokenProvider.getToken();

  void _throwIfNeeded(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    String message = 'Request failed with status ${response.statusCode}';
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final bodyMessage = decoded['message'] as String?;
      if (bodyMessage != null && bodyMessage.isNotEmpty) {
        message = bodyMessage;
      }
    } catch (_) {}
    throw ApiException(message, response.statusCode);
  }
}
