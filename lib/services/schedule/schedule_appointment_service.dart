import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ScheduleAppointmentService {
  const ScheduleAppointmentService._();

  static Future<String?> getActivePendingConflictMessage({
    required FirebaseFirestore firestore,
    required String userId,
    required Set<String> excludedAppointmentIds,
    required bool Function(Map<String, dynamic> data) isPendingHoldActive,
  }) async {
    final querySnapshot = await firestore
        .collection('appointments')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();

    final otherPendingAppointments = querySnapshot.docs.where((doc) {
      return !excludedAppointmentIds.contains(doc.id);
    }).toList();

    final activePending = otherPendingAppointments.where((doc) {
      final data = doc.data();
      return isPendingHoldActive(data);
    }).toList();

    if (activePending.isEmpty) return null;

    final pendingAppointment = activePending.first;
    final data = pendingAppointment.data();
    final appointmentDateTime = (data['dateTime'] as Timestamp).toDate();
    final timeSlot = DateFormat('HH:mm').format(appointmentDateTime);
    final dateSlot = DateFormat('dd/MM/yyyy').format(appointmentDateTime);

    return 'Você já possui um agendamento pendente às $timeSlot em $dateSlot. '
        'Complete o pagamento do agendamento atual antes de fazer um novo.';
  }
}
