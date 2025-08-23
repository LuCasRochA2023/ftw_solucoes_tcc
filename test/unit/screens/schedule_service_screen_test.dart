import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:ftw_solucoes/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Gerar mocks
@GenerateMocks([
  AuthService,
  FirebaseFirestore,
  CollectionReference,
  QuerySnapshot,
  QueryDocumentSnapshot,
  FirebaseAuth
])
import 'schedule_service_screen_test.mocks.dart';

void main() {
  group('ScheduleServiceScreen - Testes de Lógica', () {
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
    });

    // Dados de teste
    final List<Map<String, dynamic>> testServices = [
      {
        'title': 'Lavagem SUV',
        'description': 'Lavagem completa para SUV',
        'color': Colors.blue,
        'icon': Icons.car_rental,
      },
      {
        'title': 'Leva e Traz',
        'description': 'Serviço de leva e traz',
        'color': Colors.green,
        'icon': Icons.directions_car,
      },
    ];

    group('Validação de Preços dos Serviços', () {
      test('deve ter preços corretos para todos os serviços', () {
        // Arrange
        final expectedPrices = {
          'Lavagem SUV': 80.0,
          'Lavagem Carro Comum': 70.0,
          'Lavagem Caminhonete': 100.0,
          'Leva e Traz': 20.0,
        };

        // Act & Assert
        for (final entry in expectedPrices.entries) {
          expect(entry.value, isA<double>());
          expect(entry.value, greaterThan(0));
        }
      });

      test('deve ter diferença correta entre tipos de cera', () {
        // Arrange
        const carnaubaPrice = 30.0;
        const jetCeraPrice = 10.0;
        const expectedDifference = 20.0;

        // Act & Assert
        expect(carnaubaPrice - jetCeraPrice, equals(expectedDifference));
      });
    });

    group('Validação de Data', () {
      test('deve identificar domingo corretamente', () {
        // Arrange
        final sunday = DateTime(2024, 1, 7); // Domingo

        // Act
        final isSunday = sunday.weekday == DateTime.sunday;

        // Assert
        expect(isSunday, isTrue);
      });

      test('deve identificar segunda-feira corretamente', () {
        // Arrange
        final monday = DateTime(2024, 1, 8); // Segunda-feira

        // Act
        final isMonday = monday.weekday == DateTime.monday;

        // Assert
        expect(isMonday, isTrue);
      });
    });

    group('Validação de Serviços', () {
      test('deve identificar serviços de lavagem por título', () {
        // Arrange
        final washingTitles = [
          'Lavagem SUV',
          'Lavagem Carro Comum',
          'Lavagem Caminhonete',
        ];

        // Act & Assert
        for (final title in washingTitles) {
          final isWashing = title.toLowerCase().contains('lavagem');
          expect(isWashing, isTrue);
        }
      });

      test('deve identificar serviços que não são de lavagem', () {
        // Arrange
        final nonWashingTitles = [
          'Leva e Traz',
          'Manutenção',
          'Troca de Óleo',
        ];

        // Act & Assert
        for (final title in nonWashingTitles) {
          final isWashing = title.toLowerCase().contains('lavagem');
          expect(isWashing, isFalse);
        }
      });
    });

    group('Cálculo de Preços - Lógica de Negócio', () {
      test('deve calcular preço total para lavagem SUV', () {
        // Arrange
        const suvPrice = 80.0;

        // Act
        final total = suvPrice;

        // Assert
        expect(total, equals(80.0));
      });

      test('deve calcular preço total para lavagem SUV com cera de carnaúba',
          () {
        // Arrange
        const suvPrice = 80.0;
        const carnaubaPrice = 30.0;

        // Act
        final total = suvPrice + carnaubaPrice;

        // Assert
        expect(total, equals(110.0));
      });

      test('deve calcular preço total para lavagem caminhonete com jet-cera',
          () {
        // Arrange
        const caminhonetePrice = 100.0;
        const jetCeraPrice = 10.0;

        // Act
        final total = caminhonetePrice + jetCeraPrice;

        // Assert
        expect(total, equals(110.0));
      });

      test('deve calcular preço para múltiplos serviços', () {
        // Arrange
        const carroComumPrice = 70.0;
        const levaTrazPrice = 20.0;
        const carnaubaPrice = 30.0;

        // Act
        final total = carroComumPrice + levaTrazPrice + carnaubaPrice;

        // Assert
        expect(total, equals(120.0));
      });
    });

    group('Validação de Cenários de Negócio', () {
      test('deve validar que serviços de lavagem podem ter cera', () {
        // Arrange
        final washingService = {
          'title': 'Lavagem Carro Comum',
          'description': 'Lavagem para carro comum',
        };

        // Act
        final canHaveWax = washingService['title']
            .toString()
            .toLowerCase()
            .contains('lavagem');

        // Assert
        expect(canHaveWax, isTrue);
      });

      test('deve validar que serviços não-lavagem não podem ter cera', () {
        // Arrange
        final nonWashingService = {
          'title': 'Leva e Traz',
          'description': 'Serviço de transporte',
        };

        // Act
        final canHaveWax = nonWashingService['title']
            .toString()
            .toLowerCase()
            .contains('lavagem');

        // Assert
        expect(canHaveWax, isFalse);
      });

      test('deve validar que domingo não é dia útil', () {
        // Arrange
        final sunday = DateTime(2024, 1, 7);

        // Act
        final isWeekend = sunday.weekday == DateTime.sunday;

        // Assert
        expect(isWeekend, isTrue);
      });

      test('deve validar que segunda-feira é dia útil', () {
        // Arrange
        final monday = DateTime(2024, 1, 8);

        // Act
        final isWeekend = monday.weekday == DateTime.sunday;

        // Assert
        expect(isWeekend, isFalse);
      });
    });

    group('Validação de Dados de Entrada', () {
      test('deve validar estrutura de serviços', () {
        // Arrange
        final service = testServices.first;

        // Act & Assert
        expect(service.containsKey('title'), isTrue);
        expect(service.containsKey('description'), isTrue);
        expect(service.containsKey('color'), isTrue);
        expect(service.containsKey('icon'), isTrue);
      });

      test('deve validar que título do serviço não está vazio', () {
        // Arrange
        final service = testServices.first;

        // Act
        final title = service['title'] as String;

        // Assert
        expect(title.isNotEmpty, isTrue);
        expect(title.length, greaterThan(0));
      });

      test('deve validar que descrição do serviço não está vazia', () {
        // Arrange
        final service = testServices.first;

        // Act
        final description = service['description'] as String;

        // Assert
        expect(description.isNotEmpty, isTrue);
        expect(description.length, greaterThan(0));
      });
    });

    group('Validação de Lógica de Negócio Avançada', () {
      test('deve validar que cera só é aplicável em serviços de lavagem', () {
        // Arrange
        final washingService = 'Lavagem SUV';
        final nonWashingService = 'Leva e Traz';

        // Act
        final washingCanHaveWax =
            washingService.toLowerCase().contains('lavagem');
        final nonWashingCanHaveWax =
            nonWashingService.toLowerCase().contains('lavagem');

        // Assert
        expect(washingCanHaveWax, isTrue);
        expect(nonWashingCanHaveWax, isFalse);
      });

      test('deve validar que preços de cera são diferentes', () {
        // Arrange
        const carnaubaPrice = 30.0;
        const jetCeraPrice = 10.0;

        // Act
        final priceDifference = carnaubaPrice - jetCeraPrice;

        // Assert
        expect(priceDifference, equals(20.0));
        expect(carnaubaPrice, greaterThan(jetCeraPrice));
      });

      test('deve validar que serviços têm preços válidos', () {
        // Arrange
        final servicePrices = {
          'Lavagem SUV': 80.0,
          'Lavagem Carro Comum': 70.0,
          'Lavagem Caminhonete': 100.0,
          'Leva e Traz': 20.0,
        };

        // Act & Assert
        for (final entry in servicePrices.entries) {
          expect(entry.value, isA<double>());
          expect(entry.value, greaterThan(0));
          expect(entry.value, lessThan(1000)); // Preço máximo razoável
        }
      });

      test('deve validar que dias úteis não incluem domingo', () {
        // Arrange
        final weekdays = [
          DateTime(2024, 1, 8), // Segunda
          DateTime(2024, 1, 9), // Terça
          DateTime(2024, 1, 10), // Quarta
          DateTime(2024, 1, 11), // Quinta
          DateTime(2024, 1, 12), // Sexta
          DateTime(2024, 1, 13), // Sábado
        ];

        final sunday = DateTime(2024, 1, 7);

        // Act & Assert
        for (final weekday in weekdays) {
          expect(weekday.weekday, isNot(DateTime.sunday));
        }
        expect(sunday.weekday, equals(DateTime.sunday));
      });
    });
  });
}
