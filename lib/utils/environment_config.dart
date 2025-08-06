
class EnvironmentConfig {
  // Configuração do ambiente
  static const bool isProduction = true; // Usando produção com URL fornecida
  
  // URLs dos backends
  static const String localBackendUrl = 'http://10.0.2.2:3001';
  static const String productionBackendUrl = 'https://back-end-ftw-flutter-1.onrender.com';
  
  // URL ativa baseada no ambiente
  static String get activeBackendUrl {
    if (isProduction) {
      return productionBackendUrl;
    } else {
      return localBackendUrl;
    }
  }
  
  // Configurações específicas por ambiente
  static Map<String, dynamic> get config {
    if (isProduction) {
      return {
        'backendUrl': productionBackendUrl,
        'environment': 'production',
        'debugMode': false,
      };
    } else {
      return {
        'backendUrl': localBackendUrl,
        'environment': 'development',
        'debugMode': true,
      };
    }
  }
  
  // Método para verificar se está em produção
  static bool get isProductionMode => isProduction;
  
  // Método para verificar se está em desenvolvimento
  static bool get isDevelopmentMode => !isProduction;
}
