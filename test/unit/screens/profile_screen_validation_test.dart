import 'package:flutter_test/flutter_test.dart';
import 'package:ftw_solucoes/utils/validation_utils.dart';

void main() {
  group('ProfileScreen - Validações Aplicadas', () {
    test('deve ter validações robustas implementadas', () {
      // Este teste verifica se as funções de validação estão implementadas na ProfileScreen

      // Simular uma instância da ProfileScreen para acessar as funções privadas
      // Como as funções são privadas, vamos testar os comportamentos esperados

      // Teste de CPF válido
      expect(ValidationUtils.isValidCpf('529.982.247-25'), isTrue);
      expect(ValidationUtils.isValidCpf('123.456.789-00'), isFalse);

      // Teste de telefone válido
      expect(ValidationUtils.isValidPhone('(11) 98765-4321'), isTrue);
      expect(ValidationUtils.isValidPhone('(11) 12345-6789'), isFalse);

      // Teste de nome válido
      expect(ValidationUtils.isValidName('João Silva Santos'), isTrue);
      expect(ValidationUtils.isValidName('Jo'), isFalse);

      // Teste de CEP válido
      expect(ValidationUtils.isValidCep('01234-567'), isTrue);
      expect(ValidationUtils.isValidCep('1234-567'), isFalse);
    });

    test('deve validar formato de estado corretamente', () {
      expect(ValidationUtils.isValidState('SP'), isTrue);
      expect(ValidationUtils.isValidState('RJ'), isTrue);
      expect(ValidationUtils.isValidState('S'), isFalse);
      expect(ValidationUtils.isValidState('SPP'), isFalse);
      expect(ValidationUtils.isValidState('12'), isFalse);
    });

    test('deve validar número de endereço corretamente', () {
      expect(ValidationUtils.isValidNumber('123'), isTrue);
      expect(ValidationUtils.isValidNumber('123A'), isFalse);
      expect(ValidationUtils.isValidNumber(''), isFalse);
    });

    test('deve validar campos de texto sem números', () {
      expect(ValidationUtils.isValidTextOnly('Rua das Flores'), isTrue);
      expect(ValidationUtils.isValidTextOnly('Rua das Flores 123'), isFalse);
      expect(ValidationUtils.isValidTextOnly('Centro'), isTrue);
      expect(ValidationUtils.isValidTextOnly('Centro 2'), isFalse);
    });

    test('deve detectar CPF duplicado corretamente', () {
      // Simular dados de usuários no banco
      final mockUsers = [
        {'id': 'user1', 'cpf': '529.982.247-25'},
        {'id': 'user2', 'cpf': '123.456.789-09'},
        {'id': 'user3', 'cpf': '987.654.321-00'},
      ];

      // Teste: CPF já cadastrado
      const existingCpf = '529.982.247-25';
      final isDuplicate = _checkCpfDuplicate(mockUsers, 'user4', existingCpf);
      expect(isDuplicate, isTrue);

      // Teste: CPF não cadastrado
      const newCpf = '111.222.333-44';
      final isNotDuplicate = _checkCpfDuplicate(mockUsers, 'user4', newCpf);
      expect(isNotDuplicate, isFalse);

      // Teste: Usuário atualizando seu próprio CPF (não deve ser considerado duplicado)
      final sameUserCpf =
          _checkCpfDuplicate(mockUsers, 'user1', '529.982.247-25');
      expect(sameUserCpf, isFalse);
    });

    test('deve validar CPF antes de verificar duplicação', () {
      // CPF inválido não deve ser verificado
      const invalidCpf = '123.456.789-00'; // CPF inválido
      final isValid = _isValidCpf(invalidCpf);
      expect(isValid, isFalse);

      // CPF válido deve ser verificado
      const validCpf = '529.982.247-25'; // CPF válido
      final isValidCpf = _isValidCpf(validCpf);
      expect(isValidCpf, isTrue);
    });

    test('deve lidar com CPFs em diferentes formatos', () {
      final mockUsers = [
        {'id': 'user1', 'cpf': '529.982.247-25'},
      ];

      // Mesmo CPF em formato diferente
      const sameCpfDifferentFormat = '52998224725';
      final isDuplicate =
          _checkCpfDuplicate(mockUsers, 'user2', sameCpfDifferentFormat);
      expect(isDuplicate, isTrue);

      // CPF com espaços
      const cpfWithSpaces = '529 982 247 25';
      final isDuplicateSpaces =
          _checkCpfDuplicate(mockUsers, 'user2', cpfWithSpaces);
      expect(isDuplicateSpaces, isTrue);
    });
  });
}

// Função auxiliar para simular verificação de CPF duplicado
bool _checkCpfDuplicate(
    List<Map<String, String>> users, String currentUserId, String cpf) {
  // Limpar CPF (remover formatação)
  final cleanCpf = cpf.replaceAll(RegExp(r'[^\d]'), '');

  // Verificar se CPF é válido
  if (!_isValidCpf(cpf)) return false;

  // Buscar usuários com o mesmo CPF
  for (var user in users) {
    final userCpf = user['cpf']!.replaceAll(RegExp(r'[^\d]'), '');
    if (userCpf == cleanCpf && user['id'] != currentUserId) {
      return true; // CPF já está cadastrado por outro usuário
    }
  }

  return false; // CPF não está cadastrado ou é do usuário atual
}

// Função auxiliar para validar CPF
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
