import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftw_solucoes/screens/profile_screen.dart';
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

  testWidgets('ProfileScreen deve mostrar informações do usuário',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(authService: mockAuthService),
      ),
    );

    // Act
    await tester.pump();

    // Assert
    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
  });

  testWidgets('ProfileScreen deve mostrar botão de editar foto',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(authService: mockAuthService),
      ),
    );

    // Act
    await tester.pump();

    // Assert
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
  });

  testWidgets('ProfileScreen deve mostrar botão de logout',
      (WidgetTester tester) async {
    // Arrange
    when(mockAuthService.signOut()).thenAnswer((_) async => null);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(authService: mockAuthService),
      ),
    );

    // Act
    await tester.pump();
    await tester.tap(find.text('Sair'));
    await tester.pump();

    // Assert
    verify(mockAuthService.signOut()).called(1);
  });
}
