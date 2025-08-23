import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Widget reutilizável para o logo da FTW Soluções Automotivas
class FTWLogo extends StatelessWidget {
  final double size;
  final bool showShadow;

  const FTWLogo({
    super.key,
    this.size = 120,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: showShadow
            ? [
                const BoxShadow(
                  color: Color.fromRGBO(33, 150, 243, 0.3),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.1), // Reduzido de 0.13 para 0.1
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // Adicionado para evitar overflow
          children: [
            // FTW - Top Section
            Text(
              'FTW',
              style: GoogleFonts.poppins(
                color: const Color(0xFF2196F3),
                fontSize: size * 0.15, // Reduzido de 0.17 para 0.15
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: size * 0.02), // Reduzido de 0.03 para 0.02
            // SOLUÇÕES AUTOMOTIVAS - Middle Section
            Text(
              'SOLUÇÕES',
              style: GoogleFonts.poppins(
                color: const Color(0xFF2196F3),
                fontSize: size * 0.06, // Reduzido de 0.07 para 0.06
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'AUTOMOTIVAS',
              style: GoogleFonts.poppins(
                color: const Color(0xFF2196F3),
                fontSize: size * 0.06, // Reduzido de 0.07 para 0.06
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: size * 0.03), // Reduzido de 0.05 para 0.03
            // Service Icons - Bottom Section
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // Adicionado para evitar overflow
              children: [
                // Left Square - Red with "E"
                Container(
                  width: size * 0.11, // Reduzido de 0.13 para 0.11
                  height: size * 0.11, // Reduzido de 0.13 para 0.11
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(
                        size * 0.02), // Reduzido de 0.025 para 0.02
                  ),
                  child: Center(
                    child: Text(
                      'E',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: size * 0.06, // Reduzido de 0.07 para 0.06
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: size * 0.015), // Reduzido de 0.02 para 0.015
                // Middle Square - Teal with droplets
                Container(
                  width: size * 0.11, // Reduzido de 0.13 para 0.11
                  height: size * 0.11, // Reduzido de 0.13 para 0.11
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BCD4),
                    borderRadius: BorderRadius.circular(
                        size * 0.02), // Reduzido de 0.025 para 0.02
                  ),
                  child: Center(
                    child: Icon(
                      Icons.opacity,
                      color: Colors.white,
                      size: size * 0.07, // Reduzido de 0.08 para 0.07
                    ),
                  ),
                ),
                SizedBox(width: size * 0.015), // Reduzido de 0.02 para 0.015
                // Right Square - Orange with tools
                Container(
                  width: size * 0.11, // Reduzido de 0.13 para 0.11
                  height: size * 0.11, // Reduzido de 0.13 para 0.11
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(
                        size * 0.02), // Reduzido de 0.025 para 0.02
                  ),
                  child: Center(
                    child: Icon(
                      Icons.build,
                      color: Colors.white,
                      size: size * 0.07, // Reduzido de 0.08 para 0.07
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
