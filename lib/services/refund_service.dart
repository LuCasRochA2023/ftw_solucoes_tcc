import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class RefundService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Devolve dinheiro para a carteira do usuário quando um serviço é cancelado
  /// Para TODOS os serviços confirmados, independente do método de pagamento
  static Future<void> refundToWalletOnCancellation({
    required String appointmentId,
    required String userId,
    required double amount,
    required String paymentMethod,
    required String serviceTitle,
  }) async {
    try {
      debugPrint(
          '=== DEBUG: Iniciando devolução para carteira no cancelamento ===');
      debugPrint('AppointmentId: $appointmentId');
      debugPrint('UserId: $userId');
      debugPrint('Amount: R\$ ${amount.toStringAsFixed(2)}');
      debugPrint('PaymentMethod: $paymentMethod');

      // Buscar saldo atual do usuário
      final userDoc = await _firestore.collection('users').doc(userId).get();

      final currentBalance = (userDoc.data()?['balance'] ?? 0.0).toDouble();
      final newBalance = currentBalance + amount;

      // Atualizar saldo do usuário
      await _firestore
          .collection('users')
          .doc(userId)
          .update({'balance': newBalance});

      // Registrar transação de crédito (devolução)
      await _firestore.collection('transactions').add({
        'userId': userId,
        'amount': amount,
        'type': 'credit',
        'description': 'Devolução - Cancelamento - $serviceTitle',
        'appointmentId': appointmentId,
        'paymentMethod': paymentMethod,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Marcar pagamento como devolvido
      final paymentsQuery = await _firestore
          .collection('payments')
          .where('appointmentId', isEqualTo: appointmentId)
          .where('status', isEqualTo: 'paid')
          .get();

      if (paymentsQuery.docs.isNotEmpty) {
        await paymentsQuery.docs.first.reference.update({
          'status': 'refunded',
          'refundedAt': FieldValue.serverTimestamp(),
        });
      }

      debugPrint(
          '=== DEBUG: Devolução no cancelamento processada com sucesso ===');
      debugPrint('Saldo anterior: R\$ ${currentBalance.toStringAsFixed(2)}');
      debugPrint('Saldo atual: R\$ ${newBalance.toStringAsFixed(2)}');
    } catch (e) {
      debugPrint('Erro ao devolver dinheiro para carteira no cancelamento: $e');
      throw Exception('Erro ao processar devolução: $e');
    }
  }

  /// Verifica se um pagamento é elegível para devolução
  /// Agora aceita qualquer método de pagamento para serviços confirmados
  static Future<bool> isPaymentEligibleForRefund(String appointmentId) async {
    try {
      final paymentQuery = await _firestore
          .collection('payments')
          .where('appointmentId', isEqualTo: appointmentId)
          .where('status', isEqualTo: 'paid')
          .get();

      if (paymentQuery.docs.isNotEmpty) {
        final paymentData = paymentQuery.docs.first.data();
        final canRefund = paymentData['canRefund'] as bool? ?? false;

        // Para serviços confirmados, aceitar qualquer método de pagamento
        return canRefund;
      }

      return false;
    } catch (e) {
      debugPrint('Erro ao verificar elegibilidade para devolução: $e');
      return false;
    }
  }

  /// Obtém informações do pagamento para devolução
  static Future<Map<String, dynamic>?> getPaymentInfo(
      String appointmentId) async {
    try {
      final paymentQuery = await _firestore
          .collection('payments')
          .where('appointmentId', isEqualTo: appointmentId)
          .where('status', isEqualTo: 'paid')
          .get();

      if (paymentQuery.docs.isNotEmpty) {
        return paymentQuery.docs.first.data();
      }

      return null;
    } catch (e) {
      debugPrint('Erro ao obter informações do pagamento: $e');
      return null;
    }
  }
}
