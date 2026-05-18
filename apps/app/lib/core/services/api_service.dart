import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../api_config.dart';
import '../../auth_service.dart';
import '../app_navigator.dart';

class ApiService {
  static const _timeout = Duration(seconds: 30);

  static Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl$endpoint'), headers: headers)
          .timeout(_timeout);
      return _handle(response);
    } catch (e) {
      debugPrint('ApiService GET $endpoint: $e');
      return {'success': false, 'error': 'Falha na conexão.', 'data': null};
    }
  }

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool requiresAuth = true,
  }) async {
    try {
      final headers = requiresAuth
          ? await AuthService.authHeaders()
          : {'Content-Type': 'application/json'};
      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return _handle(response);
    } catch (e) {
      debugPrint('ApiService POST $endpoint: $e');
      return {'success': false, 'error': 'Falha na conexão.', 'data': null};
    }
  }

  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await http
          .put(
            Uri.parse('$baseUrl$endpoint'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return _handle(response);
    } catch (e) {
      debugPrint('ApiService PUT $endpoint: $e');
      return {'success': false, 'error': 'Falha na conexão.', 'data': null};
    }
  }

  static Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await http
          .patch(
            Uri.parse('$baseUrl$endpoint'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return _handle(response);
    } catch (e) {
      debugPrint('ApiService PATCH $endpoint: $e');
      return {'success': false, 'error': 'Falha na conexão.', 'data': null};
    }
  }

  static Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await http
          .delete(Uri.parse('$baseUrl$endpoint'), headers: headers)
          .timeout(_timeout);
      return _handle(response);
    } catch (e) {
      debugPrint('ApiService DELETE $endpoint: $e');
      return {'success': false, 'error': 'Falha na conexão.', 'data': null};
    }
  }

  static Future<Map<String, dynamic>> uploadFile(
    String endpoint,
    String filePath, {
    String fieldName = 'avatar',
  }) async {
    try {
      final token = await AuthService.getToken();
      final request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'));
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      final ext = filePath.split('.').last.toLowerCase();
      final mimeType = switch (ext) {
        'png'  => MediaType('image', 'png'),
        'webp' => MediaType('image', 'webp'),
        _      => MediaType('image', 'jpeg'), // jpg, jpeg, tmp, no extension → jpeg
      };
      request.files.add(
        await http.MultipartFile.fromPath(fieldName, filePath, contentType: mimeType),
      );
      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      return _handle(response);
    } catch (e) {
      debugPrint('ApiService UPLOAD $endpoint: $e');
      return {'success': false, 'error': 'Falha no upload.', 'data': null};
    }
  }

  static Map<String, dynamic> _handle(http.Response response) {
    if (response.statusCode == 401) {
      AuthService.logout().then((_) {
        navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/login', (_) => false);
      });
      return {
        'success': false,
        'error': 'Sessão expirada. Faça login novamente.',
        'data': null,
        'statusCode': 401,
      };
    }

    final success = response.statusCode >= 200 && response.statusCode < 300;

    dynamic data;
    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        data = response.body;
      }
    }

    String? error;
    if (!success) {
      error = (data is Map) ? data['error']?.toString() : null;
      error ??= 'Erro ${response.statusCode}';
    }

    return {
      'success': success,
      'data': data,
      'error': error,
      'statusCode': response.statusCode,
    };
  }
}
