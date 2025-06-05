import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ftw_solucoes/services/auth_service.dart';
import 'package:ftw_solucoes/screens/schedule_service_screen.dart';

class AvailableServicesScreen extends StatelessWidget {
  final AuthService authService;

  const AvailableServicesScreen({
    Key? key,
    required this.authService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> services = [
      {
        'title': 'Lavagem',
        'description': 'Lavagem completa do veículo com produtos premium',
        'icon': Icons.local_car_wash,
        'color': Colors.blue,
        'price': 'R\$ 50,00',
      },
      {
        'title': 'Espelhamento',
        'description': 'Espelhamento completo com produtos de alta qualidade',
        'icon': Icons.auto_awesome,
        'color': Colors.purple,
        'price': 'R\$ 120,00',
      },
      {
        'title': 'Polimento',
        'description': 'Polimento profissional para recuperar o brilho',
        'icon': Icons.cleaning_services,
        'color': Colors.orange,
        'price': 'R\$ 150,00',
      },
      {
        'title': 'Higienização',
        'description': 'Higienização completa do interior do veículo',
        'icon': Icons.cleaning_services_outlined,
        'color': Colors.green,
        'price': 'R\$ 100,00',
      },
      {
        'title': 'Hidratação de Couro',
        'description': 'Hidratação e proteção dos bancos e painéis em couro',
        'icon': Icons.chair_alt,
        'color': Colors.brown,
        'price': 'R\$ 180,00',
      },
      {
        'title': 'Leva e Traz',
        'description': 'Serviço de busca e entrega do seu veículo',
        'icon': Icons.directions_car_filled,
        'color': Colors.indigo,
        'price': 'R\$ 30,00',
      },
      {
        'title': 'Enceramento',
        'description': 'Enceramento profissional para proteção da pintura',
        'icon': Icons.auto_awesome_motion,
        'color': Colors.teal,
        'price': 'R\$ 200,00',
      },
      {
        'title': 'Cristalização de Faróis',
        'description': 'Restauração e proteção dos faróis',
        'icon': Icons.lightbulb_outline,
        'color': Colors.amber,
        'price': 'R\$ 250,00',
      },
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Serviços Disponíveis',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: services.length,
          itemBuilder: (context, index) {
            final service = services[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ScheduleServiceScreen(
                        serviceTitle: service['title'],
                        serviceColor: service['color'],
                        serviceIcon: service['icon'],
                        authService: authService,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: service['color'],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          service['icon'],
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service['title'],
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              service['description'],
                              style: GoogleFonts.poppins(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              service['price'],
                              style: GoogleFonts.poppins(
                                color: service['color'],
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: service['color'],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
