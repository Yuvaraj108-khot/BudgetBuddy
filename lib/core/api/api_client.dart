import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/secure_storage.dart';

class ApiClient {
  // Use localhost (needs adb reverse tcp:3000 tcp:3000 for physical devices)
  static const String baseUrl = 'http://localhost:3005/api';

  static Future<Map<String, String>> _headers() async {
    final token = await SecureStorage.getToken();
    final isPinVerified = await SecureStorage.isPinVerified();
    
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (isPinVerified) {
      headers['x-pin-verified'] = 'true';
    }

    return headers;
  }

  static Future<http.Response> get(String path) async {
    final url = Uri.parse('$baseUrl$path');
    final headers = await _headers();
    return await http.get(url, headers: headers);
  }

  static Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$path');
    final headers = await _headers();
    return await http.post(url, headers: headers, body: jsonEncode(body));
  }

  static Future<http.Response> delete(String path) async {
    final url = Uri.parse('$baseUrl$path');
    final headers = await _headers();
    return await http.delete(url, headers: headers);
  }

  // Helper to parse responses and handle 401/403 globally
  static Map<String, dynamic> processResponse(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      final message = body['message'] ?? 'An error occurred';
      throw ApiException(message, response.statusCode, body['code']);
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final String? code;

  ApiException(this.message, this.statusCode, this.code);

  @override
  String toString() => message;
}
