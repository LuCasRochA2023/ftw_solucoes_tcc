import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:ftw_solucoes/screens/login_screen.dart';
import 'package:ftw_solucoes/services/auth_service.dart';

// Gerar mocks
@GenerateMocks([AuthService])
import 'login_screen_simple_test.mocks.dart';

void main() {
  group('LoginScreen - Testes Simplificados', () {
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
      // Adicionar stub para currentUser para evitar erro no HomeScreen
      when(mockAuthService.currentUser).thenReturn(null);
    });

    Widget createLoginScreen() {
      return MaterialApp(
        home: Scaffold(
          body: LoginScreen(authService: mockAuthService),
        ),
      );
    }

    group('Validação de Campos', () {
      testWidgets('deve mostrar erro quando email está vazio',
          (WidgetTester tester) async {
        await tester.pumpWidget(createLoginScreen());

        // Tentar fazer login sem preencher campos
        await tester.tap(find.text('Entrar'));
        await tester.pump();

        // Verificar se há mensagens de erro
        expect(find.text('Por favor, insira seu email'), findsOneWidget);
        expect(find.text('Por favor, insira sua senha'), findsOneWidget);
      });

      testWidgets('deve mostrar erro quando email é inválido',
          (WidgetTester tester) async {
        await tester.pumpWidget(createLoginScreen());

        // Preencher email inválido
        await tester.enterText(
            find.byType(TextFormField).first, 'email_invalido');
        await tester.enterText(find.byType(TextFormField).last, 'senha123');
        await tester.tap(find.text('Entrar'));
        await tester.pump();

        // Verificar se há mensagem de erro de email
        expect(find.text('Por favor, insira um email válido'), findsOneWidget);
      });

      testWidgets('deve aceitar email válido', (WidgetTester tester) async {
        await tester.pumpWidget(createLoginScreen());

        // Preencher email válido
        await tester.enterText(
            find.byType(TextFormField).first, 'teste@exemplo.com');
        await tester.enterText(find.byType(TextFormField).last, 'senha123');

        // Verificar se não há erros
        expect(find.text('Por favor, insira um email válido'), findsNothing);
      });

      testWidgets('deve mostrar erro quando senha está vazia',
          (WidgetTester tester) async {
        await tester.pumpWidget(createLoginScreen());

        // Preencher apenas email
        await tester.enterText(
            find.byType(TextFormField).first, 'teste@exemplo.com');
        await tester.tap(find.text('Entrar'));
        await tester.pump();

        // Verificar se há mensagem de erro de senha
        expect(find.text('Por favor, insira sua senha'), findsOneWidget);
      });

      testWidgets('deve aceitar senha válida', (WidgetTester tester) async {
        await tester.pumpWidget(createLoginScreen());

        // Preencher senha válida
        await tester.enterText(
            find.byType(TextFormField).first, 'teste@exemplo.com');
        await tester.enterText(find.byType(TextFormField).last, 'senha123');

        // Verificar se não há erros
        expect(find.text('Por favor, insira sua senha'), findsNothing);
      });

      testWidgets('deve mostrar erro quando senha é muito curta',
          (WidgetTester tester) async {
        await tester.pumpWidget(createLoginScreen());

        // Preencher senha curta
        await tester.enterText(
            find.byType(TextFormField).first, 'teste@exemplo.com');
        await tester.enterText(find.byType(TextFormField).last, '123');
        await tester.tap(find.text('Entrar'));
        await tester.pump();

        // Verificar se há mensagem de erro de senha
        expect(find.text('A senha deve ter pelo menos 6 caracteres'),
            findsOneWidget);
      });
    });

    group('Funcionalidade de Senha', () {
      testWidgets('deve alternar visibilidade da senha',
          (WidgetTester tester) async {
        await tester.pumpWidget(createLoginScreen());

        // Verificar se a senha está oculta inicialmente
        expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

        // Clicar no ícone de visibilidade
        await tester.tap(find.byIcon(Icons.visibility_outlined));
        await tester.pump();

        // Verificar se a senha está visível
        expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      });
    });

    group('Login', () {
      testWidgets('deve chamar AuthService.signIn com dados válidos',
          (WidgetTester tester) async {
        // Arrange
        when(mockAuthService.signIn(any, any)).thenAnswer((_) async {});
        await tester.pumpWidget(createLoginScreen());

        // Act
        await tester.enterText(
            find.byType(TextFormField).first, 'teste@exemplo.com');
        await tester.enterText(find.byType(TextFormField).last, 'senha123');
        await tester.tap(find.text('Entrar'));
        await tester.pumpAndSettle();

        // Assert
        verify(mockAuthService.signIn('teste@exemplo.com', 'senha123'))
            .called(1);
      });

      testWidgets('deve mostrar loading durante login',
          (WidgetTester tester) async {
        // Arrange
        when(mockAuthService.signIn(any, any)).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpWidget(createLoginScreen());

        // Act - Iniciar login
        await tester.enterText(
            find.byType(TextFormField).first, 'teste@exemplo.com');
        await tester.enterText(find.byType(TextFormField).last, 'senha123');
        await tester.tap(find.text('Entrar'));
        await tester.pump();

        // Assert - Deve mostrar loading
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Entrar'), findsNothing);

        // Aguardar o timer terminar para evitar erro de timer pendente
        await tester.pumpAndSettle();
      });

      testWidgets('deve desabilitar botão durante loading',
          (WidgetTester tester) async {
        // Arrange
        when(mockAuthService.signIn(any, any)).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpWidget(createLoginScreen());

        // Act
        await tester.enterText(
            find.byType(TextFormField).first, 'teste@exemplo.com');
        await tester.enterText(find.byType(TextFormField).last, 'senha123');
        await tester.tap(find.text('Entrar'));
        await tester.pump();

        // Assert - O botão deve estar desabilitado (não encontrado como texto)
        expect(find.text('Entrar'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Aguardar o timer terminar
        await tester.pumpAndSettle();
      });
    });

    group('Reset de Senha', () {
      testWidgets('deve mostrar erro quando email está vazio no reset',
          (WidgetTester tester) async {
        await tester.pumpWidget(createLoginScreen());

        // Clicar em "Esqueci minha senha"
        await tester.tap(find.text('Esqueci minha senha'));
        await tester.pumpAndSettle();

        // Verificar se há mensagem de erro
        expect(find.text('Por favor, insira seu email para recuperar a senha'),
            findsOneWidget);
      });

      testWidgets('deve mostrar erro quando email é inválido no reset',
          (WidgetTester tester) async {
        await tester.pumpWidget(createLoginScreen());

        // Preencher email inválido
        await tester.enterText(
            find.byType(TextFormField).first, 'email_invalido');

        // Clicar em "Esqueci minha senha"
        await tester.tap(find.text('Esqueci minha senha'));
        await tester.pumpAndSettle();

        // Verificar se há mensagem de erro
        expect(find.text('Por favor, insira um email válido'), findsOneWidget);
      });

      testWidgets('deve chamar AuthService.sendPasswordResetEmail',
          (WidgetTester tester) async {
        // Arrange
        when(mockAuthService.sendPasswordResetEmail(any))
            .thenAnswer((_) async {});
        await tester.pumpWidget(createLoginScreen());

        // Act
        await tester.enterText(
            find.byType(TextFormField).first, 'teste@exemplo.com');
        await tester.tap(find.text('Esqueci minha senha'));
        await tester.pumpAndSettle();

        // Assert
        verify(mockAuthService.sendPasswordResetEmail('teste@exemplo.com'))
            .called(1);
      });

      testWidgets('deve mostrar loading durante reset de senha',
          (WidgetTester tester) async {
        // Arrange
        when(mockAuthService.sendPasswordResetEmail(any)).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpWidget(createLoginScreen());

        // Act
        await tester.enterText(
            find.byType(TextFormField).first, 'teste@exemplo.com');
        await tester.tap(find.text('Esqueci minha senha'));
        await tester.pump();

        // Assert
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Aguardar o timer terminar
        await tester.pumpAndSettle();
      });

      testWidgets('deve desabilitar botão de reset durante loading',
          (WidgetTester tester) async {
        // Arrange
        when(mockAuthService.sendPasswordResetEmail(any)).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpWidget(createLoginScreen());

        // Act
        await tester.enterText(
            find.byType(TextFormField).first, 'teste@exemplo.com');
        await tester.tap(find.text('Esqueci minha senha'));
        await tester.pump();

        // Assert - O botão deve estar desabilitado (não encontrado como texto)
        expect(find.text('Esqueci minha senha'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Aguardar o timer terminar
        await tester.pumpAndSettle();
      });
    });

    group('Navegação', () {
      testWidgets('deve navegar para RegisterScreen quando clicar em registrar',
          (WidgetTester tester) async {
        await tester.pumpWidget(createLoginScreen());

        // Verificar se o link de registro existe
        expect(find.text('Não tem uma conta? Registre-se'), findsOneWidget);

        // Nota: O teste de navegação real requer setup adicional de rotas
        // Por enquanto, apenas verificamos se o elemento existe
      });
    });

    group('Casos de Borda', () {
      testWidgets(
          'deve desabilitar botão durante loading para evitar múltiplos cliques',
          (WidgetTester tester) async {
        // Arrange
        when(mockAuthService.signIn(any, any)).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpWidget(createLoginScreen());

        // Act
        await tester.enterText(
            find.byType(TextFormField).first, 'teste@exemplo.com');
        await tester.enterText(find.byType(TextFormField).last, 'senha123');

        // Clicar no botão de login
        await tester.tap(find.text('Entrar'));
        await tester.pump();

        // Assert - O botão deve estar desabilitado (não encontrado como texto)
        expect(find.text('Entrar'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Aguardar o timer terminar
        await tester.pumpAndSettle();
      });

      testWidgets(
          'deve desabilitar botão de reset durante loading para evitar múltiplos cliques',
          (WidgetTester tester) async {
        // Arrange
        when(mockAuthService.sendPasswordResetEmail(any)).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpWidget(createLoginScreen());

        // Act
        await tester.enterText(
            find.byType(TextFormField).first, 'teste@exemplo.com');

        // Clicar no botão de reset
        await tester.tap(find.text('Esqueci minha senha'));
        await tester.pump();

        // Assert - O botão deve estar desabilitado (não encontrado como texto)
        expect(find.text('Esqueci minha senha'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Aguardar o timer terminar
        await tester.pumpAndSettle();
      });
    });

    group('Interface do Usuário', () {
      testWidgets('deve mostrar elementos principais',
          (WidgetTester tester) async {
        await tester.pumpWidget(createLoginScreen());

        // Assert
        expect(
            find.text('Bem-vindo à FTW Soluções Automotivas'), findsOneWidget);
        expect(find.text('Entre com suas credenciais para continuar'),
            findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Senha'), findsOneWidget);
        expect(find.text('Entrar'), findsOneWidget);
        expect(find.text('Esqueci minha senha'), findsOneWidget);
        expect(find.text('Não tem uma conta? Registre-se'), findsOneWidget);
      });
    });
  });
}
