import 'package:flutter/material.dart';
import 'package:ftw_solucoes/services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ServicesScreen extends StatefulWidget {
  final AuthService authService;

  const ServicesScreen({Key? key, required this.authService}) : super(key: key);

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _services = [];

  @override
  void initState() {
    super.initState();
    print('=== DEBUG: ServicesScreen initState ===');
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);

    try {
      final services = await widget.authService.getServiceHistory();
      print('=== DEBUG: Serviços carregados: ${services.length} ===');
      for (int i = 0; i < services.length; i++) {
        print('=== DEBUG: Serviço $i: ${services[i]['title']} ===');
      }

      // DADOS DE TESTE - FORÇAR DADOS PARA TESTE
      if (services.isEmpty) {
        print(
            '=== DEBUG: Nenhum serviço encontrado, usando dados de teste ===');
        final testServices = [
          {
            'title': 'Lavagem Carro Comum',
            'description': 'Lavagem completa externa e interna',
            'date': DateTime.now(),
            'value': 50.0,
            'status': 'concluído',
          },
          {
            'title': 'Polimento',
            'description': 'Polimento e aplicação de cera',
            'date': DateTime.now().subtract(Duration(days: 1)),
            'value': 120.0,
            'status': 'em andamento',
          },
        ];
        setState(() {
          _services = testServices;
          _isLoading = false;
        });
      } else {
        setState(() {
          _services = services;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('=== DEBUG: Erro ao carregar serviços: $e ===');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      setState(() => _isLoading = false);
    }
  }

  // Função para mostrar informações detalhadas do serviço
  void _showServiceDetails(Map<String, dynamic> service) {
    print(
        '=== DEBUG: _showServiceDetails chamado para: ${service['title']} ===');
    final serviceTitle = service['title'] ?? 'Serviço';
    final serviceDescription =
        service['description'] ?? 'Descrição não disponível';
    final serviceDate = _formatDate(service['date']);
    final serviceValue = _formatValue(service['value']);
    final serviceStatus = _getStatusText(service['status']);
    final serviceCar = service['car'] ?? 'Veículo não especificado';
    final serviceTime = service['time'] ?? 'Horário não especificado';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  serviceTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('Descrição:', serviceDescription),
                const SizedBox(height: 12),
                _buildInfoRow('Data:', serviceDate),
                const SizedBox(height: 12),
                _buildInfoRow('Horário:', serviceTime),
                const SizedBox(height: 12),
                _buildInfoRow('Veículo:', serviceCar),
                const SizedBox(height: 12),
                _buildInfoRow('Valor:', 'R\$ $serviceValue'),
                const SizedBox(height: 12),
                _buildInfoRow('Status:', serviceStatus),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: Colors.blue[600],
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Informações Adicionais',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getServiceTips(serviceTitle),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.blue[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Fechar',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Widget para construir uma linha de informação
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  // Função para obter dicas específicas de cada serviço
  String _getServiceTips(String serviceTitle) {
    switch (serviceTitle.toLowerCase()) {
      case 'lavagem':
      case 'lavagem carro comum':
      case 'lavagem caminhonete':
        return '• Duração média: 1 hora\n• Inclui lavagem externa e interna\n• Produtos de qualidade utilizados\n• Secagem completa incluída\n• Limpeza de vidros e rodas';
      case 'espelhamento':
        return '• Duração média: 2-3 horas\n• Remove riscos superficiais\n• Restaura o brilho original\n• Proteção contra novos riscos\n• Aplicação de produtos especiais';
      case 'polimento':
        return '• Duração média: 2-4 horas\n• Remove oxidação e manchas\n• Restaura cor original\n• Aplicação de cera protetora\n• Tratamento de pintura';
      case 'higienização':
        return '• Duração média: 2-3 horas\n• Limpeza profunda do interior\n• Eliminação de odores\n• Tratamento de couro incluído\n• Aspiração completa';
      case 'hidratação de couro':
        return '• Duração média: 1-2 horas\n• Nutrição do couro\n• Prevenção de rachaduras\n• Restauração da maciez\n• Proteção contra desgaste';
      case 'leva e traz':
        return '• Serviço de conveniência\n• Busca e entrega no local\n• Horário flexível\n• Economia de tempo\n• Segurança garantida';
      case 'lavagem caminhonete':
        return '• Duração média: 1-1.5 horas\n• Lavagem completa externa e interna\n• Produtos específicos para caminhonetes\n• Limpeza de caçamba\n• Secagem profissional';
      default:
        return '• Serviço personalizado\n• Qualidade garantida\n• Profissionais experientes\n• Satisfação do cliente\n• Garantia de qualidade';
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
        '=== DEBUG: ServicesScreen build - _isLoading: $_isLoading, _services.length: ${_services.length} ===');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Serviços'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _services.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.work_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum serviço encontrado',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'DEBUG: _services.length = ${_services.length}',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _services.length,
                  itemBuilder: (context, index) {
                    final service = _services[index];
                    print(
                        '=== DEBUG: Renderizando serviço $index: ${service['title']} ===');
                    print('=== DEBUG: Service data: $service ===');
                    print(
                        '=== DEBUG: Criando Container para serviço $index ===');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Título do serviço
                          Text(
                            service['title'] ?? 'Serviço',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Ícone de teste - SEMPRE VISÍVEL
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red, width: 3),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.info_outline,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            service['description'] ?? '',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Data: ${_formatDate(service['date'])}',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'Valor: R\$ ${_formatValue(service['value'])}',
                                style: GoogleFonts.poppins(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pendente':
        return Colors.orange;
      case 'em andamento':
        return Colors.blue;
      case 'concluído':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'pendente':
        return 'Pendente';
      case 'em andamento':
        return 'Em Andamento';
      case 'concluído':
        return 'Concluído';
      case 'cancelado':
        return 'Cancelado';
      default:
        return 'Desconhecido';
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is Timestamp) {
      final dateTime = date.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
    return date.toString();
  }

  String _formatValue(dynamic value) {
    if (value == null) return '0,00';
    if (value is num) {
      return value.toStringAsFixed(2).replaceAll('.', ',');
    }
    return value.toString();
  }
}
