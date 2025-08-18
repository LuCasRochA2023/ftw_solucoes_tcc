import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'schedule_service_screen.dart';
import '../services/auth_service.dart';

class ServiceHistoryScreen extends StatefulWidget {
  const ServiceHistoryScreen({super.key});

  @override
  State<ServiceHistoryScreen> createState() => _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends State<ServiceHistoryScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _appointments = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error!)),
      );
      _error = null;
    }
  }

  Future<void> _loadAppointments() async {
    print('=== DEBUG: Iniciando carregamento de agendamentos ===');
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      print('=== DEBUG: Usuário autenticado: ${user.uid} ===');

      // Primeiro tentar com orderBy, se falhar, buscar sem ordenação
      QuerySnapshot querySnapshot;
      try {
        querySnapshot = await _firestore
            .collection('appointments')
            .where('userId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .get();
        print('=== DEBUG: Consulta com orderBy executada com sucesso ===');
      } catch (e) {
        print(
            '=== DEBUG: Erro na consulta com orderBy, tentando sem ordenação: $e ===');
        querySnapshot = await _firestore
            .collection('appointments')
            .where('userId', isEqualTo: user.uid)
            .get();
        print('=== DEBUG: Consulta sem orderBy executada com sucesso ===');
      }

      print(
          '=== DEBUG: Consulta executada, documentos encontrados: ${querySnapshot.docs.length} ===');

      final appointments = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        print(
            '=== DEBUG: Agendamento carregado: ${doc.id} - Status: ${data['status']} ===');
        return data;
      }).toList();

      print(
          '=== DEBUG: Total de agendamentos processados: ${appointments.length} ===');

      // Ordenar por createdAt se disponível, caso contrário por dateTime
      appointments.sort((a, b) {
        final createdAtA = a['createdAt'] as Timestamp?;
        final createdAtB = b['createdAt'] as Timestamp?;

        if (createdAtA != null && createdAtB != null) {
          return createdAtB.compareTo(createdAtA);
        } else {
          // Fallback para dateTime se createdAt não estiver disponível
          final dateTimeA = a['dateTime'] as Timestamp?;
          final dateTimeB = b['dateTime'] as Timestamp?;

          if (dateTimeA != null && dateTimeB != null) {
            return dateTimeB.compareTo(dateTimeA);
          }
        }
        return 0;
      });

      setState(() {
        _appointments = appointments;
        _isLoading = false;
      });

      print(
          '=== DEBUG: Estado atualizado, _appointments.length: ${_appointments.length} ===');
    } catch (e) {
      print('=== DEBUG: Erro ao carregar agendamentos: $e ===');
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar histórico: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cancelAppointment(Map<String, dynamic> appointment) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Atualizar status do agendamento
      await _firestore
          .collection('appointments')
          .doc(appointment['id'])
          .update({'status': 'cancelled'});

      // Verificar se o serviço foi pago e adicionar saldo
      final status = appointment['status'] as String?;
      final amount = appointment['amount'] as double?;

      if ((status == 'confirmed' || status == 'pending') &&
          amount != null &&
          amount > 0) {
        // Adicionar saldo ao usuário
        final userRef = _firestore.collection('users').doc(user.uid);

        await _firestore.runTransaction((transaction) async {
          final userDoc = await transaction.get(userRef);
          final currentBalance = (userDoc.data()?['balance'] ?? 0.0).toDouble();
          final newBalance = currentBalance + amount;

          transaction.update(userRef, {'balance': newBalance});

          // Registrar transação
          final transactionRef = _firestore.collection('transactions').doc();
          transaction.set(transactionRef, {
            'userId': user.uid,
            'amount': amount,
            'type': 'credit',
            'description': 'Reembolso - Cancelamento de serviço',
            'appointmentId': appointment['id'],
            'createdAt': FieldValue.serverTimestamp(),
          });
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Serviço cancelado. R\$ ${amount.toStringAsFixed(2)} adicionado ao seu saldo.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Serviço cancelado com sucesso.'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erro ao cancelar agendamento: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao cancelar agendamento: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleAppointmentTap(Map<String, dynamic> appointment) {
    final status = appointment['status'] as String? ?? 'unknown';

    if (status == 'pending') {
      _showRescheduleDialog(appointment);
    }
  }

  void _showRescheduleDialog(Map<String, dynamic> appointment) {
    final services = appointment['services'] as List?;
    String serviceTitles = '';
    if (services != null && services.isNotEmpty) {
      serviceTitles = services.map((s) => s['title'] ?? 'Serviço').join(', ');
    }

    final amount = appointment['amount'] as double? ?? 0.0;
    final carData = appointment['car'] as Map<String, dynamic>?;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.schedule,
              color: Colors.orange[700],
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Reagendar Serviço',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deseja reagendar este serviço? O agendamento anterior será substituído.',
              style: GoogleFonts.poppins(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detalhes do Agendamento:',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Serviços: $serviceTitles',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  if (carData != null) ...[
                    Text(
                      'Carro: ${carData['name'] ?? 'N/A'} - ${carData['plate'] ?? 'N/A'}',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ],
                  Text(
                    'Valor: R\$ ${amount.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToReschedule(appointment);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Reagendar',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToReschedule(Map<String, dynamic> appointment) {
    final services = appointment['services'] as List?;
    if (services == null || services.isEmpty) return;

    // Converter serviços para o formato esperado pelo ScheduleServiceScreen
    final List<Map<String, dynamic>> servicesList = services.map((service) {
      return {
        'title': service['title'] ?? 'Serviço',
        'description': service['description'] ?? '',
        'price': appointment['amount'] ?? 0.0,
      };
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduleServiceScreen(
          services: servicesList,
          authService: AuthService(),
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pendente';
      case 'confirmed':
        return 'Confirmado';
      case 'completed':
        return 'Concluído';
      case 'cancelled':
        return 'Cancelado';
      case 'no_payment':
        return 'Sem Pagamento';
      default:
        return 'Desconhecido';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'no_payment':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  List<String> _getOptionalServicesText(Map<String, dynamic> optionalServices) {
    List<String> texts = [];

    if (optionalServices['selectedCera'] != null) {
      final selectedCera = optionalServices['selectedCera'] as String;
      switch (selectedCera) {
        case 'carnauba':
          texts.add('- Cera de Carnaúba (+R\$ 30,00)');
          break;
        case 'jetcera':
          texts.add('- Jet-Cera (+R\$ 10,00)');
          break;
        default:
          texts.add('- Cera: $selectedCera');
      }
    }

    return texts;
  }

  @override
  Widget build(BuildContext context) {
    print(
        '=== DEBUG: Build executado - _isLoading: $_isLoading, _appointments.length: ${_appointments.length}, _error: $_error ===');
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Histórico de Serviços',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _appointments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum serviço encontrado',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAppointments,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _appointments.length,
                    itemBuilder: (context, index) {
                      final appointment = _appointments[index];
                      final dateTime =
                          (appointment['dateTime'] as Timestamp).toDate();
                      final carData = appointment['car'];
                      final services = appointment['services'] as List?;
                      String serviceTitles = '';
                      if (services != null && services.isNotEmpty) {
                        serviceTitles = services
                            .map((s) => s['title'] ?? 'Serviço')
                            .join(', ');
                      } else {
                        serviceTitles =
                            appointment['service'] as String? ?? 'Serviço';
                      }
                      final status =
                          appointment['status'] as String? ?? 'unknown';
                      String statusText = _getStatusText(status);
                      Color statusColor = _getStatusColor(status);
                      IconData statusIcon;
                      switch (status) {
                        case 'pending':
                          statusIcon = Icons.access_time;
                          break;
                        case 'confirmed':
                          statusIcon = Icons.check_circle;
                          break;
                        case 'completed':
                          statusIcon = Icons.star;
                          break;
                        case 'cancelled':
                          statusIcon = Icons.cancel;
                          break;
                        case 'no_payment':
                          statusIcon = Icons.schedule;
                          break;
                        default:
                          statusIcon = Icons.info;
                      }
                      return InkWell(
                        onTap: () => _handleAppointmentTap(appointment),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  serviceTitles,
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(statusIcon,
                                          color: statusColor, size: 18),
                                      const SizedBox(width: 4),
                                      Text(
                                        statusText,
                                        style: GoogleFonts.poppins(
                                          color: statusColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Data/Hora: ${DateFormat('dd/MM/yyyy HH:mm').format(dateTime)}',
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey[700],
                                  ),
                                ),
                                if (carData != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Carro: ${(carData as Map<String, dynamic>)['name'] ?? 'N/A'} - ${(carData)['plate'] ?? 'N/A'}',
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                                if (services != null &&
                                    services.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Serviços:',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  ...services.map((s) => Padding(
                                        padding: const EdgeInsets.only(
                                            left: 8, top: 2),
                                        child: Text(
                                          '- ${s['title'] ?? 'Serviço'}',
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      )),
                                ],

                                // Exibir adicionais se houver
                                if (appointment['optionalServices'] != null &&
                                    appointment['optionalServices']
                                        is Map<String, dynamic>) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.add_circle_outline,
                                        size: 16,
                                        color: Colors.blue[700],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Adicionais:',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  ..._getOptionalServicesText(
                                          appointment['optionalServices']
                                              as Map<String, dynamic>)
                                      .map((text) => Padding(
                                            padding: const EdgeInsets.only(
                                                left: 8, top: 2),
                                            child: Text(
                                              text,
                                              style: GoogleFonts.poppins(
                                                color: Colors.blue[700],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          )),
                                ],
                                const SizedBox(height: 4),
                                // Informações sobre valor e pagamento
                                if (appointment['amount'] != null) ...[
                                  Text(
                                    'Valor: R\$ ${(appointment['amount'] as double).toStringAsFixed(2).replaceAll('.', ',')}',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ] else ...[
                                  Text(
                                    'Valor: Preço a combinar',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                ],
                                if (status == 'pending' ||
                                    status == 'confirmed')
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      icon: const Icon(Icons.cancel,
                                          color: Colors.red),
                                      label: Text('Cancelar',
                                          style: GoogleFonts.poppins(
                                              color: Colors.red)),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text('Cancelar Agendamento',
                                                style: GoogleFonts.poppins(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            content: Text(
                                                'Tem certeza que deseja cancelar este agendamento?',
                                                style: GoogleFonts.poppins()),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(context)
                                                        .pop(false),
                                                child: Text('Não',
                                                    style:
                                                        GoogleFonts.poppins()),
                                              ),
                                              ElevatedButton(
                                                onPressed: () =>
                                                    Navigator.of(context)
                                                        .pop(true),
                                                child: Text('Sim, Cancelar',
                                                    style:
                                                        GoogleFonts.poppins()),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await _cancelAppointment(appointment);
                                          _loadAppointments();
                                        }
                                      },
                                    ),
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
