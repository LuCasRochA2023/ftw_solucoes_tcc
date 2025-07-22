import 'package:flutter/foundation.dart' show kReleaseMode, kIsWeb;
import 'dart:io' show Platform;

String getBackendUrl() {
  if (kReleaseMode) {
    // Produção: Render
    return 'https://ftw-back-end-6.onrender.com';
  } else if (kIsWeb) {
    // Desenvolvimento web
    return 'http://localhost:8080';
  } else if (Platform.isAndroid) {
    // Emulador Android
    return 'https://ftw-back-end-6.onrender.com';
  } else {
    // Outros casos (iOS, desktop)
    return 'http://localhost:8080';
  }
}
