class ScheduleServiceConfig {
  const ScheduleServiceConfig._();

  static const Duration pendingHoldDuration = Duration(minutes: 30);

  static const List<String> weekdayDefaultSlots = [
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
  ];

  static const List<String> saturdayDefaultSlots = [
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '13:00',
    '14:00',
  ];

  static const Map<String, double> servicePrices = {
    'Lavagem SUV': 85.0,
    'Lavagem SUV Grande': 95.0,
    'Lavagem Carro Comum': 75.0,
    'Lavagem Caminhonete com Caçamba': 115.0,
    'Enceramento': 60.0,
    'Leva e Traz': 15.0,
  };
}
