import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      final querySnapshot = await _firestore
          .collection('appointments')
          .where('userId', isEqualTo: user.uid)
          .get();

      final appointments = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      appointments.sort((a, b) {
        final dateA = (a['dateTime'] as Timestamp).toDate();
        final dateB = (b['dateTime'] as Timestamp).toDate();
        return dateB.compareTo(dateA);
      });

      setState(() {
        _appointments = appointments;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar histórico';
          _isLoading = false;
        });
      }
    }
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
                      return Card(
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
                              if (services != null && services.isNotEmpty) ...[
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
                              if (status == 'pending' || status == 'confirmed')
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
                                                  fontWeight: FontWeight.bold)),
                                          content: Text(
                                              'Tem certeza que deseja cancelar este agendamento?',
                                              style: GoogleFonts.poppins()),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context)
                                                      .pop(false),
                                              child: Text('Não',
                                                  style: GoogleFonts.poppins()),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.of(context)
                                                      .pop(true),
                                              child: Text('Sim, Cancelar',
                                                  style: GoogleFonts.poppins()),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await FirebaseFirestore.instance
                                            .collection('appointments')
                                            .doc(appointment['id'])
                                            .update({'status': 'cancelled'});
                                        _loadAppointments();
                                      }
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
