import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ScheduleTotalValueCard extends StatelessWidget {
  final Color mainColor;
  final bool hasServicesWithPrice;
  final double totalValue;
  final String? selectedCera;
  final bool hasWashingServices;

  const ScheduleTotalValueCard({
    super.key,
    required this.mainColor,
    required this.hasServicesWithPrice,
    required this.totalValue,
    required this.selectedCera,
    required this.hasWashingServices,
  });

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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: softMainColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderMainColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasServicesWithPrice) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Valor Total',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'R\$ ${totalValue.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: mainColor,
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Preço será definido após avaliação do veículo - agendamento sem pagamento',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (hasWashingServices && selectedCera != null) ...[
            const SizedBox(height: 8),
            Text(
              selectedCera == 'carnauba'
                  ? '• Cera de Carnaúba (+R\$ 30,00)'
                  : (selectedCera == 'jetcera'
                      ? '• Jet-Cera (+R\$ 20,00)'
                      : '• Enceramento Manual (+R\$ 60,00)'),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: mainColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
