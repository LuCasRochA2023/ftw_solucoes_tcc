import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ftw_solucoes/services/auth_service.dart';
import 'package:ftw_solucoes/screens/schedule_service_screen.dart';

class AvailableServicesScreen extends StatefulWidget {
  final AuthService authService;

  const AvailableServicesScreen({
    Key? key,
    required this.authService,
  }) : super(key: key);

  @override
  State<AvailableServicesScreen> createState() =>
      _AvailableServicesScreenState();
}

class _AvailableServicesScreenState extends State<AvailableServicesScreen> {
  final Set<int> _selectedIndexes = {};

  void _onServiceTap(int index, Map<String, dynamic> service) async {
    final isSelected = _selectedIndexes.contains(index);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isSelected ? 'Remover Serviço' : 'Adicionar Serviço',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isSelected
              ? 'Deseja remover este serviço da sua lista?'
              : 'Deseja adicionar este serviço à sua lista?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isSelected ? 'Remover' : 'Adicionar',
                style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        if (isSelected) {
          _selectedIndexes.remove(index);
        } else {
          _selectedIndexes.add(index);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> washingServices = [
      {
        'title': 'Lavagem SUV',
        'description': 'Lavagem completa para SUV com produtos premium',
        'icon': Icons.directions_car,
        'color': Colors.lightBlue,
        'price': 'R\$ 80,00',
      },
      {
        'title': 'Lavagem Carro Comum',
        'description': 'Lavagem completa para carro de passeio',
        'icon': Icons.directions_car_filled,
        'color': Colors.blueAccent,
        'price': 'R\$ 70,00',
      },
      {
        'title': 'Lavagem Caminhonete',
        'description': 'Lavagem completa para caminhonete',
        'icon': Icons.local_shipping,
        'color': Colors.indigo,
        'price': 'R\$ 100,00',
      },
      {
        'title': 'Leva e Traz',
        'description': 'Serviço de busca e entrega do seu veículo',
        'icon': Icons.directions_car_filled,
        'color': Colors.purple,
        'price': 'R\$ 20,00',
      },
    ];

    final List<Map<String, dynamic>> otherServices = [
      {
        'title': 'Espelhamento',
        'description': 'Espelhamento completo com produtos de alta qualidade',
        'icon': Icons.auto_awesome,
        'color': Colors.purple,
      },
      {
        'title': 'Polimento',
        'description': 'Polimento profissional para recuperar o brilho',
        'icon': Icons.cleaning_services,
        'color': Colors.orange,
      },
      {
        'title': 'Higienização',
        'description': 'Higienização completa do interior do veículo',
        'icon': Icons.cleaning_services_outlined,
        'color': Colors.green,
      },
      {
        'title': 'Hidratação de Couro',
        'description': 'Hidratação e proteção dos bancos e painéis em couro',
        'icon': Icons.chair_alt,
        'color': Colors.brown,
      },
      {
        'title': 'Enceramento',
        'description': 'Enceramento profissional para proteção da pintura',
        'icon': Icons.auto_awesome_motion,
        'color': Colors.teal,
      },
      {
        'title': 'Cristalização de Faróis',
        'description': 'Restauração e proteção dos faróis',
        'icon': Icons.lightbulb_outline,
        'color': Colors.amber,
      },
      {
        'title': 'Remoção de chuva ácida',
        'description':
            'Remoção de manchas causadas por chuva ácida na pintura do veículo',
        'icon': Icons.water_drop,
        'color': Colors.blueGrey,
      },
      {
        'title': 'Lavagem do motor',
        'description': 'Lavagem detalhada e segura do motor do veículo',
        'icon': Icons.settings,
        'color': Colors.grey,
      },
      {
        'title': 'Revitalização de para-choques e plásticos',
        'description':
            'Revitalização e proteção de para-choques e plásticos externos',
        'icon': Icons.crop_16_9,
        'color': Colors.black54,
      },
      {
        'title': 'Higienização interna com extratora',
        'description':
            'Limpeza profunda dos estofados e carpetes com extratora',
        'icon': Icons.chair,
        'color': Colors.lightGreen,
      },
      {
        'title': 'Micropintura',
        'description': 'Correção de pequenos riscos e imperfeições na pintura',
        'icon': Icons.brush,
        'color': Colors.deepOrange,
      },
      {
        'title': 'Lavagem por baixo do veículo',
        'description': 'Lavagem completa da parte inferior do veículo',
        'icon': Icons.vertical_align_bottom,
        'color': Colors.brown,
      },
    ];

    final List<Map<String, dynamic>> services = [
      ...washingServices,
      ...otherServices,
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
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final service = services[index];
                final isSelected = _selectedIndexes.contains(index);
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    onTap: () => _onServiceTap(index, service),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: service['color'],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        service['icon'],
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    title: Text(
                      service['title'],
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service['description'],
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                          ),
                        ),
                        if (service['price'] != null)
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
                    trailing: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? service['color'] : Colors.grey,
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward),
                label: Text('Avançar para Agendamento',
                    style: GoogleFonts.poppins()),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _selectedIndexes.isNotEmpty ? Colors.blue : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
                onPressed: _selectedIndexes.isEmpty
                    ? null
                    : () {
                        final selectedServices =
                            _selectedIndexes.map((i) => services[i]).toList();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ScheduleServiceScreen(
                              services: selectedServices,
                              authService: widget.authService,
                            ),
                          ),
                        );
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OutrosServicosScreen extends StatelessWidget {
  final List<Map<String, dynamic>> otherServices;
  const OutrosServicosScreen({Key? key, required this.otherServices})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Atenção',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text(
            'Os preços dos serviços desta página não são informados no app. Para esses serviços, é necessário agendar uma avaliação presencial.',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      );
    });
    return Scaffold(
      appBar: AppBar(
        title: Text('Outros Serviços', style: GoogleFonts.poppins()),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: otherServices.length,
        itemBuilder: (context, index) {
          final service = otherServices[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: service['color'],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  service['icon'],
                  color: Colors.white,
                  size: 28,
                ),
              ),
              title: Text(
                service['title'],
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                service['description'],
                style: GoogleFonts.poppins(),
              ),
            ),
          );
        },
      ),
    );
  }
}
