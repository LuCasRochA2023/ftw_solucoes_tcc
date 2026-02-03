import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ftw_solucoes/services/auth_service.dart';
import 'package:ftw_solucoes/screens/schedule_service_screen.dart';
import 'package:ftw_solucoes/services/distance_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  bool _isLoadingDistance = false;
  bool _levaETrazAvailable = true; // Por padrão, disponível

  @override
  void initState() {
    super.initState();
    _loadUserAddressAndCheckDistance();
  }

  Future<void> _loadUserAddressAndCheckDistance() async {
    setState(() {
      _isLoadingDistance = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final address = userData['address'] as Map<String, dynamic>?;

          if (address != null) {
            setState(() {});

            // Verificar se está dentro da área de cobertura
            final isWithinCoverage =
                await DistanceService.isWithinCoverageArea(address);

            setState(() {
              _levaETrazAvailable = isWithinCoverage;
            });

            debugPrint(
                ' Serviço "Leva e Traz" ${isWithinCoverage ? 'disponível' : 'indisponível'} para este endereço');
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar endereço do usuário: $e');
      // Em caso de erro, mantém o serviço disponível por padrão
    } finally {
      setState(() {
        _isLoadingDistance = false;
      });
    }
  }

  void _onServiceTap(int index, Map<String, dynamic> service) async {
    // Verificar se é o serviço "Leva e Traz" e se está indisponível
    if (service['title'] == 'Leva e Traz' && !_levaETrazAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Serviço "Leva e Traz" não disponível para seu endereço (fora da área de 4km)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Verificar se é o serviço "Leva e Traz" e se não há outros serviços selecionados
    if (service['title'] == 'Leva e Traz' && !_isLevaETrazSelectable()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Selecione pelo menos um serviço de lavagem antes de adicionar "Leva e Traz"'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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

  // Método para verificar se o serviço "Leva e Traz" pode ser selecionado
  bool _isLevaETrazSelectable() {
    // Verificar se há pelo menos um serviço de lavagem selecionado
    final List<String> washingServiceTitles = [
      'Lavagem SUV',
      'Lavagem SUV Grande',
      'Lavagem Carro Comum',
      'Lavagem Caminhonete com Caçamba',
    ];

    for (int selectedIndex in _selectedIndexes) {
      final services = _getAllServices();
      if (selectedIndex < services.length) {
        final serviceTitle = services[selectedIndex]['title'];
        if (washingServiceTitles.contains(serviceTitle)) {
          return true;
        }
      }
    }
    return false;
  }

  // Método para verificar se um serviço é de lavagem
  bool _isLavagemService(String serviceTitle) {
    final List<String> lavagemServices = [
      'Lavagem SUV',
      'Lavagem SUV Grande',
      'Lavagem Carro Comum',
      'Lavagem Caminhonete com Caçamba',
    ];
    return lavagemServices.contains(serviceTitle);
  }

  // Método para verificar se já há um serviço de lavagem selecionado
  bool _hasLavagemServiceSelected() {
    for (int selectedIndex in _selectedIndexes) {
      final services = _getAllServices();
      if (selectedIndex < services.length) {
        final serviceTitle = services[selectedIndex]['title'];
        if (_isLavagemService(serviceTitle)) {
          return true;
        }
      }
    }
    return false;
  }

  // Método auxiliar para obter todos os serviços
  List<Map<String, dynamic>> _getAllServices() {
    final List<Map<String, dynamic>> washingServices = [
      {
        'title': 'Lavagem SUV',
        'subtitle': 'Premium',
        'description':
            'Lavagem completa externa e interna com produtos premium',
        'icon': Icons.directions_car,
        'color': Colors.lightBlue,
        'price': 'R\$ 85,00',
      },
      {
        'title': 'Lavagem SUV Grande',
        'subtitle': 'SUV GRANDE',
        'description': 'Lavagem completa para SUVs grandes',
        'icon': Icons.directions_car,
        'color': Colors.lightBlue,
        'price': 'R\$ 95,00',
      },
      {
        'title': 'Lavagem Carro Comum',
        'subtitle': 'Neutro',
        'description': 'Lavagem detalhada externa e interna com shampoo neutro',
        'icon': Icons.directions_car_filled,
        'color': Colors.lightBlue,
        'price': 'R\$ 75,00',
      },
      {
        'title': 'Lavagem Caminhonete com Caçamba',
        'subtitle': 'Caçamba',
        'description': 'Lavagem completa incluindo caçamba',
        'icon': Icons.local_shipping,
        'color': Colors.lightBlue,
        'price': 'R\$ 115,00',
      },
      {
        'title': 'Leva e Traz',
        'subtitle': 'Busca + Entrega',
        'description': 'Busca, lavagem e entrega do veículo',
        'icon': Icons.directions_car_filled,
        'color': Colors.lightBlue,
        'price': 'R\$ 20,00',
      },
    ];

    final List<Map<String, dynamic>> otherServices = [
      {
        'title': 'Espelhamento',
        'subtitle': 'Riscos',
        'description': 'Remoção de riscos superficiais e correção de manchas',
        'icon': Icons.auto_awesome,
        'color': Colors.lightBlue,
        'price': 'Preço a combinar',
      },
      {
        'title': 'Polimento',
        'subtitle': 'Profundo',
        'description': 'Correção de imperfeições profundas na pintura',
        'icon': Icons.cleaning_services,
        'color': Colors.lightBlue,
        'price': 'Preço a combinar',
      },
      {
        'title': 'Higienização',
        'subtitle': 'Profunda',
        'description': 'Limpeza profunda do interior com extratora',
        'icon': Icons.cleaning_services_outlined,
        'color': Colors.lightBlue,
        'price': 'Preço a combinar',
      },
      {
        'title': 'Hidratação de Couro',
        'subtitle': 'Especializado',
        'description': 'Limpeza, hidratação e proteção de bancos em couro',
        'icon': Icons.chair_alt,
        'color': Colors.lightBlue,
        'price': 'Preço a combinar',
      },
      {
        'title': 'Enceramento',
        'subtitle': 'Carnaúba Vonixx',
        'description': 'Aplicação de cera de carnaúba natural',
        'icon': Icons.auto_awesome_motion,
        'color': Colors.lightBlue,
        'price': 'R\$ 60,00',
      },
      {
        'title': 'Cristalização de Faróis',
        'subtitle': 'Restauração',
        'description': 'Restauração do brilho original dos faróis',
        'icon': Icons.lightbulb_outline,
        'color': Colors.lightBlue,
        'price': 'Preço a combinar',
      },
      {
        'title': 'Remoção de chuva ácida',
        'subtitle': 'Tratamento Especializado',
        'description': 'Tratamento para remover manchas de chuva ácida',
        'icon': Icons.water_drop,
        'color': Colors.lightBlue,
        'price': 'Preço a combinar',
      },
      {
        'title': 'Lavagem do motor',
        'subtitle': 'Limpeza Segura',
        'description': 'Lavagem segura do compartimento do motor',
        'icon': Icons.settings,
        'color': Colors.lightBlue,
        'price': 'Preço a combinar',
      },
      {
        'title': 'Revitalização de para-choques e plásticos',
        'subtitle': 'Restauração + Proteção',
        'description': 'Restauração da cor original e proteção',
        'icon': Icons.crop_16_9,
        'color': Colors.lightBlue,
        'price': 'Preço a combinar',
      },
      {
        'title': 'Higienização interna com extratora',
        'subtitle': 'Limpeza Profunda',
        'description': 'Limpeza profunda de estofados e carpetes',
        'icon': Icons.chair,
        'color': Colors.lightBlue,
        'price': 'Preço a combinar',
      },
      {
        'title': 'Micropintura',
        'subtitle': 'Correção + Polimento',
        'description': 'Correção de pequenos riscos e arranhões',
        'icon': Icons.brush,
        'color': Colors.lightBlue,
        'price': 'Preço a combinar',
      },
      {
        'title': 'Lavagem por baixo do veículo',
        'description': 'Limpeza completa da parte inferior',
        'icon': Icons.vertical_align_bottom,
        'color': Colors.lightBlue,
        'price': 'Preço a combinar',
      },
    ];

    return [...washingServices, ...otherServices];
  }

  void _showServiceDetails(Map<String, dynamic> service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          service['title'],
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                service['description'],
                style: GoogleFonts.poppins(fontSize: 16),
              ),
              const SizedBox(height: 16),
              _buildInfoRow('Preço', service['price'] ?? 'Sob consulta'),
              if (service['price'] == 'Preço a combinar') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
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
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Agendamento sem pagamento - preço será definido após avaliação do veículo',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              // Informação específica para Leva e Traz
              if (service['title'] == 'Leva e Traz') ...[
                const SizedBox(height: 8),
                _buildInfoRow('Área de Cobertura', 'Até 4km do estacionamento'),
              ],
              // Adicionar opcionais de cera apenas para serviços de lavagem
              if (_isWashingService(service['title'])) ...[
                const SizedBox(height: 16),
                Text(
                  'Opcionais disponíveis:',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: service['color'],
                  ),
                ),
                const SizedBox(height: 8),
                _buildInfoRow('Cera de Carnaúba', '+R\$ 30,00'),
                const SizedBox(height: 4),
                _buildInfoRow('Jet-Cera', '+R\$ 10,00'),
              ],
              const SizedBox(height: 16),
              Text(
                'Detalhes:',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ..._getServiceTips(service['title']).map((tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: GoogleFonts.poppins(fontSize: 16)),
                        Expanded(
                          child: Text(
                            tip,
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Fechar', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(fontSize: 14),
          ),
        ),
      ],
    );
  }

  bool _isWashingService(String serviceTitle) {
    final washingServices = [
      'lavagem suv',
      'lavagem suv grande',
      'lavagem carro comum',
      'lavagem caminhonete com caçamba',
    ];
    return washingServices.contains(serviceTitle.toLowerCase());
  }

  List<String> _getServiceTips(String serviceTitle) {
    switch (serviceTitle.toLowerCase()) {
      case 'lavagem suv':
        return [
          'Lavagem completa externa com shampoo especial',
          'Limpeza interna com aspirador e produtos específicos',
          'Secagem com pano de microfibra para evitar manchas',
          'Aplicação de cera líquida para proteção da pintura',
          'Limpeza de vidros e espelhos com produto anti-embaçante',
        ];
      case 'lavagem suv grande':
        return [
          'Lavagem completa externa com shampoo especial',
          'Limpeza interna com aspirador e produtos específicos',
          'Atenção extra em áreas maiores (teto e laterais)',
          'Secagem manual para evitar manchas e riscos',
          'Aplicação de cera líquida para proteção da pintura',
        ];
      case 'lavagem carro comum':
        return [
          'Lavagem externa com shampoo neutro de alta qualidade',
          'Limpeza interna completa com aspirador profissional',
          'Tratamento dos pneus com produto específico',
          'Secagem manual para evitar riscos na pintura',
          'Aplicação de cera para proteção e brilho',
        ];
      case 'lavagem caminhonete com caçamba':
        return [
          'Lavagem especializada para veículos de grande porte',
          'Limpeza da caçamba com produtos específicos',
          'Tratamento da pintura com cera de proteção',
          'Limpeza interna com atenção aos detalhes',
          'Secagem completa para evitar manchas',
        ];
      case 'espelhamento':
        return [
          'Remoção de riscos superficiais com pasta especial',
          'Correção de manchas e oxidação da pintura',
          'Aplicação de cera de proteção de longa duração',
          'Processo manual para garantir qualidade',
          'Resultado: pintura com brilho de showroom',
        ];
      case 'polimento':
        return [
          'Remoção de oxidação e manchas profundas',
          'Correção de riscos e imperfeições na pintura',
          'Aplicação de cera de proteção premium',
          'Tratamento com produtos de alta qualidade',
          'Duração: proteção por até 6 meses',
        ];
      case 'higienização':
        return [
          'Limpeza do tecido dos bancos com extratora',
          'Remoção de odores com produtos específicos',
          'Tratamento antibacteriano dos bancos',
          'Limpeza de forro',
          'Limpeza de carpetes',
        ];
      case 'hidratação de couro':
        return [
          'Limpeza profunda do couro com produtos específicos',
          'Aplicação de hidratante para prevenir rachaduras',
          'Proteção contra raios UV e desgaste',
          'Tratamento de costuras e detalhes',
          'Mantém a suavidade e durabilidade do couro',
        ];
      case 'enceramento':
        return [
          'Aplicação de cera de carnaúba natural',
          'Proteção da pintura contra chuva ácida',
          'Brilho intenso e duradouro',
          'Repelente de água e sujeira',
          'Duração: proteção por até 2 meses',
        ];
      case 'cristalização de faróis':
        return [
          'Lixamento para remover amarelamento',
          'Aplicação de resina de proteção UV',
          'Restauração do brilho original',
          'Proteção contra futuras oxidações',
          'Melhora significativa na iluminação',
        ];
      case 'remoção de chuva ácida':
        return [
          'Identificação e tratamento das manchas',
          'Uso de produtos específicos para cada tipo',
          'Correção da pintura afetada',
          'Aplicação de proteção preventiva',
          'Garantia de resultado satisfatório',
        ];
      case 'lavagem do motor':
        return [
          'Lavagem segura com produtos específicos',
          'Proteção de componentes elétricos',
          'Limpeza de óleo e graxa',
          'Secagem completa do compartimento',
          'Aplicação de protetor para motor',
        ];
      case 'revitalização de para-choques e plásticos':
        return [
          'Limpeza profunda com produtos específicos',
          'Aplicação de restaurador de plásticos',
          'Proteção contra raios UV',
          'Tratamento de manchas e riscos',
          'Restauração da cor original',
        ];
      case 'higienização interna com extratora':
        return [
          'Extração profunda de sujeira dos estofados',
          'Limpeza de carpetes e tapetes',
          'Remoção de odores com produtos específicos',
          'Tratamento antibacteriano completo',
          'Secagem rápida e eficiente',
        ];
      case 'micropintura':
        return [
          'Correção de riscos superficiais',
          'Reparo de pequenos arranhões',
          'Aplicação de tinta original',
          'Polimento para nivelar a superfície',
          'Resultado imperceptível',
          'Mantêm a cor original do veículo',
        ];
      case 'lavagem por baixo do veículo':
        return [
          'Remoção de lama e sujeira acumulada',
          'Limpeza de componentes mecânicos',
          'Aplicação de protetor anticorrosivo',
          'Inspeção de possíveis vazamentos',
          'Prevenção de corrosão',
        ];
      case 'leva e traz':
        return [
          'Busca do veículo no local combinado',
          'Realização do serviço em nossa lavagem',
          'Entrega do veículo limpo no mesmo local',
          'Horário flexível conforme sua disponibilidade',
        ];
      default:
        return [
          'Serviço realizado por profissionais qualificados',
          'Uso de produtos de alrta qualidade',
          'Garantia de satisfação total',
          'Agende com antecedência para melhor atendimento',
          'Atendimento personalizado e cuidadoso',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> washingServices = [
      {
        'title': 'Lavagem SUV',
        'subtitle': 'Premium',
        'description':
            'Lavagem completa externa e interna com produtos premium',
        'icon': Icons.directions_car,
        'color': Colors.lightBlue,
        'price': 'R\$ 85,00',
      },
      {
        'title': 'Lavagem SUV Grande',
        'subtitle': 'SUV GRANDE',
        'description': 'Lavagem completa para SUVs grandes',
        'icon': Icons.directions_car,
        'color': Colors.lightBlue,
        'price': 'R\$ 95,00',
      },
      {
        'title': 'Lavagem Carro Comum',
        'subtitle': 'Neutro',
        'description': 'Lavagem detalhada externa e interna com shampoo neutro',
        'icon': Icons.directions_car_filled,
        'color': Colors.lightBlue,
        'price': 'R\$ 75,00',
      },
      {
        'title': 'Lavagem Caminhonete com Caçamba',
        'subtitle': 'Caçamba',
        'description': 'Lavagem completa incluindo caçamba',
        'icon': Icons.local_shipping,
        'color': Colors.lightBlue,
        'price': 'R\$ 115,00',
      },
      {
        'title': 'Leva e Traz',
        'subtitle': 'Busca + Entrega',
        'description': 'Busca, lavagem e entrega do veículo',
        'icon': Icons.directions_car_filled,
        'color': Colors.lightBlue,
        'price': 'R\$ 20,00',
      },
    ];

    final List<Map<String, dynamic>> otherServices = [
      {
        'title': 'Espelhamento',
        'subtitle': 'Riscos',
        'description': 'Remoção de riscos superficiais e correção de manchas',
        'icon': Icons.auto_awesome,
        'color': Colors.lightBlue,
        'price': 'Preço a combinar',
      },
      {
        'title': 'Polimento',
        'subtitle': 'Profundo',
        'description': 'Correção de imperfeições profundas na pintura',
        'icon': Icons.cleaning_services,
        'color': Colors.lightBlue,
        'price': 'Preço a combinar',
      },
      {
        'title': 'Higienização',
        'subtitle': 'Profunda',
        'description': 'Limpeza profunda do interior com extratora',
        'icon': Icons.cleaning_services_outlined,
        'color': Colors.lightBlue,
        'price': 'Preço a combinar',
      },
      {
        'title': 'Hidratação de Couro',
        'subtitle': 'Especializado',
        'description': 'Limpeza, hidratação e proteção de bancos em couro',
        'icon': Icons.chair_alt,
        'color': Colors.lightBlue,
        'price': 'Preço a combinar',
      },
      {
        'title': 'Enceramento Manual',
        'subtitle': 'Carnaúba Vonixx',
        'description': 'Aplicação de cera de carnaúba natural',
        'icon': Icons.auto_awesome_motion,
        'color': Colors.lightBlue,
        'price': 'R\$ 60,00',
      },
      {
        'title': 'Cristalização de Faróis',
        'subtitle': 'Restauração',
        'description': 'Restauração do brilho original dos faróis',
        'icon': Icons.lightbulb_outline,
        'color': Colors.lightBlue,
        'price': 'Preço a combinar',
      },
      {
        'title': 'Remoção de chuva ácida',
        'subtitle': 'Tratamento Especializado',
        'description': 'Tratamento para remover manchas de chuva ácida',
        'icon': Icons.water_drop,
        'color': Colors.lightBlue,
        'price': 'Preço a combinar',
      },
      {
        'title': 'Lavagem do motor',
        'subtitle': 'Limpeza Segura',
        'description': 'Lavagem segura do compartimento do motor',
        'icon': Icons.settings,
        'color': Colors.lightBlue,
        'price': 'Preço a combinar',
      },
      {
        'title': 'Revitalização de para-choques e plásticos',
        'subtitle': 'Restauração + Proteção',
        'description': 'Restauração da cor original e proteção',
        'icon': Icons.crop_16_9,
        'color': Colors.lightBlue,
        'price': 'Preço a combinar',
      },
      {
        'title': 'Higienização interna com extratora',
        'subtitle': 'Limpeza Profunda',
        'description': 'Limpeza profunda de estofados e carpetes',
        'icon': Icons.chair,
        'color': Colors.lightBlue,
        'price': 'Preço a combinar',
      },
      {
        'title': 'Micropintura',
        'subtitle': 'Correção + Polimento',
        'description': 'Correção de pequenos riscos e arranhões',
        'icon': Icons.brush,
        'color': Colors.lightBlue,
        'price': 'Preço a combinar',
      },
      {
        'title': 'Lavagem por baixo do veículo',
        'description': 'Limpeza completa da parte inferior',
        'icon': Icons.vertical_align_bottom,
        'color': Colors.lightBlue,
        'price': 'Preço a combinar',
      },
    ];

    final List<Map<String, dynamic>> services = [
      ...washingServices,
      ...otherServices,
    ];

    return Scaffold(
      resizeToAvoidBottomInset: true,
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
          if (_isLoadingDistance)
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color.fromRGBO(33, 150, 243, 0.1),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Verificando área de cobertura...',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final service = services[index];
                final isSelected = _selectedIndexes.contains(index);
                final isLevaETrazDisabled = service['title'] == 'Leva e Traz' &&
                    (!_levaETrazAvailable || !_isLevaETrazSelectable());
                final isLavagemDisabled = _isLavagemService(service['title']) &&
                    !isSelected &&
                    _hasLavagemServiceSelected();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    onTap: (isLevaETrazDisabled || isLavagemDisabled)
                        ? null
                        : () => _onServiceTap(index, service),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isLevaETrazDisabled || isLavagemDisabled)
                            ? Colors.grey
                            : service['color'],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        service['icon'],
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Ícone "Saiba mais"
                        IconButton(
                          onPressed: () => _showServiceDetails(service),
                          icon: const Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                            size: 20,
                          ),
                          tooltip: 'Saiba mais sobre este serviço',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Ícone de seleção
                        Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: isSelected ? Colors.blue : Colors.grey,
                          size: 20,
                        ),
                      ],
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            service['title'],
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: (isLevaETrazDisabled || isLavagemDisabled)
                                  ? Colors.grey
                                  : null,
                            ),
                            maxLines: service['title'] ==
                                    'Lavagem Caminhonete com Caçamba'
                                ? 2
                                : 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isLevaETrazDisabled || isLavagemDisabled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              service['title'] == 'Leva e Traz' &&
                                      !_levaETrazAvailable
                                  ? 'Fora da área'
                                  : isLavagemDisabled
                                      ? 'Remova outro serviço'
                                      : 'Selecione um serviço',
                              style: GoogleFonts.poppins(
                                fontSize: 8,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: service['price'] != null
                        ? Text(
                            service['price'],
                            style: GoogleFonts.poppins(
                              color: (isLevaETrazDisabled || isLavagemDisabled)
                                  ? Colors.grey
                                  : service['color'],
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
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
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  onPressed: _selectedIndexes.isEmpty
                      ? null
                      : () {
                          final selectedServices =
                              _selectedIndexes.map((i) => services[i]).toList();

                          // Verificar se há mais de um serviço de lavagem
                          final lavagemServices = selectedServices
                              .where((service) =>
                                  _isLavagemService(service['title']))
                              .toList();

                          if (lavagemServices.length > 1) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Apenas um tipo de lavagem é permitido por agendamento. '
                                    'Remova um dos serviços de lavagem antes de continuar.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

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
