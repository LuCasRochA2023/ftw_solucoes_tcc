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
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.13),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // FTW - Top Section
            Text(
              'FTW',
              style: GoogleFonts.poppins(
                color: const Color(0xFF2196F3),
                fontSize: size * 0.17,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: size * 0.03),
            // SOLUÇÕES AUTOMOTIVAS - Middle Section
            Text(
              'SOLUÇÕES',
              style: GoogleFonts.poppins(
                color: const Color(0xFF2196F3),
                fontSize: size * 0.07,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'AUTOMOTIVAS',
              style: GoogleFonts.poppins(
                color: const Color(0xFF2196F3),
                fontSize: size * 0.07,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: size * 0.05),
            // Service Icons - Bottom Section
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Left Square - Red with "E"
                Container(
                  width: size * 0.13,
                  height: size * 0.13,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(size * 0.025),
                  ),
                  child: Center(
                    child: Text(
                      'E',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: size * 0.07,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: size * 0.02),
                // Middle Square - Teal with droplets
                Container(
                  width: size * 0.13,
                  height: size * 0.13,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BCD4),
                    borderRadius: BorderRadius.circular(size * 0.025),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.opacity,
                      color: Colors.white,
                      size: size * 0.08,
                    ),
                  ),
                ),
                SizedBox(width: size * 0.02),
                // Right Square - Orange with tools
                Container(
                  width: size * 0.13,
                  height: size * 0.13,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(size * 0.025),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.build,
                      color: Colors.white,
                      size: size * 0.08,
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