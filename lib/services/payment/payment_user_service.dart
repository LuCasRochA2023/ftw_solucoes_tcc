import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentUserService {
  const PaymentUserService._();

  static Future<String?> loadCurrentUserCpf() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final snap =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = snap.data();
    final cpf = (data?['cpf'] ?? '').toString().trim();
    if (cpf.isEmpty) return null;
    return cpf;
  }
}
