// Địa chỉ server, lưu trong SharedPreferences để đổi được ngay trên app
// (không phải sửa code rồi build lại).
import 'package:shared_preferences/shared_preferences.dart';

/// Giá trị gợi ý lần đầu — máy tính đang chạy server trong lab.
const String kDefaultServerUrl = 'http://192.168.51.243:3000';

const String _prefsKey = 'server_base_url';

class ServerConfig {
  static String _baseUrl = kDefaultServerUrl;

  /// Địa chỉ server đang dùng, ví dụ http://192.168.1.10:3000
  static String get baseUrl => _baseUrl;

  /// Đọc lại địa chỉ đã lưu (gọi 1 lần trong main()).
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && saved.trim().isNotEmpty) {
        _baseUrl = normalize(saved);
      }
    } catch (_) {
      // Không đọc được -> giữ giá trị mặc định
    }
  }

  static Future<void> save(String url) async {
    _baseUrl = normalize(url);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _baseUrl);
    } catch (_) {
      // Vẫn dùng địa chỉ mới trong phiên này
    }
  }

  /// Thêm http:// nếu thiếu, bỏ dấu "/" ở cuối.
  static String normalize(String url) {
    var v = url.trim();
    if (v.isEmpty) return kDefaultServerUrl;
    if (!v.startsWith('http://') && !v.startsWith('https://')) v = 'http://$v';
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }
}
