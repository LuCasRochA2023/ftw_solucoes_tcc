import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthStateService extends ChangeNotifier {
  final FirebaseAuth _auth;
  User? _user;

  AuthStateService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  User? get currentUser => _user;
  bool get isAuthenticated => _user != null;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
