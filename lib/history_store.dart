// Lịch sử thông báo nhận được, lưu bền vững bằng SharedPreferences.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alert_info.dart';

class HistoryStore extends ChangeNotifier {
  static const String _key = 'alert_history';
  static const int _max = 50;

  final List<AlertInfo> items = [];

  /// Nạp lịch sử từ disk (gọi 1 lần lúc mở app)
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        items
          ..clear()
          ..addAll(list.map(AlertInfo.fromJson));
        notifyListeners();
      }
    } catch (_) {
      // Lịch sử hỏng -> bỏ qua, bắt đầu rỗng
    }
  }

  /// Thêm mới (id trùng -> bỏ qua để tránh ghi đôi khi mở từ thông báo)
  Future<void> add(AlertInfo a) async {
    if (items.any((e) => e.id == a.id)) return;
    items.insert(0, a);
    while (items.length > _max) {
      items.removeLast();
    }
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
    } catch (_) {
      // Lưu thất bại không chặn UI
    }
  }

  /// Dùng trong background isolate (handler khi app ở nền): không qua instance
  static Future<void> addStatic(AlertInfo a) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      final list = raw == null || raw.isEmpty
          ? <Map<String, dynamic>>[]
          : (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      if (list.any((e) => e['id'] == a.id)) return;
      list.insert(0, a.toJson());
      while (list.length > _max) {
        list.removeLast();
      }
      await prefs.setString(_key, jsonEncode(list));
    } catch (_) {
      // Best-effort trong isolate nền
    }
  }
}
