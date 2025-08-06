import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SobreScreen extends StatelessWidget {
  const SobreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Text('Sobre a FTW', style: GoogleFonts.poppins()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(5.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Apresentação Institucional – FTW Soluções Automotivas',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Image.asset(
              'assets/images/entradaFtw.png',
              width: screenWidth,
              height: screenHeight * 0.6,
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8),
              child: Text(
                'Desde 2013, a FTW Soluções Automotivas atua com excelência no segmento de lavagem e estética automotiva em Porto Alegre, oferecendo serviços de alta qualidade para um público exigente e apaixonado por carros.\n'
                'Nossa missão é entregar não apenas veículos limpos, mas experiências marcantes, através de um cuidado minucioso com cada detalhe.',
                textAlign: TextAlign.justify,
                style: GoogleFonts.poppins(fontSize: 16, letterSpacing: -1),
              ),
            ),
            const SizedBox(height: 15),
            Image.asset(
              'assets/images/interiorFtw.png',
              width: screenWidth,
              height: screenHeight * 0.5,
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 12),
              child: Text(
                'Trabalhamos com produtos de primeira linha e técnicas especializadas, garantindo um resultado superior e duradouro.\n'
                'Com mais de uma década de história, construímos uma reputação sólida baseada na confiança, no comprometimento e no padrão de qualidade FTW, que pode ser visto no brilho de cada carro que passa por nossas mãos.\n'
                'Seja para proteger, restaurar ou simplesmente valorizar a aparência do seu veículo, a FTW é a escolha certa para quem trata o carro como uma verdadeira paixão.',
                textAlign: TextAlign.justify,
                style: GoogleFonts.poppins(fontSize: 16, letterSpacing: -1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
