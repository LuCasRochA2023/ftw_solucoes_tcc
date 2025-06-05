import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftw_solucoes/screens/schedule_service_screen.dart';
import 'package:ftw_solucoes/services/auth_service.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MockAuthService extends Mock implements AuthService {}

class MockUser extends Mock implements User {}

class MockFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock implements CollectionReference {}

class MockQuerySnapshot extends Mock implements QuerySnapshot {}

void main() {
  late MockAuthService mockAuthService;
  late MockUser mockUser;
  late MockFirestore mockFirestore;

  setUp(() {
    mockAuthService = MockAuthService();
    mockUser = MockUser();
    mockFirestore = MockFirestore();

    when(mockAuthService.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test-uid');
    when(mockUser.email).thenReturn('test@example.com');
  });

  testWidgets('ScheduleServiceScreen deve mostrar título do serviço',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: ScheduleServiceScreen(
          serviceTitle: 'Lavagem',
          serviceColor: Colors.blue,
          serviceIcon: Icons.local_car_wash,
          authService: mockAuthService,
        ),
      ),
    );

    // Act
    await tester.pump();

    // Assert
    expect(find.text('Agendar Lavagem'), findsOneWidget);
  });

  testWidgets('ScheduleServiceScreen deve mostrar seleção de data e horário',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: ScheduleServiceScreen(
          serviceTitle: 'Lavagem',
          serviceColor: Colors.blue,
          serviceIcon: Icons.local_car_wash,
          authService: mockAuthService,
        ),
      ),
    );

    // Act
    await tester.pump();

    // Assert
    expect(find.text('Data'), findsOneWidget);
    expect(find.text('Horário'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today), findsOneWidget);
  });

  testWidgets(
      'ScheduleServiceScreen deve mostrar botão de confirmar agendamento',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: ScheduleServiceScreen(
          serviceTitle: 'Lavagem',
          serviceColor: Colors.blue,
          serviceIcon: Icons.local_car_wash,
          authService: mockAuthService,
        ),
      ),
    );

    // Act
    await tester.pump();

    // Assert
    expect(find.text('Confirmar Agendamento'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
