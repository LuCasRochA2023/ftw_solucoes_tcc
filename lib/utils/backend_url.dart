import 'package:flutter/foundation.dart' show kReleaseMode, kIsWeb;
import 'dart:io' show Platform;
import 'environment_config.dart';

class BackendUrl {
  // Para desenvolvimento local
  static const String localUrl = 'http://10.0.2.2:3001';

  // Para emulador Android
  static const String androidEmulatorUrl = 'http://10.0.2.2:3001';

  // Para dispositivo físico (substitua pelo seu IP local)
  static const String deviceUrl = 'http://192.168.1.100:3001';

  // URL do backend em produção (Render)
  static const String productionUrl = 'https://back-end-ftw-flutter-1.onrender.com';

  // URL padrão - usa a configuração de ambiente
  static String get baseUrl {
    return EnvironmentConfig.activeBackendUrl;
  }
  
  // Método para obter URL específica por ambiente
  static String getUrlForEnvironment(String environment) {
    switch (environment.toLowerCase()) {
      case 'local':
        return localUrl;
      case 'android':
        return androidEmulatorUrl;
      case 'device':
        return deviceUrl;
      case 'production':
        return productionUrl;
      default:
        return EnvironmentConfig.activeBackendUrl;
    }
  }
}
