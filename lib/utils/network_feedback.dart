import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class NetworkFeedback {
  static const String connectionMessage = 'Erro ao conectar. Tente novamente.';

  static Future<bool> hasInternet() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (!hasNetwork) return false;

      // Rede conectada, mas pode não ter rota real para internet.
      // Usamos múltiplas estratégias e consideramos online se qualquer uma funcionar.

      // 1) Socket rápido para DNS público (TCP).
      const targets = <({String host, int port})>[
        (host: '1.1.1.1', port: 53),
        (host: '8.8.8.8', port: 53),
      ];
      for (final t in targets) {
        Socket? s;
        try {
          s = await Socket.connect(
            t.host,
            t.port,
            timeout: const Duration(seconds: 2),
          );
          return true;
        } catch (_) {
          // tenta próximo
        } finally {
          try {
            s?.destroy();
          } catch (_) {}
        }
      }

      // 2) DNS lookup (pode falhar em redes com bloqueio).
      try {
        final addrs = await InternetAddress.lookup('example.com')
            .timeout(const Duration(seconds: 3));
        if (addrs.isNotEmpty) return true;
      } catch (_) {}

      // 3) HTTP HEAD leve (aceita 200-399; captive portal costuma responder 30x/200).
      final urls = <Uri>[
        Uri.parse('https://www.gstatic.com/generate_204'),
        Uri.parse('https://clients3.google.com/generate_204'),
        Uri.parse('https://example.com/'),
      ];
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      try {
        for (final u in urls) {
          try {
            final req = await client.headUrl(u).timeout(const Duration(seconds: 3));
            req.followRedirects = true;
            req.maxRedirects = 3;
            final res = await req.close().timeout(const Duration(seconds: 3));
            if (res.statusCode >= 200 && res.statusCode < 400) return true;
          } catch (_) {
            // tenta próximo
          }
        }
      } finally {
        client.close(force: true);
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  static bool isConnectionError(Object e) {
    if (e is TimeoutException) return true;
    if (e is SocketException) return true;
    if (e is HandshakeException) return true;

    if (e is FirebaseException) {
      // Erros típicos de conectividade/indisponibilidade.
      return e.code == 'unavailable' ||
          e.code == 'deadline-exceeded' ||
          e.code == 'resource-exhausted' ||
          e.code == 'internal' ||
          e.code == 'aborted';
    }

    final msg = e.toString().toLowerCase();
    return msg.contains('cloud_firestore/unavailable') ||
        msg.contains('deadline-exceeded') ||
        msg.contains('timed out') ||
        msg.contains('timeout') ||
        msg.contains('no route to host') ||
        msg.contains('network is unreachable') ||
        msg.contains('host unreachable') ||
        msg.contains('connection refused') ||
        msg.contains('connection reset') ||
        msg.contains('unavailable');
  }

  static void showConnectionSnackBar(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text(connectionMessage),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }
}

