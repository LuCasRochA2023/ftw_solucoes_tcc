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
  int _injectionAttempts = 0;
  static const int _maxInjectionAttempts = 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pagamento Seguro')),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri('http://10.0.2.2:8080'),
              headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
            ),
            onLoadStart: (controller, url) {
              debugPrint('Página iniciando carregamento: $url');
              setState(() => _isLoading = true);
            },
            onLoadStop: (controller, url) {
              debugPrint('Página carregada: $url');
              setState(() => _isLoading = false);
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
          if (_isLoading) const Center(child: CircularProgressIndicator()),
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
    debugPrint(
        'Iniciando injeção de dados do usuário (tentativa ${_injectionAttempts + 1})');

    // Verifica se excedeu o número máximo de tentativas
    if (_injectionAttempts >= _maxInjectionAttempts) {
      debugPrint('Número máximo de tentativas excedido');
      if (!_tokenCompleter.isCompleted) {
        _tokenCompleter.completeError(
            'SDK do Mercado Pago não carregou após várias tentativas');
      }
      return;
    }

    _injectionAttempts++;

    // Aguarda mais tempo para o SDK carregar completamente
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;

      final userData = jsonDecode(_prepareUserData());
      debugPrint('Dados preparados para envio: $userData');

      // Primeiro, verifica se o SDK está carregado
      final sdkCheckResult = await controller.evaluateJavascript(
        source: '''
        (function() {
          try {
            if (typeof MercadoPago !== 'undefined' && typeof receiveUserData === 'function') {
              return 'ready';
            } else if (typeof MercadoPago !== 'undefined') {
              return 'sdk_loaded';
            } else {
              return 'not_ready';
            }
          } catch (e) {
            return 'error: ' + e.message;
          }
        })();
      ''',
      );

      debugPrint('Status do SDK: $sdkCheckResult');

             if (sdkCheckResult == 'ready') {
         // SDK está pronto, injeta os dados
         controller.evaluateJavascript(
           source: '''
         try {
           if (typeof receiveUserData === 'function') {
             receiveUserData(${jsonEncode(userData)});
             console.log('Dados enviados para receiveUserData:', ${jsonEncode(userData)});
           } else {
             console.error('Função receiveUserData não encontrada');
             window.flutter_inappwebview.callHandler('onError', 'Função receiveUserData não encontrada');
           }
         } catch (e) {
           console.error('Erro ao enviar dados:', e.message);
           window.flutter_inappwebview.callHandler('onError', 'Erro ao enviar dados: ' + e.message);
         }
       ''',
         );
      } else if (sdkCheckResult == 'sdk_loaded') {
        // SDK carregado mas função não disponível, tenta novamente
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          _injectUserData(controller);
        });
      } else {
        // SDK não carregado, tenta novamente
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          _injectUserData(controller);
        });
      }
    });
  }

  String _prepareUserData() {
    // Garante que o CPF está limpo (apenas números)
    final cpf =
        widget.userData['cpf']?.toString().replaceAll(RegExp(r'[^\d]'), '') ??
            '';

    // Garante que o email está disponível
    final email = widget.userData['email']?.toString() ?? '';

    // Log dos dados para debug
    debugPrint('Preparando dados do usuário:');
    debugPrint('Email: $email');
    debugPrint('CPF: $cpf');
    debugPrint('Valor: ${widget.amount}');

    final data = {
      'amount': widget.amount,
      'description': 'Pagamento FTW Soluções',
      'payer': {
        'email': email,
        'identification': {
          'type': 'CPF',
          'number': cpf,
        },
        'entityType': 'individual',
      },
    };

    return jsonEncode(data);
  }

  Future<String> getToken() => _tokenCompleter.future;
}
