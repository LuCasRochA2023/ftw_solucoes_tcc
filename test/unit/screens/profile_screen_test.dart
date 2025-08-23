import 'package:flutter_test/flutter_test.dart';
import 'package:ftw_solucoes/utils/validation_utils.dart';

void main() {
  group('ProfileScreen - Validação de Dados', () {
    group('Validação de CPF', () {
      test('deve validar CPF com formato correto', () {
        // Arrange
        const cpfValido = '529.982.247-25';
        const cpfInvalido = '123.456.789-00';

        // Act & Assert
        expect(ValidationUtils.isValidCpf(cpfValido), isTrue);
        expect(ValidationUtils.isValidCpf(cpfInvalido), isFalse);
      });

      test('deve validar CPF sem formatação', () {
        // Arrange
        const cpfValido = '52998224725';
        const cpfInvalido = '12345678900';

        // Act & Assert
        expect(ValidationUtils.isValidCpf(cpfValido), isTrue);
        expect(ValidationUtils.isValidCpf(cpfInvalido), isFalse);
      });

      test('deve rejeitar CPF com todos os dígitos iguais', () {
        // Arrange
        const cpfInvalido = '111.111.111-11';

        // Act & Assert
        expect(ValidationUtils.isValidCpf(cpfInvalido), isFalse);
      });

      test('deve rejeitar CPF com menos de 11 dígitos', () {
        // Arrange
        const cpfInvalido = '123.456.789';

        // Act & Assert
        expect(ValidationUtils.isValidCpf(cpfInvalido), isFalse);
      });
    });

    group('Validação de Telefone', () {
      test('deve validar telefone com formato correto', () {
        // Arrange
        const telefoneValido = '(11) 98765-4321';
        const telefoneInvalido =
            '(11) 12345-6789'; // Telefone com 9 dígitos (inválido)

        // Act & Assert
        expect(ValidationUtils.isValidPhone(telefoneValido), isTrue);
        expect(ValidationUtils.isValidPhone(telefoneInvalido), isFalse);
      });

      test('deve validar telefone sem formatação', () {
        // Arrange
        const telefoneValido = '11987654321';
        const telefoneInvalido = '119876543'; // Muito curto

        // Act & Assert
        expect(ValidationUtils.isValidPhone(telefoneValido), isTrue);
        expect(ValidationUtils.isValidPhone(telefoneInvalido), isFalse);
      });

      test('deve rejeitar telefone com DDD inválido', () {
        // Arrange
        const telefoneInvalido = '(00) 98765-4321';

        // Act & Assert
        expect(ValidationUtils.isValidPhone(telefoneInvalido), isFalse);
      });
    });

    group('Validação de CEP', () {
      test('deve validar CEP com formato correto', () {
        // Arrange
        const cepValido = '01234-567';
        const cepInvalido = '1234-567';

        // Act & Assert
        expect(ValidationUtils.isValidCep(cepValido), isTrue);
        expect(ValidationUtils.isValidCep(cepInvalido), isFalse);
      });

      test('deve validar CEP sem formatação', () {
        // Arrange
        const cepValido = '01234567';
        const cepInvalido = '1234567';

        // Act & Assert
        expect(ValidationUtils.isValidCep(cepValido), isTrue);
        expect(ValidationUtils.isValidCep(cepInvalido), isFalse);
      });

      test('deve rejeitar CEP com caracteres não numéricos', () {
        // Arrange
        const cepInvalido = '01234-56a';

        // Act & Assert
        expect(ValidationUtils.isValidCep(cepInvalido), isFalse);
      });
    });

    group('Validação de Nome', () {
      test('deve validar nome com caracteres válidos', () {
        // Arrange
        const nomeValido = 'João Silva Santos';
        const nomeInvalido = 'João123 Silva';

        // Act & Assert
        expect(ValidationUtils.isValidName(nomeValido), isTrue);
        expect(ValidationUtils.isValidName(nomeInvalido), isFalse);
      });

      test('deve rejeitar nome muito curto', () {
        // Arrange
        const nomeInvalido = 'Jo';

        // Act & Assert
        expect(ValidationUtils.isValidName(nomeInvalido), isFalse);
      });

      test('deve rejeitar nome muito longo', () {
        // Arrange
        const nomeInvalido =
            'João Silva Santos Oliveira Costa Pereira Rodrigues da Silva';

        // Act & Assert
        expect(ValidationUtils.isValidName(nomeInvalido), isFalse);
      });

      test('deve aceitar nomes com acentos e espaços', () {
        // Arrange
        const nomeValido = 'João da Silva Santos';

        // Act & Assert
        expect(ValidationUtils.isValidName(nomeValido), isTrue);
      });
    });

    group('Validação de Endereço', () {
      test('deve validar endereço completo', () {
        // Arrange
        final enderecoValido = {
          'cep': '01234-567',
          'street': 'Rua das Flores',
          'number': '123',
          'complement': 'Apto 45',
          'neighborhood': 'Centro',
          'city': 'São Paulo',
          'state': 'SP',
        };

        // Act & Assert
        expect(_isValidAddress(enderecoValido), isTrue);
      });

      test('deve rejeitar endereço sem campos obrigatórios', () {
        // Arrange
        final enderecoInvalido = {
          'cep': '01234-567',
          'street': 'Rua das Flores',
          'number': '', // Campo obrigatório vazio
          'neighborhood': 'Centro',
          'city': 'São Paulo',
          'state': 'SP',
        };

        // Act & Assert
        expect(_isValidAddress(enderecoInvalido), isFalse);
      });

      test('deve validar endereço sem complemento', () {
        // Arrange
        final enderecoValido = {
          'cep': '01234-567',
          'street': 'Rua das Flores',
          'number': '123',
          'complement': '', // Complemento é opcional
          'neighborhood': 'Centro',
          'city': 'São Paulo',
          'state': 'SP',
        };

        // Act & Assert
        expect(_isValidAddress(enderecoValido), isTrue);
      });
    });

    group('Validação de Dados do Perfil', () {
      test('deve validar perfil completo', () {
        // Arrange
        final perfilValido = {
          'name': 'João Silva Santos',
          'cpf': '529.982.247-25',
          'phone': '(11) 98765-4321',
          'address': {
            'cep': '01234-567',
            'street': 'Rua das Flores',
            'number': '123',
            'complement': 'Apto 45',
            'neighborhood': 'Centro',
            'city': 'São Paulo',
            'state': 'SP',
          },
        };

        // Act & Assert
        expect(_isValidProfile(perfilValido), isTrue);
      });

      test('deve rejeitar perfil com dados inválidos', () {
        // Arrange
        final perfilInvalido = {
          'name': 'Jo', // Nome muito curto
          'cpf': '123.456.789-00', // CPF inválido
          'phone': '(11) 12345-6789', // Telefone inválido
          'address': {
            'cep': '01234-567',
            'street': 'Rua das Flores',
            'number': '', // Número vazio
            'neighborhood': 'Centro',
            'city': 'São Paulo',
            'state': 'SP',
          },
        };

        // Act & Assert
        expect(_isValidProfile(perfilInvalido), isFalse);
      });

      test('deve validar perfil sem complemento de endereço', () {
        // Arrange
        final perfilValido = {
          'name': 'João Silva Santos',
          'cpf': '529.982.247-25',
          'phone': '(11) 98765-4321',
          'address': {
            'cep': '01234-567',
            'street': 'Rua das Flores',
            'number': '123',
            'complement': '', // Complemento opcional
            'neighborhood': 'Centro',
            'city': 'São Paulo',
            'state': 'SP',
          },
        };

        // Act & Assert
        expect(_isValidProfile(perfilValido), isTrue);
      });
    });

    group('Formatação de Dados', () {
      test('deve formatar CPF corretamente', () {
        // Arrange
        const cpfSemFormatacao = '52998224725';
        const cpfFormatado = '529.982.247-25';

        // Act
        final resultado = ValidationUtils.formatCpf(cpfSemFormatacao);

        // Assert
        expect(resultado, equals(cpfFormatado));
      });

      test('deve formatar telefone corretamente', () {
        // Arrange
        const telefoneSemFormatacao = '11987654321';
        const telefoneFormatado = '(11) 98765-4321';

        // Act
        final resultado = ValidationUtils.formatPhone(telefoneSemFormatacao);

        // Assert
        expect(resultado, equals(telefoneFormatado));
      });

      test('deve formatar CEP corretamente', () {
        // Arrange
        const cepSemFormatacao = '01234567';
        const cepFormatado = '01234-567';

        // Act
        final resultado = ValidationUtils.formatCep(cepSemFormatacao);

        // Assert
        expect(resultado, equals(cepFormatado));
      });
    });
  });
}

// Funções auxiliares simplificadas usando ValidationUtils

bool _isValidAddress(Map<String, dynamic> address) {
  // Campos obrigatórios
  final requiredFields = [
    'cep',
    'street',
    'number',
    'neighborhood',
    'city',
    'state'
  ];

  for (final field in requiredFields) {
    if (address[field] == null || address[field].toString().trim().isEmpty) {
      return false;
    }
  }

  // Validar CEP
  if (!ValidationUtils.isValidCep(address['cep'])) return false;

  // Validar estado (deve ter 2 letras)
  if (!ValidationUtils.isValidState(address['state'])) return false;

  return true;
}

bool _isValidProfile(Map<String, dynamic> profile) {
  // Validar nome
  if (!ValidationUtils.isValidName(profile['name'])) return false;

  // Validar CPF
  if (!ValidationUtils.isValidCpf(profile['cpf'])) return false;

  // Validar telefone
  if (!ValidationUtils.isValidPhone(profile['phone'])) return false;

  // Validar endereço
  if (!_isValidAddress(profile['address'])) return false;

  return true;
}
