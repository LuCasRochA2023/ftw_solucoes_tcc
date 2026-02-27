import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ScheduleDateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final DateFormat? dateFormat;
  final Color mainColor;
  final VoidCallback onTap;

  const ScheduleDateSelector({
    super.key,
    required this.selectedDate,
    required this.dateFormat,
    required this.mainColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              dateFormat?.format(selectedDate) ??
                  '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
              style: GoogleFonts.poppins(fontSize: 16),
            ),
            Icon(
              Icons.calendar_today,
              color: mainColor,
            ),
          ],
        ),
      ),
    );
  }
}
