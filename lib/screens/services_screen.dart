import 'package:flutter/material.dart';
import 'package:ftw_solucoes/services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ftw_solucoes/utils/error_handler.dart';

class ServicesScreen extends StatefulWidget {
  final AuthService authService;

  const ServicesScreen({Key? key, required this.authService}) : super(key: key);

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _services = [];

  // Preços atuais (fixos). Serviços "Preço a combinar" continuam vindo do histórico.
  static const Map<String, double> _currentFixedPrices = {
    'Lavagem SUV': 75.0,
    'Lavagem Carro Comum': 65.0,
    'Lavagem Caminhonete': 95.0,
    'Leva e Traz': 20.0,
  };

  double? _getCurrentFixedPrice(Map<String, dynamic> service) {
    final title = service['title'] as String?;
    if (title == null) return null;
    return _currentFixedPrices[title];
  }

  @override
  void initState() {
    super.initState();
    debugPrint('=== DEBUG: ServicesScreen initState ===');
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);

    try {
      final services = await widget.authService.getServiceHistory();
      debugPrint('=== DEBUG: Serviços carregados: ${services.length} ===');
      for (int i = 0; i < services.length; i++) {
        debugPrint('=== DEBUG: Serviço $i: ${services[i]['title']} ===');
      }

      // DADOS DE TESTE - FORÇAR DADOS PARA TESTE
      if (services.isEmpty) {
        debugPrint(
            '=== DEBUG: Nenhum serviço encontrado, usando dados de teste ===');
        final testServices = [
          {
            'title': 'Lavagem Carro Comum',
            'description': 'Lavagem completa externa e interna',
            'date': DateTime.now(),
            'value': 65.0,
            'status': 'concluído',
          },
          {
            'title': 'Polimento',
            'description': 'Polimento e aplicação de cera',
            'date': DateTime.now().subtract(const Duration(days: 1)),
            'value': null, // Preço a combinar
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
      debugPrint('=== DEBUG: Erro ao carregar serviços: $e ===');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorHandler.getFriendlyErrorMessage(e)),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  // Widget para construir uma linha de informação

  // Função para obter dicas específicas de cada serviço

  @override
  Widget build(BuildContext context) {
    debugPrint(
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
                      const Text(
                        'Nenhum serviço encontrado',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'DEBUG: _services.length = ${_services.length}',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _services.length,
                  itemBuilder: (context, index) {
                    final service = _services[index];
                    debugPrint(
                        '=== DEBUG: Renderizando serviço $index: ${service['title']} ===');
                    debugPrint('=== DEBUG: Service data: $service ===');
                    debugPrint(
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
                            child: const Center(
                              child: Icon(
                                Icons.info_outline,
                                color: Colors.orange,
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
                                'Valor: ${_formatDisplayPrice(service)}',
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

  String _formatDisplayPrice(Map<String, dynamic> service) {
    final fixed = _getCurrentFixedPrice(service);
    if (fixed != null) {
      return 'R\$ ${fixed.toStringAsFixed(2).replaceAll('.', ',')}';
    }

    final value = service['value'];
    if (value == null) return 'Preço a combinar';
    return 'R\$ ${_formatValue(value)}';
  }
}
