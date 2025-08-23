class ValidationUtils {
  /// Valida CPF com dígitos verificadores
  static bool isValidCpf(String cpf) {
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

  /// Valida telefone com DDD e formato
  static bool isValidPhone(String phone) {
    // Remove caracteres não numéricos
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');

    // Telefone deve ter 10 ou 11 dígitos (com DDD)
    if (cleanPhone.length < 10 || cleanPhone.length > 11) return false;

    // DDD deve ser válido (11-99)
    final ddd = int.parse(cleanPhone.substring(0, 2));
    if (ddd < 11 || ddd > 99) return false;

    // Para telefone com 11 dígitos, deve ser celular (9 no início)
    if (cleanPhone.length == 11 && cleanPhone[2] != '9') return false;

    return true;
  }

  /// Valida nome completo
  static bool isValidName(String name) {
    // Nome deve ter entre 3 e 40 caracteres
    if (name.length < 3 || name.length > 40) return false;

    // Nome deve conter apenas letras, espaços e acentos
    if (!RegExp(r'^[a-zA-ZÀ-ÿ\s]+$').hasMatch(name)) return false;

    // Nome deve ter pelo menos duas palavras
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length < 2) return false;

    return true;
  }

  /// Valida CEP
  static bool isValidCep(String cep) {
    // Remove caracteres não numéricos
    final cleanCep = cep.replaceAll(RegExp(r'[^\d]'), '');

    // CEP deve ter 8 dígitos
    if (cleanCep.length != 8) return false;

    return true;
  }

  /// Valida estado (2 letras)
  static bool isValidState(String state) {
    if (state.length != 2) return false;
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(state.toUpperCase())) return false;
    return true;
  }

  /// Valida número (apenas dígitos)
  static bool isValidNumber(String number) {
    if (number.isEmpty) return false;
    if (!RegExp(r'^[0-9]+$').hasMatch(number)) return false;
    return true;
  }

  /// Valida texto sem números
  static bool isValidTextOnly(String text) {
    if (RegExp(r'[0-9]').hasMatch(text)) return false;
    return true;
  }

  /// Formata CPF
  static String formatCpf(String cpf) {
    final cleanCpf = cpf.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanCpf.length != 11) return cpf;

    return '${cleanCpf.substring(0, 3)}.${cleanCpf.substring(3, 6)}.${cleanCpf.substring(6, 9)}-${cleanCpf.substring(9)}';
  }

  /// Formata telefone
  static String formatPhone(String phone) {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.length == 11) {
      return '(${cleanPhone.substring(0, 2)}) ${cleanPhone.substring(2, 7)}-${cleanPhone.substring(7)}';
    } else if (cleanPhone.length == 10) {
      return '(${cleanPhone.substring(0, 2)}) ${cleanPhone.substring(2, 6)}-${cleanPhone.substring(6)}';
    }
    return phone;
  }

  /// Formata CEP
  static String formatCep(String cep) {
    final cleanCep = cep.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanCep.length != 8) return cep;

    return '${cleanCep.substring(0, 5)}-${cleanCep.substring(5)}';
  }
}
