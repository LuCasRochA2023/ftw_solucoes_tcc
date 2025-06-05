import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftw_solucoes/screens/home_screen.dart';
import 'package:ftw_solucoes/services/auth_service.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MockAuthService extends Mock implements AuthService {}

class MockUser extends Mock implements User {}

void main() {
  late MockAuthService mockAuthService;
  late MockUser mockUser;

  setUp(() {
    mockAuthService = MockAuthService();
    mockUser = MockUser();
    when(mockAuthService.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test-uid');
    when(mockUser.email).thenReturn('test@example.com');
  });

  testWidgets('HomeScreen deve mostrar AppBar com título',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(authService: mockAuthService),
      ),
    );

    // Act
    await tester.pump();

    // Assert
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('FTW Soluções'), findsOneWidget);
  });

  testWidgets('HomeScreen deve mostrar drawer com informações do usuário',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(authService: mockAuthService),
      ),
    );

    // Act
    await tester.pump();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump();

    // Assert
    expect(find.byType(UserAccountsDrawerHeader), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
  });

  testWidgets('HomeScreen deve mostrar botão de logout no drawer',
      (WidgetTester tester) async {
    // Arrange
    when(mockAuthService.signOut()).thenAnswer((_) async => null);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(authService: mockAuthService),
      ),
    );

    // Act
    await tester.pump();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump();
    await tester.tap(find.text('Sair'));
    await tester.pump();

    // Assert
    verify(mockAuthService.signOut()).called(1);
  });
}
