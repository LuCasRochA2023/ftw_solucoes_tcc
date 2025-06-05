import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftw_solucoes/screens/payment_screen.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MockUser extends Mock implements User {}

class MockFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock implements CollectionReference {}

void main() {
  late List<Map<String, dynamic>> mockAppointments;

  setUp(() {
    mockAppointments = [
      {
        'service': 'Lavagem',
        'dateTime': DateTime(2024, 3, 15, 14, 30),
        'status': 'scheduled',
      },
      {
        'service': 'Polimento',
        'dateTime': DateTime(2024, 3, 15, 16, 0),
        'status': 'scheduled',
      },
    ];
  });

  testWidgets('PaymentScreen deve mostrar resumo dos serviços',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: PaymentScreen(appointments: mockAppointments),
      ),
    );

    // Act
    await tester.pump();

    // Assert
    expect(find.text('Resumo dos Serviços'), findsOneWidget);
    expect(find.text('Lavagem'), findsOneWidget);
    expect(find.text('Polimento'), findsOneWidget);
    expect(find.text('R\$ 200,00'), findsOneWidget); // Total para 2 serviços
  });

  testWidgets('PaymentScreen deve mostrar opções de pagamento',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: PaymentScreen(appointments: mockAppointments),
      ),
    );

    // Act
    await tester.pump();

    // Assert
    expect(find.text('Forma de Pagamento'), findsOneWidget);
    expect(find.text('Cartão de Crédito'), findsOneWidget);
    expect(find.text('PIX'), findsOneWidget);
    expect(find.byIcon(Icons.credit_card), findsOneWidget);
  });

  testWidgets(
      'PaymentScreen deve mostrar formulário de cartão ao selecionar cartão',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: PaymentScreen(appointments: mockAppointments),
      ),
    );

    // Act
    await tester.pump();
    await tester.tap(find.text('Cartão de Crédito'));
    await tester.pump();

    // Assert
    expect(find.text('Dados do Cartão'), findsOneWidget);
    expect(find.text('Número do Cartão'), findsOneWidget);
    expect(find.text('Data de Validade'), findsOneWidget);
    expect(find.text('CVV'), findsOneWidget);
    expect(find.text('Nome no Cartão'), findsOneWidget);
  });
}
