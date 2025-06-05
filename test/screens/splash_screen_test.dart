import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftw_solucoes/screens/splash_screen.dart';
import 'package:ftw_solucoes/screens/home_screen.dart';
import 'package:ftw_solucoes/services/auth_service.dart';
import 'package:mockito/mockito.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthService();
  });

  testWidgets('SplashScreen deve mostrar o logo FTW',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          nextScreen: HomeScreen(authService: mockAuthService),
        ),
      ),
    );

    // Act
    await tester.pump();

    // Assert
    expect(find.text('FTW'), findsOneWidget);
    expect(find.text('Soluções Automotivas'), findsOneWidget);
  });

  testWidgets('SplashScreen deve ter animações', (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          nextScreen: HomeScreen(authService: mockAuthService),
        ),
      ),
    );

    // Act
    await tester.pump();

    // Assert
    expect(find.byType(AnimatedBuilder), findsOneWidget);
    expect(find.byType(Transform), findsNWidgets(2)); // scale e rotate
  });

  testWidgets('SplashScreen deve navegar após 3 segundos',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          nextScreen: HomeScreen(authService: mockAuthService),
        ),
      ),
    );

    // Act
    await tester.pump(const Duration(seconds: 3));

    // Assert
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
