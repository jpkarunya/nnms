// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

String getDefaultBaseUrl() {
  if (!kIsWeb && Platform.isAndroid) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://localhost:8000';
}

class ApiService {
  String baseUrl;
  final _client = http.Client();
  static const _timeout = Duration(seconds: 30);

  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? getDefaultBaseUrl();

  Map<String, String> get _h => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'ngrok-skip-browser-warning': 'true',
    'User-Agent': 'NetGuardApp/1.0',
  };

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, String>? q}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: q);
    try {
      final r = await _client.get(uri, headers: _h).timeout(_timeout);
      return _parse(r);
    } on SocketException {
      throw ApiException(0, 'Cannot connect to server at $baseUrl');
    } on HttpException {
      throw ApiException(0, 'HTTP error');
    }
  }

  Future<Map<String, dynamic>> _post(String path, Object body) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final r = await _client
          .post(uri, headers: _h, body: jsonEncode(body))
          .timeout(_timeout);
      return _parse(r);
    } on SocketException {
      throw ApiException(0, 'Cannot connect to server at $baseUrl');
    }
  }

  Map<String, dynamic> _parse(http.Response r) {
    if (r.headers['content-type']?.contains('application/pdf') == true) {
      return {'pdf_bytes': r.bodyBytes, 'is_pdf': true};
    }
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode >= 400) {
      throw ApiException(r.statusCode,
          body['detail']?.toString() ?? 'Server error ${r.statusCode}');
    }
    return body;
  }

  Future<bool> checkHealth() async {
    try {
      final r = await _get('/health');
      return r['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> startScan({String? interface}) =>
      _post('/scan/start', {'interface': interface});

  Future<Map<String, dynamic>> stopScan() =>
      _post('/scan/stop', {});

  Future<Map<String, dynamic>> getScanStatus({int maxPackets = 20}) =>
      _get('/scan/status', q: {'max_packets': maxPackets.toString()});

  Future<Map<String, dynamic>> detectThreats(
          List<Map<String, dynamic>> packets) =>
      _post('/detect', {'packets': packets});

  Future<Map<String, dynamic>> getPrediction() => _get('/predict');

  Future<Map<String, dynamic>> getLogs({
    int limit = 50,
    int offset = 0,
    String? severity,
    double? minScore,
  }) =>
      _get('/logs', q: {
        'limit': limit.toString(),
        'offset': offset.toString(),
        if (severity != null) 'severity': severity,
        if (minScore != null) 'min_score': minScore.toString(),
      });

  Future<Map<String, dynamic>> getDashboardData({int hours = 24}) =>
      _get('/dashboard-data', q: {'hours': hours.toString()});

  // ── SHAP Explain ───────────────────────────────────────
  Future<Map<String, dynamic>> explainThreat({
    required Map<String, dynamic> packet,
    required String threatLabel,
    required double threatScore,
  }) =>
      _post('/explain', {
        'packet': packet,
        'threat_label': threatLabel,
        'threat_score': threatScore,
      });

  Future<Map<String, dynamic>> getExplainSummary() =>
      _get('/explain/summary');

  // ── PCAP Upload ────────────────────────────────────────
  Future<Map<String, dynamic>> uploadPcap(String filePath) async {
    final uri = Uri.parse('$baseUrl/pcap/upload');
    try {
      final request = http.MultipartRequest('POST', uri)
        ..headers['ngrok-skip-browser-warning'] = 'true'
        ..headers['User-Agent'] = 'NetGuardApp/1.0'
        ..files.add(await http.MultipartFile.fromPath('file', filePath));
      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on SocketException {
      throw ApiException(0, 'Cannot connect to server at $baseUrl');
    }
  }

  // ── Report Generate ────────────────────────────────────
  Future<Map<String, dynamic>> generateReport() async {
    final uri = Uri.parse('$baseUrl/report/generate');
    try {
      final r = await _client.get(uri, headers: _h).timeout(_timeout);
      if (r.headers['content-type']?.contains('application/pdf') == true) {
        return {'pdf_bytes': r.bodyBytes, 'is_pdf': true};
      }
      return jsonDecode(r.body) as Map<String, dynamic>;
    } on SocketException {
      throw ApiException(0, 'Cannot connect to server at $baseUrl');
    }
  }

  // ── JWT Auth ───────────────────────────────────────────
  Future<Map<String, dynamic>> loginWithCredentials({
    required String username,
    required String password,
  }) =>
      _post('/auth/login', {
        'username': username,
        'password': password,
      });

  Future<Map<String, dynamic>> verifyToken(String token) =>
      _post('/auth/verify', {'token': token});

  Future<Map<String, dynamic>> logoutFromServer() =>
      _post('/auth/logout', {});
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}
