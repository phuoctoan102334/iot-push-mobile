// Gọi API ngưỡng cảnh báo trên server Node.js (dùng dart:io, không thêm thư viện).
import 'dart:convert';
import 'dart:io';

import 'server_config.dart';

/// Bộ ngưỡng cảnh báo đang lưu trên server.
class Thresholds {
  final double tempHigh;
  final double tempLow;
  final int gasThreshold;
  final String updatedAt;

  const Thresholds({
    required this.tempHigh,
    required this.tempLow,
    required this.gasThreshold,
    this.updatedAt = '',
  });

  factory Thresholds.fromJson(Map<String, dynamic> json, String updatedAt) => Thresholds(
        tempHigh: (json['tempHigh'] as num?)?.toDouble() ?? 0,
        tempLow: (json['tempLow'] as num?)?.toDouble() ?? 0,
        gasThreshold: (json['gasThreshold'] as num?)?.toInt() ?? 0,
        updatedAt: updatedAt,
      );
}

class ThresholdsApi {
  /// Gọi server, trả về Map JSON; ném Exception kèm thông báo lỗi của server.
  static Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final url = Uri.parse('${ServerConfig.baseUrl}$path');
      final req = method == 'GET' ? await client.getUrl(url) : await client.putUrl(url);
      req.headers.contentType = ContentType.json;
      if (body != null) req.write(jsonEncode(body));
      final res = await req.close().timeout(const Duration(seconds: 12));
      final text = await res.transform(utf8.decoder).join();
      final data = text.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(text) as Map<String, dynamic>;
      if (res.statusCode >= 400 || data['ok'] == false) {
        throw Exception(data['error']?.toString() ?? 'HTTP ${res.statusCode}');
      }
      return data;
    } finally {
      client.close(force: true);
    }
  }

  static Thresholds _parse(Map<String, dynamic> data) => Thresholds.fromJson(
        (data['thresholds'] as Map).cast<String, dynamic>(),
        data['updatedAt']?.toString() ?? '',
      );

  /// Đọc ngưỡng hiện tại từ server
  static Future<Thresholds> fetch() async => _parse(await _request('GET', '/api/thresholds'));

  /// Ghi ngưỡng mới lên server (dashboard web sẽ tự cập nhật theo)
  static Future<Thresholds> save({
    required double tempHigh,
    required double tempLow,
    required int gasThreshold,
  }) async =>
      _parse(await _request('PUT', '/web-api/thresholds', {
        'tempHigh': tempHigh,
        'tempLow': tempLow,
        'gasThreshold': gasThreshold,
      }));
}
