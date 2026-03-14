// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<void> showThreatAlert({
    required String title,
    required String body,
    required double score,
  }) async {
    await init();

    final androidDetails = AndroidNotificationDetails(
      'netguard_threats',
      'NetGuard Threat Alerts',
      channelDescription: 'Alerts when threat score exceeds threshold',
      importance: Importance.high,
      priority: Priority.high,
      color: score > 80
          ? const Color(0xFFFF4444)
          : score > 60
              ? const Color(0xFFFF8800)
              : const Color(0xFFFFD700),
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  Future<void> showScanComplete({
    required int totalPackets,
    required int threats,
  }) async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      'netguard_scan',
      'NetGuard Scan Results',
      channelDescription: 'Scan completion notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    await _plugin.show(
      1,
      'Scan Complete',
      'Analyzed $totalPackets packets — $threats threats detected',
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> showMaliciousDetected({
    required String srcIp,
    required double score,
  }) async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      'netguard_malicious',
      'NetGuard Malicious Detection',
      channelDescription: 'Malicious packet detection alerts',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
    );

    await _plugin.show(
      2,
      '⚠️ MALICIOUS PACKET DETECTED',
      'Source: $srcIp | Threat Score: ${score.toStringAsFixed(1)}/100',
      const NotificationDetails(android: androidDetails),
    );
  }
}

// Color import needed
class Color {
  final int value;
  const Color(this.value);
}
