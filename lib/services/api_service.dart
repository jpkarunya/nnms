// lib/services/api_service.dart
// Fully embedded — no server needed, works 100% offline

import 'dart:math';

final _rng = Random();

double _randDouble(double min, double max) =>
    min + _rng.nextDouble() * (max - min);

int _randInt(int min, int max) => min + _rng.nextInt(max - min);

String _randIp() =>
    '192.168.${_randInt(1, 5)}.${_randInt(1, 254)}';

String _randLabel() {
  final v = _rng.nextDouble();
  if (v > 0.85) return 'Malicious';
  if (v > 0.65) return 'Suspicious';
  return 'Normal';
}

String _severity(double score) {
  if (score > 80) return 'CRITICAL';
  if (score > 60) return 'HIGH';
  if (score > 40) return 'MEDIUM';
  return 'LOW';
}

class ApiService {
  String baseUrl;
  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? 'embedded';

  Future<bool> checkHealth() async => true;

  Future<Map<String, dynamic>> getDashboardData({int hours = 24}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final score = _randDouble(15, 65);
    final normal = _randInt(300, 1000);
    final suspicious = _randInt(20, 80);
    final malicious = _randInt(5, 30);
    return {
      'current_threat_score': double.parse(score.toStringAsFixed(1)),
      'severity': score > 40 ? 'MEDIUM' : 'LOW',
      'total_packets_analyzed': normal + suspicious + malicious,
      'anomaly_count': _randInt(2, 15),
      'label_distribution': {
        'Normal': normal,
        'Suspicious': suspicious,
        'Malicious': malicious,
      },
      'trend_summary': {
        'trend': 'STABLE',
        'slope_per_hour': double.parse(_randDouble(-2, 2).toStringAsFixed(2)),
      },
      'hourly_trend': List.generate(24, (i) => {
        'hour': i,
        'avg_score': double.parse(_randDouble(5, 60).toStringAsFixed(1)),
      }),
      'predictions': List.generate(8, (i) => {
        'hour': i,
        'score': double.parse(_randDouble(10, 70).toStringAsFixed(1)),
      }),
      'top_threat_sources': [
        {'ip': '192.168.1.105', 'count': 230},
        {'ip': '10.0.0.44', 'count': 180},
        {'ip': '172.16.0.12', 'count': 95},
        {'ip': '192.168.1.200', 'count': 60},
        {'ip': '10.0.0.1', 'count': 34},
      ],
      'timestamp': DateTime.now().millisecondsSinceEpoch / 1000,
    };
  }

  Future<Map<String, dynamic>> startScan({String? interface}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return {'status': 'started', 'interface': interface ?? 'eth0', 'ok': true};
  }

  Future<Map<String, dynamic>> stopScan() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return {'status': 'stopped'};
  }

  Future<Map<String, dynamic>> getScanStatus({int maxPackets = 20}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final count = _randInt(5, maxPackets);
    final packets = List.generate(count, (_) {
      final score = _randDouble(0, 100);
      final label = _randLabel();
      return {
        'src_ip': _randIp(),
        'dst_ip': '10.0.0.${_randInt(1, 50)}',
        'src_port': _randInt(1024, 65535),
        'dst_port': [80, 443, 22, 3389, 8080][_randInt(0, 5)],
        'protocol': _rng.nextBool() ? 'TCP' : 'UDP',
        'packet_length': _randInt(64, 1500),
        'threat_label': label,
        'threat_score': double.parse(score.toStringAsFixed(1)),
        'severity': _severity(score),
        'is_anomaly': score > 65,
        'timestamp': DateTime.now().millisecondsSinceEpoch / 1000,
      };
    });
    final threats =
        packets.where((p) => p['threat_label'] != 'Normal').length;
    return {
      'running': true,
      'stats': {'total_packets': count, 'threats_detected': threats},
      'packets': packets,
      'timestamp': DateTime.now().millisecondsSinceEpoch / 1000,
    };
  }

  Future<Map<String, dynamic>> detectThreats(
      List<Map<String, dynamic>> packets) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final results = packets.map((p) {
      final score = _randDouble(0, 100);
      final label = score > 70
          ? 'Malicious'
          : score > 40
              ? 'Suspicious'
              : 'Normal';
      return {
        'threat_label': label,
        'threat_score': double.parse(score.toStringAsFixed(1)),
        'severity': _severity(score),
        'is_anomaly': score > 65,
      };
    }).toList();
    final scores = results
        .map((r) => (r['threat_score'] as double))
        .toList();
    final avg = scores.isEmpty
        ? 0.0
        : scores.reduce((a, b) => a + b) / scores.length;
    return {
      'results': results,
      'aggregate_threat_score': double.parse(avg.toStringAsFixed(1)),
      'total': results.length,
      'threats':
          results.where((r) => r['threat_label'] != 'Normal').length,
    };
  }

  Future<Map<String, dynamic>> getLogs({
    int limit = 50,
    int offset = 0,
    String? severity,
    double? minScore,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final ips = [
      '192.168.1.105', '10.0.0.44', '172.16.0.12',
      '192.168.1.200', '10.0.0.1'
    ];
    var logs = List.generate(30, (i) {
      final score = _randDouble(10, 95);
      final label = score > 70
          ? 'Malicious'
          : score > 40
              ? 'Suspicious'
              : 'Normal';
      return {
        'id': i + 1,
        'timestamp': DateTime.now()
                .subtract(Duration(minutes: (30 - i) * 5))
                .millisecondsSinceEpoch /
            1000,
        'src_ip': ips[_randInt(0, ips.length)],
        'dst_ip': '10.0.0.${_randInt(1, 50)}',
        'threat_label': label,
        'threat_score': double.parse(score.toStringAsFixed(1)),
        'severity': _severity(score),
        'protocol': _rng.nextBool() ? 'TCP' : 'UDP',
        'dst_port': [80, 443, 22, 3389, 8080][_randInt(0, 5)],
        'is_anomaly': score > 65,
      };
    });
    if (severity != null && severity != 'ALL') {
      logs = logs.where((l) => l['severity'] == severity).toList();
    }
    if (minScore != null) {
      logs = logs
          .where((l) => (l['threat_score'] as double) >= minScore)
          .toList();
    }
    return {
      'logs': logs.skip(offset).take(limit).toList(),
      'total': logs.length,
      'limit': limit,
      'offset': offset,
    };
  }

  Future<Map<String, dynamic>> getPrediction() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return {
      'predictions': List.generate(24, (i) => {
        'hour': i,
        'score': double.parse(_randDouble(10, 70).toStringAsFixed(1)),
      }),
      'trend': 'STABLE',
      'confidence': 0.85,
    };
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}
