import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:html' as html;

class MercadoPagoSecureFieldsPage extends StatelessWidget {
  final double amount;
  final Map<String, dynamic> userData;

  const MercadoPagoSecureFieldsPage({
    Key? key,
    required this.amount,
    required this.userData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final paymentUrl = 'https://ftw-back-end-6.onrender.com';
    // Registra o iframe para Flutter Web
    // O viewType precisa ser único por URL
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      'iframe-$paymentUrl',
      (int viewId) => html.IFrameElement()
        ..src = paymentUrl
        ..style.border = 'none'
        ..width = '100%'
        ..height = '600',
    );
    return Scaffold(
      appBar: AppBar(title: Text('Pagamento')),
      body: Center(
        child: SizedBox(
          width: double.infinity,
          height: 600,
          child: HtmlElementView(viewType: 'iframe-$paymentUrl'),
        ),
      ),
    );
  }
}
