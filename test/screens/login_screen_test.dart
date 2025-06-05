import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftw_solucoes/screens/login_screen.dart';
import 'package:ftw_solucoes/services/auth_service.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MockUserCredential extends Mock implements UserCredential {}

class MockAuthService extends Mock implements AuthService {
  @override
  Future<void> signIn(String email, String password) {
    return Future.value();
  }
}

void main() {
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthService();
  });

  testWidgets('LoginScreen deve mostrar campos de email e senha',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(authService: mockAuthService),
      ),
    );

    // Act
    await tester.pump();

    // Assert
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
  });

  testWidgets('LoginScreen deve mostrar botão de login',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(authService: mockAuthService),
      ),
    );

    // Act
    await tester.pump();

    // Assert
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('LoginScreen deve chamar login ao pressionar botão',
      (WidgetTester tester) async {
    // Arrange
    when(mockAuthService.signIn('test@example.com', 'password123'))
        .thenAnswer((_) => Future<void>.value());

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(authService: mockAuthService),
      ),
    );

    // Act
    await tester.enterText(
        find.byType(TextFormField).first, 'test@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    // Assert
    verify(mockAuthService.signIn('test@example.com', 'password123')).called(1);
  });
}
