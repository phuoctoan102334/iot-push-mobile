// Cấu hình FCM: xin quyền, kênh HIGH, subscribe topic, xử lý 3 trạng thái.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'alert_info.dart';
import 'firebase_options.dart';
import 'history_store.dart';

const String kAlertTopic = 'alerts'; // topic app tự subscribe
const String kChannelId = 'iot_alerts'; // kênh HIGH -> hiện heads-up
const String kChannelName = 'Cảnh báo IoT';

/// Handler chạy ở isolate RIÊNG khi app ở nền hoặc vừa được mở từ thông báo.
/// Hệ thống Android tự hiện thông báo (notification payload); ta chỉ ghi lịch sử.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await HistoryStore.addStatic(AlertInfo.fromMessage(message));
  } catch (_) {}
}

class MessagingService {
  static final FlutterLocalNotificationsPlugin _lnp = FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Giá trị cho UI quan sát
  static final ValueNotifier<String?> fcmToken = ValueNotifier(null);
  static final ValueNotifier<String?> permissionStatus = ValueNotifier(null);
  static final ValueNotifier<bool> topicOk = ValueNotifier(false);
  static final String lastError = '';

  static int _notifId = 0;

  static Future<void> init({required HistoryStore store}) async {
    // 1) Kênh thông báo importance HIGH (Android hiện heads-up)
    const androidChannel = AndroidNotificationChannel(
      kChannelId,
      kChannelName,
      description: 'Cảnh báo từ hệ thống IoT (nhiệt độ, cháy, khí gas...)',
      importance: Importance.high,
      playSound: true,
    );
    await _lnp.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final androidImpl =
        _lnp.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(androidChannel);

    // 2) Xin quyền POST_NOTIFICATIONS (Android 13+) + quyền FCM
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    permissionStatus.value = settings.authorizationStatus.name;
    await androidImpl?.requestNotificationsPermission(); // fallback 13+

    // 3) Tự subscribe topic "alerts"
    try {
      await _messaging.subscribeToTopic(kAlertTopic);
      topicOk.value = true;
    } catch (_) {
      topicOk.value = false;
    }

    // 4) Lắng nghe token (đổi khi gỡ/cài lại)
    // getToken/onTokenRefresh vẫn hoạt động và là thứ Firebase Console cần
    // khi gửi test message thủ công (ignore deprecation có chủ đích).
    // ignore: deprecated_member_use
    fcmToken.value = await _safeToken();
    if (fcmToken.value == null) {
      // Fallback theo API mới (firebase_messaging 17+): FID qua register()
      try {
        await _messaging.register();
        _messaging.onRegistered.listen((t) => fcmToken.value = t);
      } catch (_) {}
    }
    // ignore: deprecated_member_use
    _messaging.onTokenRefresh.listen((t) => fcmToken.value = t);

    // 5) TRẠNG THÁI FOREGROUND: hiện thông báo THẬT bằng flutter_local_notifications
    FirebaseMessaging.onMessage.listen((m) async {
      final a = AlertInfo.fromMessage(m);
      await store.add(a); // UI tự notify
      await showLocal(a);
    });

    // 6) TRẠNG THÁI BACKGROUND: người dùng bấm vào thông báo -> mở app
    FirebaseMessaging.onMessageOpenedApp.listen((m) async {
      await store.add(AlertInfo.fromMessage(m));
    });

    // 7) TRẠNG THÁI TERMINATED: mở app từ thông báo
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      await store.add(AlertInfo.fromMessage(initial));
    }
  }

  static Future<String?> _safeToken() async {
    try {
      // ignore: deprecated_member_use
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Hiện thông báo local (foreground) với màu theo loại cảnh báo
  static Future<void> showLocal(AlertInfo a) async {
    final style = AlertStyle.of(a.type);
    await _lnp.show(
      id: _notifId++,
      title: a.title,
      body: a.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          kChannelId,
          kChannelName,
          importance: Importance.high,
          priority: Priority.high,
          color: style.color,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(a.body),
        ),
      ),
    );
  }
}
