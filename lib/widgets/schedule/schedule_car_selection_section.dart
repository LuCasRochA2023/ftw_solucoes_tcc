import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ScheduleCarSelectionSection extends StatelessWidget {
  final List<Map<String, dynamic>> userCars;
  final String? selectedCarId;
  final Color mainColor;
  final Future<void> Function() onAddCar;
  final ValueChanged<Map<String, dynamic>?> onSelectCar;

  const ScheduleCarSelectionSection({
    super.key,
    required this.userCars,
    required this.selectedCarId,
    required this.mainColor,
    required this.onAddCar,
    required this.onSelectCar,
  });

  @override
  Widget build(BuildContext context) {
    if (userCars.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.directions_car, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'Nenhum carro cadastrado',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Adicione um carro para continuar com o agendamento',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async => onAddCar(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  foregroundColor: Colors.white,
                ),
                child: Text('Adicionar Carro', style: GoogleFonts.poppins()),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        ...userCars.map((car) {
          final isSelected = car['id'] == selectedCarId;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => onSelectCar(car),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (bool? value) {
                          if (value == true) {
                            onSelectCar(car);
                          } else {
                            onSelectCar(null);
                          }
                        },
                        activeColor: mainColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (car['name'] ?? '').toString(),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${(car['model'] ?? '').toString()} - ${(car['plate'] ?? '').toString()}',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () async => onAddCar(),
          icon: Icon(Icons.add, color: mainColor),
          label: Text(
            'Adicionar outro carro',
            style: GoogleFonts.poppins(color: mainColor),
          ),
        ),
      ],
    );
  }
}
