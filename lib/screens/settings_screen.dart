import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ftw_solucoes/screens/profile_screen.dart';
import 'package:ftw_solucoes/screens/change_password_screen.dart';
import 'package:ftw_solucoes/screens/service_history_screen.dart';
import 'package:ftw_solucoes/services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  final AuthService authService;

  const SettingsScreen({super.key, required this.authService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  Future<void> _showDeleteAccountDialog() async {
    final TextEditingController passwordController = TextEditingController();

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Excluir Conta',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Esta ação não pode ser desfeita. Para confirmar, digite sua senha:',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'Senha',
                labelStyle: GoogleFonts.poppins(),
                border: const OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Excluir',
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final user = _auth.currentUser;
        if (user != null) {
          // Reautenticar o usuário antes de excluir a conta
          final credential = EmailAuthProvider.credential(
            email: user.email!,
            password: passwordController.text,
          );

          await user.reauthenticateWithCredential(credential);

          await _firestore.collection('users').doc(user.uid).delete();
          await user.delete();
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          }
        }
      } catch (e) {
        if (mounted) {
          String errorMessage = 'Erro ao excluir conta';
          if (e is FirebaseAuthException) {
            switch (e.code) {
              case 'wrong-password':
                errorMessage = 'Senha incorreta';
                break;
              case 'too-many-requests':
                errorMessage = 'Muitas tentativas. Tente novamente mais tarde';
                break;
              default:
                errorMessage = 'Erro ao excluir conta: ${e.message}';
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Configurações',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Perfil'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              ProfileScreen(authService: widget.authService)),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.lock),
                  title: const Text('Alterar Senha'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ChangePasswordScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Histórico de Serviços'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ServiceHistoryScreen(
                              authService: widget.authService)),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Excluir Conta',
                      style: TextStyle(color: Colors.red)),
                  onTap: _showDeleteAccountDialog,
                ),
              ],
            ),
    );
  }
}
