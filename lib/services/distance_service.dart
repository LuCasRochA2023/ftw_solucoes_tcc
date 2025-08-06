import 'dart:math';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class DistanceService {
  // Coordenadas do estacionamento/lavagem (Porto Alegre, RS)
  static const double _lavagemLatitude = -30.0346;
  static const double _lavagemLongitude = -51.2177;

  /// Calcula a distância entre o endereço do usuário e o estacionamento
  /// Retorna a distância em quilômetros
  static Future<double?> calculateDistanceFromUserAddress(
      Map<String, dynamic> userAddress) async {
    try {
      // Construir endereço completo do usuário
      final userAddressString = _buildAddressString(userAddress);

      // Obter coordenadas do endereço do usuário
      final userCoordinates =
          await _getCoordinatesFromAddress(userAddressString);

      if (userCoordinates == null) {
        print('⚠️ Não foi possível obter coordenadas do endereço do usuário');
        return null;
      }

      // Calcular distância usando fórmula de Haversine
      final distance = _calculateHaversineDistance(
        userCoordinates['latitude']!,
        userCoordinates['longitude']!,
        _lavagemLatitude,
        _lavagemLongitude,
      );

      print('📍 Distância calculada: ${distance.toStringAsFixed(2)} km');
      return distance;
    } catch (e) {
      print('❌ Erro ao calcular distância: $e');
      return null;
    }
  }

  /// Verifica se o endereço está dentro da área de cobertura (4km)
  static Future<bool> isWithinCoverageArea(
      Map<String, dynamic> userAddress) async {
    final distance = await calculateDistanceFromUserAddress(userAddress);

    if (distance == null) {
      print(
          '⚠️ Não foi possível calcular distância, permitindo serviço por padrão');
      return true; // Por padrão, permite o serviço se não conseguir calcular
    }

    final isWithin = distance <= 4.0;
    print(
        '📍 Endereço está ${isWithin ? 'dentro' : 'fora'} da área de cobertura (${distance.toStringAsFixed(2)} km)');
    return isWithin;
  }

  /// Constrói string do endereço completo
  static String _buildAddressString(Map<String, dynamic> address) {
    final street = address['street'] ?? '';
    final number = address['number'] ?? '';
    final neighborhood = address['neighborhood'] ?? '';
    final city = address['city'] ?? '';
    final state = address['state'] ?? '';
    final cep = address['cep'] ?? '';

    return '$street, $number, $neighborhood, $city, $state, $cep, Brasil';
  }

  /// Obtém coordenadas de um endereço usando geocoding
  static Future<Map<String, double>?> _getCoordinatesFromAddress(
      String address) async {
    try {
      final locations = await locationFromAddress(address);

      if (locations.isNotEmpty) {
        final location = locations.first;
        return {
          'latitude': location.latitude,
          'longitude': location.longitude,
        };
      }

      return null;
    } catch (e) {
      print('❌ Erro ao obter coordenadas do endereço: $e');
      return null;
    }
  }

  /// Calcula distância usando fórmula de Haversine
  static double _calculateHaversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Raio da Terra em km

    // Converter graus para radianos
    final lat1Rad = _degreesToRadians(lat1);
    final lon1Rad = _degreesToRadians(lon1);
    final lat2Rad = _degreesToRadians(lat2);
    final lon2Rad = _degreesToRadians(lon2);

    // Diferenças nas coordenadas
    final deltaLat = lat2Rad - lat1Rad;
    final deltaLon = lon2Rad - lon1Rad;

    // Fórmula de Haversine
    final a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLon / 2) * sin(deltaLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Converte graus para radianos
  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }
}
