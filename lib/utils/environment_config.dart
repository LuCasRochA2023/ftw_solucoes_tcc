import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvironmentConfig {
  // Configuração do ambiente
  static const bool isProduction = true; // Usando produção com URL fornecida

  // URLs dos backends
  static const String localBackendUrl = 'http://10.0.2.2:3001';
  static const String productionBackendUrl =
      'https://back-end-ftw-flutter-1.onrender.com';

  // Configurações do Mercado Pago
  static String get mercadopagoPublicKey {
    return dotenv.env['MERCADOPAGO_PUBLIC_KEY'] ??
        'APP_USR-a182e1ab-4e96-4223-8621-fd3d52a76d0c';
  }

  static String get mercadopagoAccessToken {
    return dotenv.env['MERCADOPAGO_ACCESS_TOKEN'] ??
        'APP_USR-1234567890123456789012345678901234567890';
  }

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

  // Métodos para obter configurações do Mercado Pago
  static String get mercadopagoPublicKeyValue => mercadopagoPublicKey;
  static String get mercadopagoAccessTokenValue => mercadopagoAccessToken;
}
