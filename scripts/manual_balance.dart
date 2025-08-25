// Script para adicionar saldo manualmente
// Copie este código e execute no seu projeto Flutter

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

Future<void> addManualBalance({
  required String userId,
  required double amount,
}) async {
  try {
    final firestore = FirebaseFirestore.instance;

    // Buscar saldo atual
    final userDoc = await firestore.collection('users').doc(userId).get();

    if (userDoc.exists) {
      final currentBalance = (userDoc.data()?['balance'] ?? 0.0).toDouble();
      final newBalance = currentBalance + amount;

      // Atualizar saldo
      await firestore.collection('users').doc(userId).update({
        'balance': newBalance,
      });

      // Registrar transação
      await firestore.collection('transactions').add({
        'userId': userId,
        'amount': amount,
        'type': 'credit',
        'description': 'Adição manual de saldo',
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Saldo adicionado com sucesso!');
      debugPrint('Saldo anterior: R\$ ${currentBalance.toStringAsFixed(2)}');
      debugPrint(' Saldo atual: R\$ ${newBalance.toStringAsFixed(2)}');
      debugPrint('Valor adicionado: R\$ ${amount.toStringAsFixed(2)}');
    } else {
      debugPrint(' Usuário não encontrado!');
    }
  } catch (e) {
    debugPrint('Erro: $e');
  }
}
