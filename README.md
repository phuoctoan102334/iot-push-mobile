# iotalert — App di động nhận thông báo đẩy FCM (LAB 1)

App Flutter (Android) nhận thông báo đẩy từ Firebase Cloud Messaging trong hệ thống cảnh báo IoT,
kèm tab chỉnh **ngưỡng cảnh báo** (đồng bộ với server Node.js) và tab **lịch sử thông báo** riêng.

## Chức năng

| Chức năng | Mô tả |
|---|---|
| Nhận push FCM | Xử lý cả 3 trạng thái: app đang mở (foreground), ở nền (background), đã vuốt tắt (terminated) |
| Hiển thị thông báo | Kênh `iot_alerts` importance HIGH (heads-up), icon + màu theo 5 loại cảnh báo |
| Tab **Ngưỡng** | Xem FCM token, trạng thái subscribe topic `alerts`, quyền thông báo; chỉnh ngưỡng nhiệt độ cao/thấp và khí gas rồi lưu lên server |
| Tab **Lịch sử** | 50 thông báo gần nhất, lưu bền bằng SharedPreferences |

## Yêu cầu môi trường

- Flutter 3.41+ / Dart 3.11+
- Android SDK (điện thoại thật hoặc emulator, Android 8+; Android 13+ cần quyền thông báo)
- Một project Firebase có app Android, package `com.example.iotalert`

## Cài đặt

1. **Cấu hình Firebase cho app**

   Firebase Console → Project settings → *Your apps* → app Android → tải `google-services.json`
   → đặt vào `android/app/google-services.json` (file này **không** commit, đã nằm trong `.gitignore`).

2. **(Khuyến nghị) tạo `firebase_options.dart` thật**

   ```bash
   flutterfire configure
   ```

   Nếu bỏ qua bước này, app tự dùng cấu hình native sinh ra từ `google-services.json`.

3. **Địa chỉ server Node.js**

   Mở `lib/server_config.dart`, sửa hằng số:

   ```dart
   const String kServerBaseUrl = 'http://192.168.1.10:3000';
   ```

   Điện thoại và máy chạy server phải cùng một mạng WiFi. Server chạy HTTP nên
   `android:usesCleartextTraffic="true"` đã được bật trong `AndroidManifest.xml`.

4. **Cài dependency và chạy**

   ```bash
   flutter pub get
   flutter analyze
   flutter run -d <device_id>
   ```

5. **Build APK để cài độc lập**

   ```bash
   flutter build apk --release
   ```

   APK: `build/app/outputs/flutter-apk/app-release.apk`

## Cài qua WiFi (không cần cáp)

```bash
adb pair <ip>:<cổng ghép> <mã ghép>     # chỉ lần đầu, mã chỉ sống vài phút
adb connect <ip>:<cổng kết nối>          # cổng đổi mỗi lần bật/tắt Wireless debugging
adb -s <ip>:<cổng> install -r build/app/outputs/flutter-apk/app-release.apk
```

Mẹo: `adb mdns services` để xem cổng `_adb-tls-connect._tcp` hiện tại.

## Liên quan tới server

App gọi 2 API của server Node.js:

| API | Dùng cho |
|---|---|
| `GET /api/thresholds` | Đọc ngưỡng hiện tại khi mở tab **Ngưỡng** |
| `PUT /web-api/thresholds` | Lưu ngưỡng mới (dashboard web tự cập nhật sau ~5 giây) |

Server nhận cảnh báo và gửi push tới topic `alerts` — app tự subscribe topic này khi khởi động.
