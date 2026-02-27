import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ScheduleCeraOptionsSection extends StatelessWidget {
  final String? selectedCera;
  final Color mainColor;
  final ValueChanged<String?> onChanged;

  const ScheduleCeraOptionsSection({
    super.key,
    required this.selectedCera,
    required this.mainColor,
    required this.onChanged,
  });

  Widget _buildOption({
    required String value,
    required String title,
    required String priceLabel,
  }) {
    return Row(
      children: [
        Radio<String>(
          value: value,
          // ignore: deprecated_member_use
          groupValue: selectedCera,
          toggleable: true,
          // ignore: deprecated_member_use
          onChanged: onChanged,
          activeColor: mainColor,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                priceLabel,
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final softMainColor = Color.fromRGBO(
      (mainColor.r * 255).round(),
      (mainColor.g * 255).round(),
      (mainColor.b * 255).round(),
      0.1,
    );
    final borderMainColor = Color.fromRGBO(
      (mainColor.r * 255).round(),
      (mainColor.g * 255).round(),
      (mainColor.b * 255).round(),
      0.3,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adicionais de Cera',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: mainColor,
              ),
            ),
            const SizedBox(height: 12),
            _buildOption(
              value: 'carnauba',
              title: 'Cera de Carnaúba',
              priceLabel: '+R\$ 30,00',
            ),
            _buildOption(
              value: 'jetcera',
              title: 'Jet-Cera',
              priceLabel: '+R\$ 20,00',
            ),
            _buildOption(
              value: 'manual',
              title: 'Enceramento Manual',
              priceLabel: '+R\$ 60,00',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: softMainColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderMainColor),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selecione apenas um tipo de cera',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: mainColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
