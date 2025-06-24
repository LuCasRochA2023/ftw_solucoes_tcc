import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class MercadoPagoSecureFieldsPage extends StatefulWidget {
  final double amount;
  final Map<String, dynamic> userData;

  const MercadoPagoSecureFieldsPage({
    Key? key,
    required this.amount,
    required this.userData,
  }) : super(key: key);

  @override
  State<MercadoPagoSecureFieldsPage> createState() =>
      _MercadoPagoSecureFieldsPageState();
}

class _MercadoPagoSecureFieldsPageState
    extends State<MercadoPagoSecureFieldsPage> {
  final Completer<String> _tokenCompleter = Completer<String>();
  String? _errorMessage;
  bool _isLoading = true;
  InAppWebViewController? _webViewController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagamento Seguro'),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri('https://ftw-back-end-5.onrender.com'),
              headers: {
                'Cache-Control': 'no-cache',
                'Pragma': 'no-cache',
              },
            ),
            onLoadStart: (controller, url) {
              debugPrint('Página iniciando carregamento: $url');
              setState(() => _isLoading = true);
            },
            onLoadStop: (controller, url) {
              debugPrint('Página carregada: $url');
              setState(() => _isLoading = false);
              _webViewController = controller;
              _injectUserData(controller);
            },
            onLoadError: (controller, url, code, message) {
              debugPrint('Erro ao carregar página: $message (código: $code)');
              setState(() {
                _errorMessage = 'Erro ao carregar página: $message';
                _isLoading = false;
              });
            },
            onConsoleMessage: (controller, consoleMessage) {
              debugPrint('Console: ${consoleMessage.message}');
            },
            onWebViewCreated: (controller) {
              debugPrint('WebView criada');
              _webViewController = controller;

              controller.addJavaScriptHandler(
                handlerName: 'onSuccess',
                callback: (args) {
                  debugPrint('Callback onSuccess recebido: $args');
                  if (args.isNotEmpty && args[0] is Map) {
                    final data = args[0] as Map;
                    if (!_tokenCompleter.isCompleted) {
                      _tokenCompleter.complete(data['token'] as String);
                    }
                  }
                },
              );

              controller.addJavaScriptHandler(
                handlerName: 'onError',
                callback: (args) {
                  debugPrint('Callback onError recebido: $args');
                  if (args.isNotEmpty) {
                    setState(() {
                      _errorMessage = args[0].toString();
                    });
                    if (!_tokenCompleter.isCompleted) {
                      _tokenCompleter.completeError(args[0].toString());
                    }
                  }
                },
              );
            },
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          if (_errorMessage != null)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _injectUserData(InAppWebViewController controller) {
    debugPrint('Iniciando injeção de dados do usuário');

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      final userData = jsonDecode(_prepareUserData());
      debugPrint('Dados preparados para envio: $userData');

      controller.evaluateJavascript(source: '''
      try {
        if (typeof receiveUserData === 'function') {
          receiveUserData(${jsonEncode(userData)});
        } else {
          window.flutter_inappwebview.callHandler('onError', 'SDK do Mercado Pago não carregado');
        }
      } catch (e) {
        window.flutter_inappwebview.callHandler('onError', 'Erro ao enviar dados: ' + e.message);
      }
    ''');
    });
  }

  String _prepareUserData() {
    final data = {
      'amount': widget.amount,
      'payer': {
        'email': widget.userData['email'],
        'identification': {
          'type': 'CPF',
          'number': widget.userData['cpf']?.replaceAll(RegExp(r'[^\d]'), ''),
        },
        'entityType': 'individual',
      },
    };

    return jsonEncode(data);
  }

  Future<String> getToken() => _tokenCompleter.future;
}
