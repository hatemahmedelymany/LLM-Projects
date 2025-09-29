// import 'dart:convert';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:http/http.dart' as http;

// class GptClient {
//   final String _url = (dotenv.env['NGROK_URL'] ?? '').trim();
//   final String bearer = (dotenv.env['AUTH_BEARER'] ?? '').trim();

//   Uri _buildUri() {
//     if (_url.isEmpty) throw Exception('NGROK_URL is not set in .env');
//     final normalized = _url.endsWith('/generate')
//         ? _url
//         : (_url.endsWith('/') ? '${_url}generate' : '$_url/generate');
//     return Uri.parse(normalized);
//   }

//   Future<String> generate({
//     required String prompt,
//     int maxLength = 120,
//     double temperature = 0.3,
//     double topP = 0.95,
//   }) async {
//     final uri = _buildUri();
//     final headers = {
//       'Content-Type': 'application/json',
//       if (bearer.isNotEmpty) 'Authorization': 'Bearer $bearer',
//     };
//     final body = jsonEncode({
//       'query': prompt,
//       'max_length': maxLength,
//       'temperature': temperature,
//       'top_p': topP,
//     });

//     if (kDebugMode) debugPrint('POST $uri');

//     final res = await http.post(uri, headers: headers, body: body);
//     if (res.statusCode >= 200 && res.statusCode < 300) {
//       final j = jsonDecode(res.body);
//       return (j['response'] ?? '').toString();
//     }
//     throw Exception('HTTP ${res.statusCode}: ${res.body}');
//   }
// }


// lib/services/gpt_client.dart
// lib/services/gpt_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/chat_message.dart';

/// Minimal client for your text-generation backend.
/// Endpoint: POST {API_URL}/generate
/// Headers: Authorization: Bearer <API_KEY>, Content-Type: application/json
/// Body:    { "query": "<user message only>" }
class GptClient {
  GptClient({
    String? baseUrl,
    String? apiKey,
    Duration? timeout,
  })  : _rawBase = (baseUrl ?? dotenv.env['NGROK_URL'] ?? '').trim(),
        _apiKey = (apiKey ?? dotenv.env['API_KEY'] ?? 'secret123').trim(),
        _timeout = timeout ?? const Duration(seconds: 60) {
    if (_rawBase.isEmpty) {
      throw Exception('NGROK_URL is not set in .env and no baseUrl was provided.');
    }
  }

  final String _rawBase;
  final String _apiKey;
  final Duration _timeout;

  /// Build normalized /generate URL
  Uri _buildUri() {
    final base = _rawBase;
    final normalized = base.endsWith('/generate')
        ? base
        : (base.endsWith('/') ? '${base}generate' : '$base/generate');
    return Uri.parse(normalized);
  }

  /// Send user message ONLY. History is ignored on purpose (guardrails live on backend).
  Future<String> generate({
    required String prompt,
    List<ChatMessage> history = const [], // kept for API compatibility
  }) async {
    final uri = _buildUri();

    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json',
      if (_apiKey.isNotEmpty) HttpHeaders.authorizationHeader: 'Bearer $_apiKey',
    };

    // IMPORTANT: send the raw user text only
    final body = jsonEncode({'query': prompt});

    if (kDebugMode) debugPrint('POST $uri  body=${body.substring(0, body.length.clamp(0, 300))}');

    http.Response res;
    try {
      res = await http.post(uri, headers: headers, body: body).timeout(_timeout);
    } on TimeoutException catch (e) {
      throw Exception('Timeout: $e');
    } on SocketException catch (e) {
      throw Exception('No se pudo conectar al servidor ($uri): $e');
    } on HttpException catch (e) {
      throw Exception('HTTP error al conectar ($uri): $e');
    } on FormatException catch (e) {
      throw Exception('Respuesta con formato no válido: $e');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final snippet = res.body.length > 500 ? '${res.body.substring(0, 500)}…' : res.body;
      throw Exception('Servidor devolvió ${res.statusCode}. Respuesta: $snippet');
    }

    final text = _extractText(res)?.trim();
    if (text == null || text.isEmpty) {
      throw Exception('Respuesta vacía del generador. Body: ${res.body}');
    }
    return text;
  }

  /// Extract text from JSON {response|text|...} or fall back to raw body.
  String? _extractText(http.Response res) {
    final ctype = res.headers['content-type'] ?? '';
    if (ctype.contains('application/json')) {
      try {
        final data = jsonDecode(res.body);

        if (data is Map<String, dynamic>) {
          // Common keys
          for (final key in const ['response', 'text', 'reply', 'message', 'answer', 'output']) {
            final v = data[key];
            if (v is String && v.trim().isNotEmpty) return v;
          }
          // Nested { data: { ... } }
          final d = data['data'];
          if (d is Map<String, dynamic>) {
            for (final key in const ['response', 'text', 'reply', 'message', 'answer', 'output']) {
              final v = d[key];
              if (v is String && v.trim().isNotEmpty) return v;
            }
          }
        }

        if (data is String && data.trim().isNotEmpty) return data;
      } catch (_) {
        // fall through to raw body
      }
    }
    return res.body; // non-JSON servers → raw text
  }
}


