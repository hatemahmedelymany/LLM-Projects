import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  String baseUrl; // e.g., https://XXXX.ngrok-free.app
  ApiService({required this.baseUrl});

  Future<Map<String, dynamic>> health() async {
    final uri = Uri.parse('$baseUrl/health');
    final res = await http.get(uri);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> ingestPdf(File file) async {
    final uri = Uri.parse('$baseUrl/ingest');
    final req = http.MultipartRequest('POST', uri);
    req.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamRes = await req.send();
    final body = await streamRes.stream.bytesToString();
    if (streamRes.statusCode != 200) {
      throw Exception('Ingest failed: ${streamRes.statusCode} $body');
    }
    return jsonDecode(body);
  }

  Future<String> ask(String question) async {
    final uri = Uri.parse('$baseUrl/ask');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'question': question}),
    );
    if (res.statusCode != 200) {
      throw Exception('Ask failed: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['answer'] ?? '').toString();
  }
}