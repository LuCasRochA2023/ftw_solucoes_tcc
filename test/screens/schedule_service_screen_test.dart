import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftw_solucoes/screens/schedule_service_screen.dart';
import 'package:ftw_solucoes/services/auth_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseFirestore>(),
  MockSpec<QuerySnapshot>(),
  MockSpec<CollectionReference>(),
  MockSpec<QueryDocumentSnapshot>()
])
void main() {
  setUp(() {
    test('O método deve retornar uma lista de agendamentos realizados', () {});
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
