import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/risk_result.dart';

class RiskApiClient {
  final String baseUrl;

  RiskApiClient({this.baseUrl = 'http://127.0.0.1:8000'});

  Future<RiskResult> predict(Map<String, dynamic> fields) async {
    final uri = Uri.parse('$baseUrl/predict');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(fields),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw RiskApiException(
        'Server returned ${response.statusCode}: ${response.body}',
      );
    }
    return RiskResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class RiskApiException implements Exception {
  final String message;
  RiskApiException(this.message);
  @override
  String toString() => message;
}
