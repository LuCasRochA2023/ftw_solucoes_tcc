import 'package:flutter_test/flutter_test.dart';
import 'package:ftw_solucoes/utils/validation_utils.dart';

void main() {
  group('AuthService - Lógica de Validação', () {
    group('Validação de Nome', () {
      test('deve aceitar nome válido', () {
        // Arrange
        const nomeValido = 'João Silva Santos';

        // Act
        final resultado = ValidationUtils.isValidName(nomeValido);

        // Assert
        expect(resultado, isTrue);
      });

      test('deve rejeitar nome com uma palavra apenas', () {
        // Arrange
        const nomeInvalido = 'João';

        // Act
        final resultado = ValidationUtils.isValidName(nomeInvalido);

        // Assert
        expect(resultado, isFalse);
      });

      test('deve rejeitar nome com números', () {
        // Arrange
        const nomeInvalido = 'João123 Silva';

        // Act
        final resultado = ValidationUtils.isValidName(nomeInvalido);

        // Assert
        expect(resultado, isFalse);
      });

      test('deve rejeitar nome vazio', () {
        // Arrange
        const nomeInvalido = '';

        // Act
        final resultado = ValidationUtils.isValidName(nomeInvalido);

        // Assert
        expect(resultado, isFalse);
      });

      test('deve rejeitar nome muito longo', () {
        // Arrange
        const nomeInvalido = 'João Silva Santos de Oliveira Pereira Costa';

        // Act
        final resultado = ValidationUtils.isValidName(nomeInvalido);

        // Assert
        expect(resultado, isFalse);
      });

      test('deve aceitar nome com acentos', () {
        // Arrange
        const nomeValido = 'José da Silva';

        // Act
        final resultado = ValidationUtils.isValidName(nomeValido);

        // Assert
        expect(resultado, isTrue);
      });

      test('deve aceitar nome com cedilha', () {
        // Arrange
        const nomeValido = 'Francisco Conceição';

        // Act
        final resultado = ValidationUtils.isValidName(nomeValido);

        // Assert
        expect(resultado, isTrue);
      });
    });

    group('Validação de Email', () {
      test('deve aceitar email válido', () {
        // Arrange
        const emailValido = 'usuario@exemplo.com';
        final regex =
            RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

        // Act
        final resultado = regex.hasMatch(emailValido);

        // Assert
        expect(resultado, isTrue);
      });

      test('deve rejeitar email sem @', () {
        // Arrange
        const emailInvalido = 'usuarioexemplo.com';
        final regex =
            RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

        // Act
        final resultado = regex.hasMatch(emailInvalido);

        // Assert
        expect(resultado, isFalse);
      });

      test('deve rejeitar email sem domínio', () {
        // Arrange
        const emailInvalido = 'usuario@';
        final regex =
            RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

        // Act
        final resultado = regex.hasMatch(emailInvalido);

        // Assert
        expect(resultado, isFalse);
      });

      test('deve rejeitar email sem extensão', () {
        // Arrange
        const emailInvalido = 'usuario@exemplo';
        final regex =
            RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

        // Act
        final resultado = regex.hasMatch(emailInvalido);

        // Assert
        expect(resultado, isFalse);
      });

      test('deve aceitar email com subdomínio', () {
        // Arrange
        const emailValido = 'usuario@mail.exemplo.com';
        final regex =
            RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

        // Act
        final resultado = regex.hasMatch(emailValido);

        // Assert
        expect(resultado, isTrue);
      });

      test('deve aceitar email com números', () {
        // Arrange
        const emailValido = 'usuario123@exemplo.com';
        final regex =
            RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

        // Act
        final resultado = regex.hasMatch(emailValido);

        // Assert
        expect(resultado, isTrue);
      });

      test('deve aceitar email com caracteres especiais', () {
        // Arrange
        const emailValido = 'usuario.teste+tag@exemplo-site.com';
        final regex =
            RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

        // Act
        final resultado = regex.hasMatch(emailValido);

        // Assert
        expect(resultado, isTrue);
      });
    });

    group('Validação de Senha', () {
      test('deve aceitar senha válida', () {
        // Arrange
        const senhaValida = 'Senha123';

        // Act
        final temTamanhoMinimo = senhaValida.length >= 8;
        final temMaiuscula = RegExp(r'[A-Z]').hasMatch(senhaValida);
        final temMinuscula = RegExp(r'[a-z]').hasMatch(senhaValida);
        final temNumero = RegExp(r'\d').hasMatch(senhaValida);

        // Assert
        expect(temTamanhoMinimo, isTrue);
        expect(temMaiuscula, isTrue);
        expect(temMinuscula, isTrue);
        expect(temNumero, isTrue);
      });

      test('deve rejeitar senha muito curta', () {
        // Arrange
        const senhaInvalida = 'Sen123';

        // Act
        final temTamanhoMinimo = senhaInvalida.length >= 8;

        // Assert
        expect(temTamanhoMinimo, isFalse);
      });

      test('deve rejeitar senha sem maiúscula', () {
        // Arrange
        const senhaInvalida = 'senha123';

        // Act
        final temMaiuscula = RegExp(r'[A-Z]').hasMatch(senhaInvalida);

        // Assert
        expect(temMaiuscula, isFalse);
      });

      test('deve rejeitar senha sem minúscula', () {
        // Arrange
        const senhaInvalida = 'SENHA123';

        // Act
        final temMinuscula = RegExp(r'[a-z]').hasMatch(senhaInvalida);

        // Assert
        expect(temMinuscula, isFalse);
      });

      test('deve rejeitar senha sem número', () {
        // Arrange
        const senhaInvalida = 'SenhaForte';

        // Act
        final temNumero = RegExp(r'\d').hasMatch(senhaInvalida);

        // Assert
        expect(temNumero, isFalse);
      });

      test('deve aceitar senha com caracteres especiais', () {
        // Arrange
        const senhaValida = 'Senha123!@#';

        // Act
        final temTamanhoMinimo = senhaValida.length >= 8;
        final temMaiuscula = RegExp(r'[A-Z]').hasMatch(senhaValida);
        final temMinuscula = RegExp(r'[a-z]').hasMatch(senhaValida);
        final temNumero = RegExp(r'\d').hasMatch(senhaValida);

        // Assert
        expect(temTamanhoMinimo, isTrue);
        expect(temMaiuscula, isTrue);
        expect(temMinuscula, isTrue);
        expect(temNumero, isTrue);
      });

      test('deve validar força da senha com regex completo', () {
        // Arrange
        const senhaValida = 'MinhaSenh@123';
        final regexCompleto = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)');

        // Act
        final temTamanhoMinimo = senhaValida.length >= 8;
        final temTodosRequisitos = regexCompleto.hasMatch(senhaValida);

        // Assert
        expect(temTamanhoMinimo, isTrue);
        expect(temTodosRequisitos, isTrue);
      });
    });

    group('Validação Completa de Cadastro', () {
      test('deve aceitar dados válidos para cadastro', () {
        // Arrange
        const nome = 'João Silva Santos';
        const email = 'joao.silva@exemplo.com';
        const senha = 'MinhaSenh@123';

        // Act
        final nomeValido = ValidationUtils.isValidName(nome);
        final emailValido =
            RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                .hasMatch(email);
        final senhaValida = senha.length >= 8 &&
            RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(senha);

        // Assert
        expect(nomeValido, isTrue);
        expect(emailValido, isTrue);
        expect(senhaValida, isTrue);
      });

      test('deve rejeitar dados inválidos para cadastro', () {
        // Arrange
        const nome = 'João'; // Apenas um nome
        const email = 'email_invalido'; // Sem @
        const senha = '123'; // Muito curta

        // Act
        final nomeValido = ValidationUtils.isValidName(nome);
        final emailValido =
            RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                .hasMatch(email);
        final senhaValida = senha.length >= 8 &&
            RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(senha);

        // Assert
        expect(nomeValido, isFalse);
        expect(emailValido, isFalse);
        expect(senhaValida, isFalse);
      });

      test('deve validar dados mistos para cadastro', () {
        // Arrange
        const nome = 'Maria Silva'; // Válido
        const email = 'maria@exemplo'; // Inválido (sem extensão)
        const senha = 'MinhaSenh@123'; // Válido

        // Act
        final nomeValido = ValidationUtils.isValidName(nome);
        final emailValido =
            RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                .hasMatch(email);
        final senhaValida = senha.length >= 8 &&
            RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(senha);

        // Assert
        expect(nomeValido, isTrue);
        expect(emailValido, isFalse);
        expect(senhaValida, isTrue);
      });

      test('deve validar cenário completo de registro', () {
        // Arrange
        const dadosValidos = {
          'nome': 'Ana Paula Silva',
          'email': 'ana.paula@exemplo.com.br',
          'senha': 'MinhaSenh@2024',
        };

        // Act
        final nomeValido = ValidationUtils.isValidName(dadosValidos['nome']!);
        final emailValido =
            RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                .hasMatch(dadosValidos['email']!);
        final senhaValida = dadosValidos['senha']!.length >= 8 &&
            RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)')
                .hasMatch(dadosValidos['senha']!);
        final todosValidos = nomeValido && emailValido && senhaValida;

        // Assert
        expect(nomeValido, isTrue);
        expect(emailValido, isTrue);
        expect(senhaValida, isTrue);
        expect(todosValidos, isTrue);
      });
    });

    group('Casos de Borda', () {
      test('deve lidar com strings nulas e vazias', () {
        // Arrange
        const nomeVazio = '';
        const emailVazio = '';
        const senhaVazia = '';

        // Act
        final nomeValido = nomeVazio.isNotEmpty
            ? ValidationUtils.isValidName(nomeVazio)
            : false;
        final emailValido = emailVazio.isNotEmpty
            ? RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                .hasMatch(emailVazio)
            : false;
        final senhaValida = senhaVazia.length >= 8 &&
            RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(senhaVazia);

        // Assert
        expect(nomeValido, isFalse);
        expect(emailValido, isFalse);
        expect(senhaValida, isFalse);
      });

      test('deve lidar com espaços em branco', () {
        // Arrange
        const nomeComEspacos = '   João Silva   ';
        const emailComEspacos = '  joao@exemplo.com  ';
        const senhaComEspacos = '  MinhaSenh@123  ';

        // Act - Simulando trim que seria feito na aplicação
        final nomeLimpo = nomeComEspacos.trim();
        final emailLimpo = emailComEspacos.trim();
        final senhaLimpa = senhaComEspacos.trim();

        final nomeValido = ValidationUtils.isValidName(nomeLimpo);
        final emailValido =
            RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                .hasMatch(emailLimpo);
        final senhaValida = senhaLimpa.length >= 8 &&
            RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(senhaLimpa);

        // Assert
        expect(nomeValido, isTrue);
        expect(emailValido, isTrue);
        expect(senhaValida, isTrue);
      });

      test('deve validar limites de tamanho', () {
        // Arrange
        const nomeMaximo = 'João Silva Santos Oliveira'; // No limite
        const emailLongo =
            'usuario.com.nome.muito.longo@dominio.muito.longo.exemplo.com';
        const senhaMinima = 'Senha123'; // 8 caracteres

        // Act
        final nomeValido = ValidationUtils.isValidName(nomeMaximo);
        final emailValido =
            RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                .hasMatch(emailLongo);
        final senhaValida = senhaMinima.length >= 8 &&
            RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(senhaMinima);

        // Assert
        expect(nomeValido, isTrue);
        expect(emailValido, isTrue);
        expect(senhaValida, isTrue);
      });
    });
  });
}
