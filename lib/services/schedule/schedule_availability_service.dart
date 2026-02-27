import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class ScheduleAvailabilityService {
  const ScheduleAvailabilityService._();

  static bool isBlockAvailable(DateTime start, Map<String, String> bookedSlots) {
    debugPrint('=== DEBUG: Verificando disponibilidade do bloco ===');
    debugPrint('Horário de início: ${DateFormat('HH:mm').format(start)}');
    debugPrint('Slots ocupados: ${bookedSlots.keys.toList()}');

    final slotStr = DateFormat('HH:mm').format(start);
    if (bookedSlots.containsKey(slotStr)) {
      debugPrint('=== DEBUG: Slot ocupado: $slotStr ===');
      return false;
    }

    debugPrint('=== DEBUG: Slot disponível: $slotStr ===');
    return true;
  }

  static bool hasTimeOverlap(DateTime newAppointment, DateTime existingAppointment) {
    const blockDuration = Duration(minutes: 60);
    final existingEnd = existingAppointment.add(blockDuration);
    final newEnd = newAppointment.add(blockDuration);

    debugPrint('=== DEBUG: Verificação de sobreposição ===');
    debugPrint(
        'Novo agendamento: ${DateFormat('dd/MM/yyyy HH:mm').format(newAppointment)} - ${DateFormat('dd/MM/yyyy HH:mm').format(newEnd)}');
    debugPrint(
        'Agendamento existente: ${DateFormat('dd/MM/yyyy HH:mm').format(existingAppointment)} - ${DateFormat('dd/MM/yyyy HH:mm').format(existingEnd)}');

    final condition1 = newAppointment.isBefore(existingEnd);
    final condition2 = newEnd.isAfter(existingAppointment);
    final condition3 = newAppointment.isAtSameMomentAs(existingAppointment);
    final hasOverlap = (condition1 && condition2) || condition3;

    debugPrint('Condição 1 (novo início < fim existente): $condition1');
    debugPrint('Condição 2 (novo fim > início existente): $condition2');
    debugPrint('Condição 3 (horários iguais): $condition3');
    debugPrint('Resultado final: $hasOverlap');
    return hasOverlap;
  }

  static bool hasLavagemConflict(
    Map<String, dynamic> newServices,
    Map<String, dynamic> existingServices,
  ) {
    final newServicesList = newServices['services'] as List? ?? [];
    final existingServicesList = existingServices['services'] as List? ?? [];

    final hasNewLavagem = newServicesList.any((service) {
      final title = (service['title'] as String? ?? '').toLowerCase();
      return title.contains('lavagem');
    });

    final hasExistingLavagem = existingServicesList.any((service) {
      final title = (service['title'] as String? ?? '').toLowerCase();
      return title.contains('lavagem');
    });

    final hasConflict = hasNewLavagem && hasExistingLavagem;

    debugPrint('=== DEBUG: Verificação de conflito de lavagem ===');
    debugPrint(
        'Novos serviços: ${newServicesList.map((s) => s['title']).toList()}');
    debugPrint(
        'Serviços existentes: ${existingServicesList.map((s) => s['title']).toList()}');
    debugPrint('Tem lavagem no novo: $hasNewLavagem');
    debugPrint('Tem lavagem no existente: $hasExistingLavagem');
    debugPrint('Há conflito: $hasConflict');

    return hasConflict;
  }
}
