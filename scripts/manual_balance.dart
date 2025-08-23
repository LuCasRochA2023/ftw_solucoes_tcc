// Script para adicionar saldo manualmente
// Copie este código e execute no seu projeto Flutter

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

      print('✅ Saldo adicionado com sucesso!');
      print('💰 Saldo anterior: R\$ ${currentBalance.toStringAsFixed(2)}');
      print('💰 Saldo atual: R\$ ${newBalance.toStringAsFixed(2)}');
      print('💰 Valor adicionado: R\$ ${amount.toStringAsFixed(2)}');
    } else {
      print('❌ Usuário não encontrado!');
    }
  } catch (e) {
    print('❌ Erro: $e');
  }
}

// Exemplo de uso:
// addManualBalance(userId: 'SEU_USER_ID', amount: 100.0);
