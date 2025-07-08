import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class PaymentService {
  static const String _baseUrl =
      'http://10.0.2.2:8080'; // Para desenvolvimento local (emulador Android)
  // static const String _baseUrl = 'https://seu-backend-producao.com'; // Para produção

  /// Processa um pagamento via cartão de crédito
  static Future<Map<String, dynamic>> processCreditCardPayment({
    required double amount,
    required String token,
    required String description,
    required Map<String, dynamic> payer,
    int installments = 1,
    String paymentMethodId = 'master',
  }) async {
    try {
      final idempotencyKey = const Uuid().v4();

      final paymentData = {
        'transaction_amount': amount,
        'token': token,
        'description': description,
        'installments': installments,
        'payment_method_id': paymentMethodId,
        'payer': payer,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/payment/v2'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Idempotency-Key': idempotencyKey,
        },
        body: jsonEncode(paymentData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['error_message'] ?? 'Erro ao processar pagamento',
        );
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  /// Obtém a public key do Mercado Pago
  static Future<String> getPublicKey() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/public-key'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['public_key'];
      } else {
        throw Exception('Erro ao obter public key');
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  /// Valida se o backend está disponível
  static Future<bool> isBackendAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/public-key'),
        headers: {'Accept': 'application/json'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
