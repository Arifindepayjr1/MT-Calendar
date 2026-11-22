import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:trader_log/model/auth.model.dart';

class AuthApiException implements Exception {
  final String message;
  const AuthApiException(this.message);

  @override
  String toString() => message;
}

/// Client for the backend-owned JWT auth endpoints.
class AuthApiService {
  final http.Client? client;
  final String? baseUrl;

  const AuthApiService({this.client, this.baseUrl});

  Future<AuthSession> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final json = await _post('auth/signup', {
      'email': email,
      'password': password,
      'name': name,
    });
    return AuthSession.fromJson(json);
  }

  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final json = await _post('auth/login', {
      'email': email,
      'password': password,
    });
    return AuthSession.fromJson(json);
  }

  /// Starts passwordless onboarding. The backend stores a hashed 6-digit code
  /// and returns it as `devCode` when email/SMS delivery is not configured.
  Future<AuthCodeRequest> requestCode({
    required String email,
    required String password,
    required String name,
    String? framework,
  }) async {
    final json = await _post('auth/request-code', {
      'email': email,
      'password': password,
      'name': name,
      if (framework != null && framework.isNotEmpty) 'framework': framework,
    });
    return AuthCodeRequest.fromJson(json);
  }

  /// Exchanges the 6-digit code for a JWT session and creates the account.
  Future<AuthSession> verifyCode({
    required String email,
    required String code,
  }) async {
    final json = await _post('auth/verify-code', {
      'email': email,
      'code': code,
    });
    return AuthSession.fromJson(json);
  }

  Future<AuthUser> me(String token) async {
    final json = await _get('auth/me', token);
    return AuthUser.fromJson(json);
  }

  List<Uri> _candidates(String path) {
    if (baseUrl != null) {
      return [Uri.parse('${baseUrl!.replaceAll(RegExp(r'/+$'), '')}/api/$path')];
    }
    return [
      if (kIsWeb) Uri.base.resolve('/api/$path'),
      Uri.parse('http://127.0.0.1:3000/api/$path'),
    ];
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final ownsClient = client == null;
    final httpClient = client ?? http.Client();
    Object? lastError;
    try {
      for (final uri in _candidates(path)) {
        try {
          final response = await httpClient.post(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          );
          final decoded = _decode(response);
          if (decoded != null) return decoded;
          lastError = AuthApiException(
            'Unexpected response from $uri (${response.statusCode}).',
          );
        } on AuthApiException {
          rethrow;
        } catch (error) {
          lastError = error;
        }
      }
    } finally {
      if (ownsClient) httpClient.close();
    }
    throw AuthApiException(
      'Auth API is unavailable. Start the backend on port 3000. $lastError',
    );
  }

  Future<Map<String, dynamic>> _get(String path, String token) async {
    final ownsClient = client == null;
    final httpClient = client ?? http.Client();
    Object? lastError;
    try {
      for (final uri in _candidates(path)) {
        try {
          final response = await httpClient.get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );
          final decoded = _decode(response);
          if (decoded != null) return decoded;
          lastError = AuthApiException(
            'Unexpected response from $uri (${response.statusCode}).',
          );
        } on AuthApiException {
          rethrow;
        } catch (error) {
          lastError = error;
        }
      }
    } finally {
      if (ownsClient) httpClient.close();
    }
    throw AuthApiException(
      'Auth API is unavailable. Start the backend on port 3000. $lastError',
    );
  }

  /// Returns a JSON map for 2xx, throws a server-aware error for JSON 4xx/5xx,
  /// and returns null for non-JSON responses so the next candidate can be tried.
  Map<String, dynamic>? _decode(http.Response response) {
    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.contains('application/json')) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded['error'] as String? ??
          decoded['message'] as String? ??
          'Request failed (${response.statusCode}).';
      throw AuthApiException(message);
    }
    return decoded;
  }
}
