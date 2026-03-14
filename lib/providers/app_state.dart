// lib/providers/app_state.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AppState extends ChangeNotifier {
  // Auth
  bool _authenticated = false;
  String? _jwtToken;
  String? _username;
  String? _role;

  bool get isAuthenticated => _authenticated;
  String? get jwtToken => _jwtToken;
  String? get username => _username;
  String? get role => _role;

  // Navigation
  int _tabIndex = 0;
  int get tabIndex => _tabIndex;

  // Settings
  String _serverUrl = getDefaultBaseUrl();
  double _alertThreshold = 70.0;
  bool _alertsEnabled = true;
  String get serverUrl => _serverUrl;
  double get alertThreshold => _alertThreshold;
  bool get alertsEnabled => _alertsEnabled;

  // Scan state
  bool _scanRunning = false;
  bool get scanRunning => _scanRunning;

  // Dashboard data cache
  Map<String, dynamic> _dashData = {};
  Map<String, dynamic> get dashData => _dashData;

  // Active alerts
  final List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> get alerts => List.unmodifiable(_alerts);

  AppState() { _loadPrefs(); }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString('serverUrl') ?? getDefaultBaseUrl();
    _alertThreshold = prefs.getDouble('alertThreshold') ?? 70.0;
    _alertsEnabled = prefs.getBool('alertsEnabled') ?? true;

    // Auto-login if valid token exists
    final savedToken = prefs.getString('jwt_token');
    final savedUsername = prefs.getString('jwt_username');
    final savedRole = prefs.getString('jwt_role');
    if (savedToken != null && savedUsername != null) {
      _jwtToken = savedToken;
      _username = savedUsername;
      _role = savedRole;
      _authenticated = true;
    }
    notifyListeners();
  }

  Future<void> saveSettings({
    required String url,
    required double threshold,
    required bool alertsOn,
  }) async {
    _serverUrl = url;
    _alertThreshold = threshold;
    _alertsEnabled = alertsOn;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('serverUrl', url);
    await prefs.setDouble('alertThreshold', threshold);
    await prefs.setBool('alertsEnabled', alertsOn);
    notifyListeners();
  }

  // Simple login (demo mode - no JWT)
  void login() {
    _authenticated = true;
    _username = 'admin';
    _role = 'admin';
    notifyListeners();
  }

  // JWT login - called after successful API authentication
  Future<void> loginWithJwt({
    required String token,
    required String username,
    required String role,
  }) async {
    _jwtToken = token;
    _username = username;
    _role = role;
    _authenticated = true;

    // Save to persistent storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setString('jwt_username', username);
    await prefs.setString('jwt_role', role);

    notifyListeners();
  }

  // Logout - clears JWT token
  Future<void> logout() async {
    _authenticated = false;
    _jwtToken = null;
    _username = null;
    _role = null;
    _tabIndex = 0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('jwt_username');
    await prefs.remove('jwt_role');

    notifyListeners();
  }

  void setTab(int i) { _tabIndex = i; notifyListeners(); }
  void setScanRunning(bool v) { _scanRunning = v; notifyListeners(); }

  void updateDashData(Map<String, dynamic> d) {
    _dashData = d;
    final score = (d['current_threat_score'] as num?)?.toDouble() ?? 0.0;
    if (_alertsEnabled && score >= _alertThreshold) {
      _addAlert(score, d['severity'] ?? 'HIGH');
    }
    notifyListeners();
  }

  void _addAlert(double score, String severity) {
    final now = DateTime.now();
    if (_alerts.isNotEmpty) {
      final last = _alerts.last['ts'] as DateTime;
      if (now.difference(last).inSeconds < 30) return;
    }
    _alerts.add({'score': score, 'severity': severity, 'ts': now});
    if (_alerts.length > 5) _alerts.removeAt(0);
    notifyListeners();
  }

  void dismissAlert(int i) {
    if (i < _alerts.length) { _alerts.removeAt(i); notifyListeners(); }
  }

  void clearAlerts() { _alerts.clear(); notifyListeners(); }
}
