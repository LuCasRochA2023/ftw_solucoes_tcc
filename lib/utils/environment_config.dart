import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centraliza configurações vindas do `.env`.
///
/// Importante: o `.env` está no `.gitignore`, então sempre tenha um fallback
/// seguro para não quebrar o app em ambiente sem variáveis.
class EnvironmentConfig {
  // Backend
  static String get activeBackendUrl =>
      _envFirst([
        'ACTIVE_BACKEND_URL',
        'BACKEND_URL',
        'API_URL',
      ]) ??
      // Fallback (mesmo domínio usado no projeto)
      'https://srv962030.hstgr.cloud';

  // Mercado Pago
  static String get mercadopagoPublicKeyValue =>
      _envFirst([
        'MERCADOPAGO_PUBLIC_KEY',
        'MP_PUBLIC_KEY',
        'MERCADOPAGO_PUB_KEY',
      ]) ??
      '';

  static String get mpNotificationUrlValue =>
      _envFirst([
        'MP_NOTIFICATION_URL',
        'MERCADOPAGO_NOTIFICATION_URL',
        'MERCADOPAGO_WEBHOOK_URL',
      ]) ??
      // fallback razoável: endpoint no backend (ajuste se seu backend usar outro path)
      '${activeBackendUrl.replaceAll(RegExp(r"/+$"), "")}/mp-notification';

  static String? _envFirst(List<String> keys) {
    for (final k in keys) {
      final v = dotenv.env[k];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }
}
