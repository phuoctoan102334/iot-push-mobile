// ============================================================
// TẠM THỜI — placeholder sẽ bị `flutterfire configure` GHI ĐÈ.
// Chạy flutterfire configure (sau khi firebase login) để file này
// chứa API key/appId/projectId THẬT của dự án Firebase.
// ============================================================
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Lab nay chi ho tro Android');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Lab nay chi ho tro Android');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'PLACEHOLDER_CHUA_CHAY_FLUTTERFIRE_CONFIGURE',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'placeholder-project',
  );
}
