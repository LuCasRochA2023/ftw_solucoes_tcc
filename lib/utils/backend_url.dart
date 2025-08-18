import 'environment_config.dart';

class BackendUrl {
  // Para desenvolvimento local
  static const String localUrl = 'https://srv962030.hstgr.cloud';

  // Para emulador Android
  static const String androidEmulatorUrl = 'https://srv962030.hstgr.cloud';

  // Para dispositivo físico (substitua pelo seu IP local)
  static const String deviceUrl = 'http://192.168.1.100:3001';

  // URL do backend em produção
  static const String productionUrl = 'https://srv962030.hstgr.cloud';

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
