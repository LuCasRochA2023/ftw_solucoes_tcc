import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() {
  group('AuthService - Testes Básicos', () {
    test('deve validar formato de email', () {
      // Arrange
      const emailValido = 'teste@exemplo.com';
      const emailInvalido = 'email-invalido';

      // Act & Assert
      expect(_isValidEmail(emailValido), isTrue);
      expect(_isValidEmail(emailInvalido), isFalse);
    });

    test('deve validar força da senha', () {
      // Arrange
      const senhaForte = 'Senha123!';
      const senhaFraca = '123';

      // Act & Assert
      expect(_isStrongPassword(senhaForte), isTrue);
      expect(_isStrongPassword(senhaFraca), isFalse);
    });

    test('deve validar CPF válido', () {
      // Arrange
      const cpfValido = '52998224725'; // CPF válido
      const cpfInvalido = '123';

      // Act & Assert
      expect(_isValidCpf(cpfValido), isTrue);
      expect(_isValidCpf(cpfInvalido), isFalse);
    });

    test('deve retornar mensagem amigável para erro de usuário não encontrado',
        () {
      // Arrange
      final erro = FirebaseAuthException(code: 'user-not-found');

      // Act
      final mensagem = _handleAuthError(erro);

      // Assert
      expect(mensagem, contains('não encontrado'));
    });

    test('deve retornar mensagem amigável para erro de senha incorreta', () {
      // Arrange
      final erro = FirebaseAuthException(code: 'wrong-password');

      // Act
      final mensagem = _handleAuthError(erro);

      // Assert
      expect(mensagem, contains('incorreta'));
    });

    test('deve retornar mensagem amigável para erro de email já em uso', () {
      // Arrange
      final erro = FirebaseAuthException(code: 'email-already-in-use');

      // Act
      final mensagem = _handleAuthError(erro);

      // Assert
      expect(mensagem, contains('já está em uso'));
    });

    test('deve retornar mensagem para erro de rede', () {
      // Arrange
      final erro = FirebaseAuthException(code: 'network-request-failed');

      // Act
      final mensagem = _handleAuthError(erro);

      // Assert
      expect(mensagem, contains('Erro de conexão'));
    });

    test('deve retornar mensagem para senha fraca', () {
      // Arrange
      final erro = FirebaseAuthException(code: 'weak-password');

      // Act
      final mensagem = _handleAuthError(erro);

      // Assert
      expect(mensagem, contains('muito fraca'));
    });

    test('deve retornar mensagem genérica para erro desconhecido', () {
      // Arrange
      final erro = FirebaseAuthException(code: 'unknown-error');

      // Act
      final mensagem = _handleAuthError(erro);

      // Assert
      expect(mensagem, contains('Ocorreu um erro'));
    });
  });
}

// Funções auxiliares para validação (simulando as que estariam no AuthService)
bool _isValidEmail(String email) {
  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  return emailRegex.hasMatch(email);
}

bool _isStrongPassword(String password) {
  // Senha deve ter pelo menos 6 caracteres
  if (password.length < 6) return false;

  // Deve conter pelo menos uma letra maiúscula
  if (!password.contains(RegExp(r'[A-Z]'))) return false;

  // Deve conter pelo menos uma letra minúscula
  if (!password.contains(RegExp(r'[a-z]'))) return false;

  // Deve conter pelo menos um número
  if (!password.contains(RegExp(r'[0-9]'))) return false;

  return true;
}

bool _isValidCpf(String cpf) {
  // Remove caracteres não numéricos
  final cleanCpf = cpf.replaceAll(RegExp(r'[^\d]'), '');

  // CPF deve ter 11 dígitos
  if (cleanCpf.length != 11) return false;

  // Verifica se todos os dígitos são iguais (CPF inválido)
  if (RegExp(r'^(\d)\1{10}$').hasMatch(cleanCpf)) return false;

  // Validação dos dígitos verificadores
  int sum = 0;
  for (int i = 0; i < 9; i++) {
    sum += int.parse(cleanCpf[i]) * (10 - i);
  }
  int remainder = sum % 11;
  int digit1 = remainder < 2 ? 0 : 11 - remainder;

  if (int.parse(cleanCpf[9]) != digit1) return false;

  sum = 0;
  for (int i = 0; i < 10; i++) {
    sum += int.parse(cleanCpf[i]) * (11 - i);
  }
  remainder = sum % 11;
  int digit2 = remainder < 2 ? 0 : 11 - remainder;

  return int.parse(cleanCpf[10]) == digit2;
}

String _handleAuthError(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'Email inválido.';
    case 'user-disabled':
      return 'Esta conta foi desativada.';
    case 'user-not-found':
      return 'Usuário não encontrado.';
    case 'wrong-password':
      return 'Senha incorreta.';
    case 'email-already-in-use':
      return 'Este email já está em uso.';
    case 'operation-not-allowed':
      return 'Método de autenticação não habilitado. Entre em contato com o suporte.';
    case 'weak-password':
      return 'A senha é muito fraca. Use pelo menos 6 caracteres.';
    case 'invalid-credential':
      return 'Credenciais inválidas. Verifique seu email e senha.';
    case 'invalid-verification-code':
      return 'Código de verificação inválido.';
    case 'invalid-verification-id':
      return 'ID de verificação inválido.';
    case 'network-request-failed':
      return 'Erro de conexão. Verifique sua internet.';
    default:
      return 'Ocorreu um erro: ${e.message ?? "Erro desconhecido"}';
  }
}
