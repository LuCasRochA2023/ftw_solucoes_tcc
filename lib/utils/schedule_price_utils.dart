import '../config/schedule_service_config.dart';

class SchedulePriceUtils {
  const SchedulePriceUtils._();

  static double? parsePrice(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return null;
      final cleaned = s
          .replaceAll('R\$', '')
          .replaceAll(RegExp(r'\s+'), '')
          .replaceAll('.', '')
          .replaceAll(',', '.');
      return double.tryParse(cleaned);
    }
    return null;
  }

  static double getServicePrice(Map<String, dynamic> service) {
    final title = (service['title'] ?? '').toString().trim();
    final fixed = ScheduleServiceConfig.servicePrices[title];
    if (fixed != null) return fixed;

    final fromPriceField = parsePrice(service['price']);
    if (fromPriceField != null) return fromPriceField;

    final fromValueField = parsePrice(service['value']);
    if (fromValueField != null) return fromValueField;

    return 0.0;
  }

  static bool hasWashingServices(List<Map<String, dynamic>> services) {
    return services.any((service) {
      final title = (service['title'] ?? '').toString().toLowerCase();
      return (title.contains('lavagem suv') ||
              title.contains('lavagem carro comum') ||
              title.contains('lavagem caminhonete')) &&
          !title.contains('leva e traz');
    });
  }

  static double calculateTotalValue({
    required List<Map<String, dynamic>> services,
    required String? selectedCera,
  }) {
    double total = 0;

    for (final service in services) {
      total += getServicePrice(service);
    }

    if (hasWashingServices(services) && selectedCera != null) {
      if (selectedCera == 'carnauba') total += 30.0;
      if (selectedCera == 'jetcera') total += 20.0;
      if (selectedCera == 'manual') total += 60.0;
    }

    return total;
  }

  static bool hasServicesWithPrice(List<Map<String, dynamic>> services) {
    for (final service in services) {
      final title = (service['title'] ?? '').toString().trim();
      final fixed = ScheduleServiceConfig.servicePrices[title];
      if (fixed != null && fixed > 0) return true;

      final fromPriceField = service['price'];
      if (fromPriceField is String && fromPriceField.contains('R\$')) {
        return true;
      }

      final fromValueField = service['value'];
      if (fromValueField is num && fromValueField.toDouble() > 0) return true;
    }
    return false;
  }
}
