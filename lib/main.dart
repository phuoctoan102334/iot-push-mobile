// IoT Push Lab — app nhận thông báo đẩy FCM từ hệ thống IoT.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'alert_info.dart';
import 'firebase_options.dart';
import 'history_store.dart';
import 'messaging.dart';
import 'server_config.dart';
import 'thresholds_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServerConfig.load(); // địa chỉ server đã lưu (nếu có)
  await _initFirebase();
  // Bắt buộc đăng ký TRƯỚC runApp cho thông báo khi app ở nền
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const IoTAlertApp());
}

/// Nếu chưa chạy `flutterfire configure`, `firebase_options.dart` vẫn là
/// placeholder -> dùng cấu hình native đọc từ `android/app/google-services.json`
/// (plugin google-services đã sinh ra tài nguyên Firebase mặc định).
Future<void> _initFirebase() async {
  final options = DefaultFirebaseOptions.currentPlatform;
  final isPlaceholder = options.apiKey.startsWith('PLACEHOLDER') ||
      options.projectId == 'placeholder-project';
  if (isPlaceholder) {
    await Firebase.initializeApp();
  } else {
    await Firebase.initializeApp(options: options);
  }
}

class IoTAlertApp extends StatelessWidget {
  const IoTAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IoT Push Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

String _fmtTime(DateTime t) {
  String p(int v) => v.toString().padLeft(2, '0');
  return '${p(t.day)}/${p(t.month)} ${p(t.hour)}:${p(t.minute)}:${p(t.second)}';
}

/// Bỏ ".0" khi số là số nguyên (50.0 -> "50")
String _fmtNum(num v) => v == v.round() ? v.toInt().toString() : v.toString();

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final HistoryStore _store = HistoryStore();

  @override
  void initState() {
    super.initState();
    _store.load();
    _store.addListener(_onHistoryChanged);
    MessagingService.init(store: _store); // setup FCM + 3 trạng thái
  }

  void _onHistoryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_onHistoryChanged);
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('IoT Push Lab'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          bottom: TabBar(
            tabs: [
              const Tab(icon: Icon(Icons.tune, size: 20), text: 'Ngưỡng'),
              Tab(
                icon: const Icon(Icons.history, size: 20),
                text: 'Lịch sử (${_store.items.length})',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const _ThresholdsTab(),
            _HistoryTab(store: _store),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1: FCM token / trạng thái + chỉnh ngưỡng cảnh báo
// ---------------------------------------------------------------------------

class _ThresholdsTab extends StatelessWidget {
  const _ThresholdsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: const [
        _TokenCard(),
        SizedBox(height: 8),
        _ThresholdsCard(),
      ],
    );
  }
}

class _TokenCard extends StatelessWidget {
  const _TokenCard();

  Future<void> _copy(BuildContext context, String token) async {
    await Clipboard.setData(ClipboardData(text: token));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã copy FCM token')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FCM token', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            ValueListenableBuilder<String?>(
              valueListenable: MessagingService.fcmToken,
              builder: (_, token, _) => Row(
                children: [
                  Expanded(
                    child: Text(
                      token ?? 'Đang lấy token (thiếu google-services.json?)',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  if (token != null)
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      tooltip: 'Copy token',
                      onPressed: () => _copy(context, token),
                    ),
                ],
              ),
            ),
            const Divider(),
            ValueListenableBuilder<bool>(
              valueListenable: MessagingService.topicOk,
              builder: (_, ok, _) => Row(
                children: [
                  Icon(ok ? Icons.check_circle : Icons.error,
                      size: 16, color: ok ? Colors.green : Colors.red),
                  const SizedBox(width: 6),
                  Text(ok
                      ? 'Đã subscribe topic "alerts"'
                      : 'Chưa subscribe được topic "alerts"'),
                ],
              ),
            ),
            ValueListenableBuilder<String?>(
              valueListenable: MessagingService.permissionStatus,
              builder: (_, st, _) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      st == 'granted' ? Icons.notifications_active : Icons.notifications_off,
                      size: 16,
                      color: st == 'granted' ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Text('Quyền thông báo: ${st ?? "chưa rõ"}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThresholdsCard extends StatefulWidget {
  const _ThresholdsCard();

  @override
  State<_ThresholdsCard> createState() => _ThresholdsCardState();
}

class _ThresholdsCardState extends State<_ThresholdsCard> {
  final TextEditingController _server = TextEditingController(text: ServerConfig.baseUrl);
  final TextEditingController _high = TextEditingController();
  final TextEditingController _low = TextEditingController();
  final TextEditingController _gas = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _updatedAt = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _server.dispose();
    _high.dispose();
    _low.dispose();
    _gas.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final t = await ThresholdsApi.fetch();
      if (!mounted) return;
      setState(() {
        _high.text = _fmtNum(t.tempHigh);
        _low.text = _fmtNum(t.tempLow);
        _gas.text = t.gasThreshold.toString();
        _updatedAt = t.updatedAt;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được ngưỡng từ server: $e';
      });
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final high = double.tryParse(_high.text.trim().replaceAll(',', '.'));
    final low = double.tryParse(_low.text.trim().replaceAll(',', '.'));
    final gas = int.tryParse(_gas.text.trim());

    if (high == null || low == null || gas == null) {
      setState(() => _error = 'Ngưỡng phải là số');
      return;
    }
    if (low >= high) {
      setState(() => _error = 'Ngưỡng nhiệt độ thấp phải nhỏ hơn ngưỡng cao');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Lưu luôn địa chỉ server người dùng vừa nhập
      await ServerConfig.save(_server.text);
      _server.text = ServerConfig.baseUrl;
      final t = await ThresholdsApi.save(
        tempHigh: high,
        tempLow: low,
        gasThreshold: gas,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _updatedAt = t.updatedAt;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã lưu lên server: cao >${_fmtNum(t.tempHigh)}°C, '
            'thấp <${_fmtNum(t.tempLow)}°C, gas >${t.gasThreshold}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Lưu thất bại: $e';
      });
    }
  }

  String get _stamp {
    if (_updatedAt.isEmpty) return 'Ngưỡng mặc định của server';
    final t = DateTime.tryParse(_updatedAt)?.toLocal();
    return t == null ? 'Đã cập nhật' : 'Cập nhật lúc ${_fmtTime(t)}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Ngưỡng cảnh báo tự động',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Lấy lại ngưỡng từ server',
                  onPressed: _loading || _saving ? null : _load,
                ),
              ],
            ),
            Text(
              'Hệ thống tự gửi cảnh báo khi cảm biến vượt ngưỡng. '
              'Ngưỡng lưu trên server nên dashboard web cũng cập nhật theo.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _server,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ server',
                helperText: 'IP máy tính chạy server + cổng 3000 (cùng mạng WiFi)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text('Đang tải ngưỡng...'),
                  ],
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _high,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: const InputDecoration(
                        labelText: 'Nhiệt độ CAO hơn (°C)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _low,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: const InputDecoration(
                        labelText: 'Nhiệt độ THẤP hơn (°C)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _gas,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Khí gas vượt (thang 0–4095)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined, size: 20),
                label: Text(_saving ? 'Đang lưu...' : 'Lưu ngưỡng lên server'),
              ),
              const SizedBox(height: 6),
              Text(_stamp, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12.5),
                ),
              ),

          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Lịch sử thông báo
// ---------------------------------------------------------------------------

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.store});

  final HistoryStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = store.items;
        if (items.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              Text('Chưa có thông báo nào. Gửi test từ dashboard web, '
                  'Firebase Console hoặc chạy simulator.'),
            ],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final a = items[i];
            final s = AlertStyle.of(a.type);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: s.color,
                  child: Icon(s.icon, color: Colors.white),
                ),
                title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.body),
                    const SizedBox(height: 2),
                    Text(
                      '${_fmtTime(a.time)}  •  ${s.label}'
                      '${a.deviceId.isNotEmpty ? "  •  ${a.deviceId}" : ""}'
                      '${a.value.isNotEmpty ? "  •  giá trị ${a.value}" : ""}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}
