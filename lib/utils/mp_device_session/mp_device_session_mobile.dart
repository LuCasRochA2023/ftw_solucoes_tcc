import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Gera e retorna o `MP_DEVICE_SESSION_ID` (Mercado Pago) em Android/iOS
/// carregando o `security.js` dentro de um WebView invisível.
///
/// Importante:
/// - Isso atende a exigência de "Identificador do dispositivo" sem migrar
///   agora a tokenização para o MercadoPago.JS V2.
/// - Se falhar por qualquer motivo, retorna null (o backend pode lidar).
class MpDeviceSessionMobile {
  MpDeviceSessionMobile._();

  static final MpDeviceSessionMobile instance = MpDeviceSessionMobile._();

  HeadlessInAppWebView? _headless;
  bool _isStarting = false;
  String? _cached;

  Future<String?> getOrCreate() async {
    if (_cached != null && _cached!.trim().isNotEmpty) return _cached;
    if (_isStarting) {
      // Aguarda um pouco e devolve o cache se já tiver sido preenchido.
      await Future.delayed(const Duration(milliseconds: 300));
      return _cached;
    }

    _isStarting = true;
    try {
      // HTML mínimo: carrega security.js e expõe MP_DEVICE_SESSION_ID no window.
      final html = '''
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <script src="https://www.mercadopago.com/v2/security.js" view="checkout"></script>
  </head>
  <body>ok</body>
</html>
''';

      String? result;

      _headless = HeadlessInAppWebView(
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          // Não precisamos de UI, só carregar e ler variável global.
          transparentBackground: true,
          clearCache: false,
          mediaPlaybackRequiresUserGesture: false,
        ),
        initialData: InAppWebViewInitialData(data: html),
        onLoadStop: (controller, _) async {
          try {
            // Dá um pequeno tempo pro script inicializar.
            await Future.delayed(const Duration(milliseconds: 300));
            final v = await controller.evaluateJavascript(
              source:
                  "typeof MP_DEVICE_SESSION_ID !== 'undefined' ? MP_DEVICE_SESSION_ID : null;",
            );
            if (v != null) {
              final s = v.toString().trim();
              if (s.isNotEmpty) {
                result = s;
                _cached = s;
              }
            }
          } catch (_) {
            // ignore
          } finally {
            try {
              await _headless?.dispose();
            } catch (_) {
              // ignore
            }
            _headless = null;
          }
        },
      );

      await _headless!.run();

      // Aguarda até 2s pelo resultado.
      final startedAt = DateTime.now();
      while (result == null &&
          DateTime.now().difference(startedAt).inMilliseconds < 2000) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return result;
    } catch (_) {
      return null;
    } finally {
      _isStarting = false;
    }
  }
}
