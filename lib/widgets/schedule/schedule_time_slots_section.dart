import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ScheduleTimeSlotsSection extends StatelessWidget {
  final DateTime selectedDate;
  final List<String> timeSlots;
  final String? selectedTime;
  final Map<String, String> bookedTimeSlots;
  final Color mainColor;
  final bool Function(DateTime slotTime, Map<String, String> bookedSlots)
      isBlockAvailable;
  final bool Function(DateTime slotTime) isSlotInPast;
  final Future<void> Function(DateTime slotTime, String timeSlot) onSelectSlot;

  const ScheduleTimeSlotsSection({
    super.key,
    required this.selectedDate,
    required this.timeSlots,
    required this.selectedTime,
    required this.bookedTimeSlots,
    required this.mainColor,
    required this.isBlockAvailable,
    required this.isSlotInPast,
    required this.onSelectSlot,
  });

  @override
  Widget build(BuildContext context) {
    if (timeSlots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Icon(Icons.schedule, size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 12),
            Text(
              'Nenhum horário disponível',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Para esta data não há horários habilitados pelo administrador.\nSelecione outra data ou entre em contato conosco.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: timeSlots.length,
      itemBuilder: (context, index) {
        final timeSlot = timeSlots[index];
        final isSelected = timeSlot == selectedTime;
        final slotTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          int.parse(timeSlot.split(':')[0]),
          int.parse(timeSlot.split(':')[1]),
        );
        final available = isBlockAvailable(slotTime, bookedTimeSlots);
        final isPast = isSlotInPast(slotTime);
        final canSelect = available && !isPast;

        return Tooltip(
          message: isPast ? 'Horário já passou' : (available ? 'Disponível' : 'Ocupado'),
          child: InkWell(
            onTap: canSelect ? () => onSelectSlot(slotTime, timeSlot) : null,
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? mainColor
                    : (canSelect ? Colors.white : Colors.grey.shade300),
                border: Border.all(
                  color: isSelected
                      ? mainColor
                      : (canSelect ? Colors.grey.shade300 : Colors.red.shade300),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  timeSlot,
                  style: GoogleFonts.poppins(
                    color: isSelected
                        ? Colors.white
                        : (canSelect ? Colors.black87 : Colors.grey.shade600),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
