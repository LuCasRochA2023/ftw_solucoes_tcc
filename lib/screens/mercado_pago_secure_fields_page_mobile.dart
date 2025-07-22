import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

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
  bool isLoading = true;
  bool showWebView = false;
  late final String paymentUrl;
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    paymentUrl = 'https://ftw-back-end-6.onrender.com';
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => isLoading = true),
          onPageFinished: (_) => setState(() => isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse(paymentUrl));
    _checkBackendReady();
  }

  Future<void> _checkBackendReady() async {
    while (true) {
      try {
        final response = await http.get(Uri.parse(paymentUrl));
        if (response.statusCode == 200) {
          setState(() {
            showWebView = true;
            isLoading = false;
          });
          break;
        }
      } catch (e) {}
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pagamento')),
      body: Stack(
        children: [
          if (showWebView) WebViewWidget(controller: controller),
          if (isLoading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Carregando pagamento...')
                ],
              ),
            ),
        ],
      ),
    );
  }
}
