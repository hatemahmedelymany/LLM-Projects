import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ApiService extends ChangeNotifier {
  // Replace with your ngrok URL from Kaggle
  static const String baseUrl = 'https://34ed97257a0b.ngrok-free.app';
  
  bool _isLoading = false;
  String _summary = '';
  String _error = '';

  bool get isLoading => _isLoading;
  String get summary => _summary;
  String get error => _error;

  Future<void> summarizeVideo(String videoUrl) async {
    _isLoading = true;
    _error = '';
    _summary = '';
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/summarize'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'url': videoUrl,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _summary = data['summary'];
      } else {
        final error = json.decode(response.body);
        _error = error['error'] ?? 'Failed to summarize video';
      }
    } catch (e) {
      _error = 'Network error: Please check your connection and ngrok URL';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearResults() {
    _summary = '';
    _error = '';
    notifyListeners();
  }
}
