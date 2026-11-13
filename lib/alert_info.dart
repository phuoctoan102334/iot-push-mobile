// Ánh xạ loại cảnh báo -> icon + màu (yêu cầu 7) và parse FCM message.
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

/// Một thông báo đã nhận (hiển thị trong lịch sử)
class AlertInfo {
  final String id; // dedupe khi nhận qua nhiều đường (foreground/background/tap)
  final String type;
  final String title;
  final String body;
  final String deviceId;
  final String value;
  final DateTime time;

  const AlertInfo({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.deviceId = '',
    this.value = '',
    required this.time,
  });

  /// Lấy từ RemoteMessage (notification hoặc data do server gửi)
  factory AlertInfo.fromMessage(RemoteMessage m) {
    final data = m.data;
    return AlertInfo(
      id: m.messageId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      type: data['type']?.toString() ?? 'unknown',
      title: m.notification?.title ?? data['title']?.toString() ?? 'Cảnh báo IoT',
      body: m.notification?.body ?? data['body']?.toString() ?? '',
      deviceId: data['deviceId']?.toString() ?? '',
      value: data['value']?.toString() ?? '',
      time: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'body': body,
        'deviceId': deviceId,
        'value': value,
        'time': time.millisecondsSinceEpoch,
      };

  factory AlertInfo.fromJson(Map<String, dynamic> j) => AlertInfo(
        id: j['id']?.toString() ?? '',
        type: j['type']?.toString() ?? 'unknown',
        title: j['title']?.toString() ?? '',
        body: j['body']?.toString() ?? '',
        deviceId: j['deviceId']?.toString() ?? '',
        value: j['value']?.toString() ?? '',
        time: DateTime.fromMillisecondsSinceEpoch((j['time'] as num?)?.toInt() ?? 0),
      );
}

/// Icon/màu/nhãn theo 5 loại cảnh báo bắt buộc
class AlertStyle {
  static const Map<String, ({IconData icon, Color color, String label})> map = {
    'temp_high': (icon: Icons.thermostat, color: Color(0xFFE53935), label: 'Nhiệt độ cao'),
    'temp_low': (icon: Icons.ac_unit, color: Color(0xFF1E88E5), label: 'Nhiệt độ thấp'),
    'intruder': (icon: Icons.person_off_outlined, color: Color(0xFF8E24AA), label: 'Xâm nhập'),
    'fire': (icon: Icons.local_fire_department, color: Color(0xFFF4511E), label: 'Cháy'),
    'gas': (icon: Icons.air, color: Color(0xFFFF8F00), label: 'Khí gas'),
  };

  static ({IconData icon, Color color, String label}) of(String type) =>
      map[type] ?? (icon: Icons.notifications, color: Color(0xFF757575), label: 'Khác');
}
