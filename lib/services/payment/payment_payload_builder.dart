class PaymentPayloadBuilder {
  const PaymentPayloadBuilder._();

  static String buildItemId({
    required String serviceTitle,
    required String appointmentId,
  }) {
    final t = serviceTitle.toLowerCase();
    if (t.contains('lavagem') && t.contains('carro comum')) {
      return 'lavagem_001';
    }
    if (t.contains('lavagem') && t.contains('suv')) return 'lavagem_002';
    if (t.contains('lavagem') && t.contains('caminhonete')) {
      return 'lavagem_003';
    }
    if (t.contains('leva') && t.contains('traz')) return 'leva_traz_001';
    if (appointmentId.isNotEmpty) return appointmentId;
    return 'service_item';
  }

  static List<Map<String, dynamic>> buildPaymentItems({
    required String serviceTitle,
    required String serviceDescription,
    required String appointmentId,
    required double amount,
    required double balanceToUse,
  }) {
    final totalServicePrice = amount + balanceToUse;
    return [
      {
        'id': buildItemId(serviceTitle: serviceTitle, appointmentId: appointmentId),
        'title': serviceTitle,
        'description': serviceDescription,
        'category_id': 'services',
        'quantity': 1,
        'unit_price': totalServicePrice,
      }
    ];
  }

  static String buildExternalReference(String appointmentId) {
    final id = appointmentId.trim();
    if (id.isEmpty) return 'agendamento_desconhecido';
    if (id.startsWith('agendamento_')) return id;
    return 'agendamento_$id';
  }
}
