import 'package:firebase_auth/firebase_auth.dart';

class ErrorHandler {
  static String getFriendlyErrorMessage(dynamic error) {
    if (error is String) {
      // Se já é uma string, verifica se contém mensagens específicas
      if (error.contains('Erro ao fazer login:')) {
        return _extractLoginError(error);
      }
      if (error.contains('Erro ao criar conta:')) {
        return _extractRegisterError(error);
      }
      if (error.contains('Failed to create user:')) {
        return 'Erro interno do sistema. Tente novamente em alguns minutos.';
      }
      if (error.contains('Failed to reset password:')) {
        return 'Erro interno do sistema. Tente novamente em alguns minutos.';
      }
      // Se for uma string simples, retorna ela mesma
      return error;
    }

    if (error is FirebaseAuthException) {
      return _handleFirebaseAuthError(error);
    }

    // Para outros tipos de erro
    return 'Ocorreu um erro inesperado. Tente novamente.';
  }

  static String _extractLoginError(String error) {
    // Remove o prefixo "Erro ao fazer login: " e trata as exceções do Firebase
    final cleanError = error.replaceFirst('Erro ao fazer login: ', '');

    if (cleanError.contains('user-not-found')) {
      return 'Email não encontrado. Verifique se o email está correto.';
    }
    if (cleanError.contains('wrong-password')) {
      return 'Senha incorreta. Verifique sua senha.';
    }
    if (cleanError.contains('invalid-email')) {
      return 'Email inválido. Verifique o formato do email.';
    }
    if (cleanError.contains('user-disabled')) {
      return 'Esta conta foi desativada. Entre em contato com o suporte.';
    }
    if (cleanError.contains('too-many-requests')) {
      return 'Muitas tentativas de login. Aguarde alguns minutos antes de tentar novamente.';
    }
    if (cleanError.contains('network-request-failed')) {
      return 'Erro de conexão. Verifique sua internet e tente novamente.';
    }
    if (cleanError.contains('invalid-credential')) {
      return 'Email ou senha incorretos. Verifique suas credenciais.';
    }

    return 'Erro ao fazer login. Verifique suas credenciais e tente novamente.';
  }

  static String _extractRegisterError(String error) {
    // Remove o prefixo "Erro ao criar conta: " e trata as exceções do Firebase
    final cleanError = error.replaceFirst('Erro ao criar conta: ', '');

    if (cleanError.contains('email-already-in-use')) {
      return 'Este email já está sendo usado por outra conta.';
    }
    if (cleanError.contains('weak-password')) {
      return 'A senha é muito fraca. Use pelo menos 8 caracteres com letras maiúsculas, minúsculas e números.';
    }
    if (cleanError.contains('invalid-email')) {
      return 'Email inválido. Verifique o formato do email.';
    }
    if (cleanError.contains('operation-not-allowed')) {
      return 'Registro de novos usuários está temporariamente desabilitado. Entre em contato com o suporte.';
    }
    if (cleanError.contains('network-request-failed')) {
      return 'Erro de conexão. Verifique sua internet e tente novamente.';
    }

    return 'Erro ao criar conta. Tente novamente ou entre em contato com o suporte.';
  }

  static String _handleFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email inválido. Verifique o formato do email.';
      case 'user-disabled':
        return 'Esta conta foi desativada. Entre em contato com o suporte.';
      case 'user-not-found':
        return 'Email não encontrado. Verifique se o email está correto.';
      case 'wrong-password':
        return 'Senha incorreta. Verifique sua senha.';
      case 'email-already-in-use':
        return 'Este email já está sendo usado por outra conta.';
      case 'operation-not-allowed':
        return 'Método de autenticação não habilitado. Entre em contato com o suporte.';
      case 'weak-password':
        return 'A senha é muito fraca. Use pelo menos 8 caracteres com letras maiúsculas, minúsculas e números.';
      case 'invalid-credential':
        return 'Email ou senha incorretos. Verifique suas credenciais.';
      case 'invalid-verification-code':
        return 'Código de verificação inválido.';
      case 'invalid-verification-id':
        return 'ID de verificação inválido.';
      case 'network-request-failed':
        return 'Erro de conexão. Verifique sua internet e tente novamente.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde alguns minutos antes de tentar novamente.';
      case 'requires-recent-login':
        return 'Por segurança, faça login novamente antes de continuar.';
      default:
        return 'Ocorreu um erro inesperado. Tente novamente ou entre em contato com o suporte.';
    }
  }

  static String getPasswordResetErrorMessage(dynamic error) {
    if (error is String) {
      if (error.contains('Failed to reset password:')) {
        return 'Erro interno do sistema. Tente novamente em alguns minutos.';
      }
      // Remove prefixos comuns
      final cleanError = error.replaceFirst('Failed to reset password: ', '');
      return _handlePasswordResetError(cleanError);
    }

    if (error is FirebaseAuthException) {
      return _handlePasswordResetError(error.code);
    }

    return 'Erro ao enviar email de recuperação. Tente novamente.';
  }

  static String _handlePasswordResetError(String errorCode) {
    switch (errorCode) {
      case 'invalid-email':
        return 'Email inválido. Verifique o formato do email.';
      case 'user-not-found':
        return 'Email não encontrado. Verifique se o email está correto.';
      case 'user-disabled':
        return 'Esta conta foi desativada. Entre em contato com o suporte.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde alguns minutos antes de tentar novamente.';
      case 'network-request-failed':
        return 'Erro de conexão. Verifique sua internet e tente novamente.';
      default:
        return 'Erro ao enviar email de recuperação. Tente novamente.';
    }
  }
}
