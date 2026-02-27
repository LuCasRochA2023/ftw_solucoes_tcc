import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'schedule_cera_options_section.dart';
import 'schedule_date_selector.dart';
import 'schedule_time_slots_section.dart';
import 'schedule_total_value_card.dart';

class ScheduleBookingDetailsSection extends StatelessWidget {
  final bool hasWashingServices;
  final String? selectedCera;
  final Color mainColor;
  final ValueChanged<String?> onCeraChanged;
  final DateTime selectedDate;
  final DateFormat? dateFormat;
  final VoidCallback onSelectDate;
  final List<String> timeSlots;
  final String? selectedTime;
  final Map<String, String> bookedTimeSlots;
  final bool Function(DateTime slotTime, Map<String, String> bookedSlots)
      isBlockAvailable;
  final bool Function(DateTime slotTime) isSlotInPast;
  final Future<void> Function(DateTime slotTime, String timeSlot) onSelectSlot;
  final bool hasServicesWithPrice;
  final double totalValue;

  const ScheduleBookingDetailsSection({
    super.key,
    required this.hasWashingServices,
    required this.selectedCera,
    required this.mainColor,
    required this.onCeraChanged,
    required this.selectedDate,
    required this.dateFormat,
    required this.onSelectDate,
    required this.timeSlots,
    required this.selectedTime,
    required this.bookedTimeSlots,
    required this.isBlockAvailable,
    required this.isSlotInPast,
    required this.onSelectSlot,
    required this.hasServicesWithPrice,
    required this.totalValue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (hasWashingServices) ...[
          Text(
            'Opcionais',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ScheduleCeraOptionsSection(
            selectedCera: selectedCera,
            mainColor: mainColor,
            onChanged: onCeraChanged,
          ),
          const SizedBox(height: 16),
        ],
        Text(
          'Data',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ScheduleDateSelector(
          selectedDate: selectedDate,
          dateFormat: dateFormat,
          mainColor: mainColor,
          onTap: onSelectDate,
        ),
        const SizedBox(height: 24),
        Text(
          'Horário',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ScheduleTimeSlotsSection(
          selectedDate: selectedDate,
          timeSlots: timeSlots,
          selectedTime: selectedTime,
          bookedTimeSlots: bookedTimeSlots,
          mainColor: mainColor,
          isBlockAvailable: isBlockAvailable,
          isSlotInPast: isSlotInPast,
          onSelectSlot: onSelectSlot,
        ),
        const SizedBox(height: 24),
        ScheduleTotalValueCard(
          mainColor: mainColor,
          hasServicesWithPrice: hasServicesWithPrice,
          totalValue: totalValue,
          selectedCera: selectedCera,
          hasWashingServices: hasWashingServices,
        ),
      ],
    );
  }
}
