import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../services/auth_service.dart';
import 'payment_screen.dart';
import 'cars_screen.dart';
import 'home_screen.dart';

class ScheduleServiceScreen extends StatefulWidget {
  final List<Map<String, dynamic>> services;
  final AuthService authService;

  const ScheduleServiceScreen({
    super.key,
    required this.services,
    required this.authService,
  });

  @override
  State<ScheduleServiceScreen> createState() => _ScheduleServiceScreenState();
}

class _ScheduleServiceScreenState extends State<ScheduleServiceScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedTime;
  bool _isLoading = false;
  Map<String, String> _bookedTimeSlots = {};
  Map<String, dynamic>? _selectedCar;
  List<Map<String, dynamic>> _userCars = [];

  // Variável para opcional de cera (apenas uma seleção)
  String? _selectedCera;

  final List<String> _timeSlots = [];
  late DateFormat _dateFormat;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Mapa de preços dos serviços
  static const Map<String, double> _servicePrices = {
    'Lavagem SUV': 80.0,
    'Lavagem Carro Comum': 70.0,
    'Lavagem Caminhonete': 100.0,
    'Leva e Traz': 20.0,
  };

  String _serviceTitles = '';
  Color _mainColor = Colors.blue;
  IconData _mainIcon = Icons.build;

  _ScheduleServiceScreenState()
      : _serviceTitles = '',
        _mainColor = Colors.blue,
        _mainIcon = Icons.build;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Não reatribuir as variáveis aqui
  }

  @override
  void initState() {
    super.initState();
    _serviceTitles = widget.services.map((s) => s['title']).join(', ');
    _mainColor = widget.services.first['color'] ?? Colors.blue;
    _mainIcon = widget.services.first['icon'] ?? Icons.build;
    _initializeDateFormatting();
    _generateTimeSlots();
    _loadBookedTimeSlots();
    _loadUserCars();
  }

  double _calculateTotalValue() {
    double total = 0;

    // Calcular valor dos serviços
    for (final service in widget.services) {
      final title = service['title'] as String;
      if (_servicePrices.containsKey(title)) {
        total += _servicePrices[title]!;
      }
    }

    // Adicionar opcional de cera (apenas para serviços de lavagem)
    bool hasWashingService = widget.services.any((service) {
      final title = (service['title'] as String).toLowerCase();
      return (title.contains('lavagem suv') ||
              title.contains('lavagem carro comum') ||
              title.contains('lavagem caminhonete')) &&
          !title.contains('leva e traz');
    });

    if (hasWashingService && _selectedCera != null) {
      if (_selectedCera == 'carnauba') total += 30.0; // Preço invertido
      if (_selectedCera == 'jetcera') total += 10.0; // Preço invertido
    }

    return total;
  }

  bool _hasServicesWithPrice() {
    for (final service in widget.services) {
      final title = service['title'] as String;
      if (_servicePrices.containsKey(title)) {
        return true;
      }
    }
    return false;
  }

  bool _hasWashingServices() {
    return widget.services.any((service) {
      final title = (service['title'] as String).toLowerCase();
      return (title.contains('lavagem suv') ||
              title.contains('lavagem carro comum') ||
              title.contains('lavagem caminhonete')) &&
          !title.contains('leva e traz');
    });
  }

  Future<void> _initializeDateFormatting() async {
    await initializeDateFormatting('pt_BR', null);
    _dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');
  }

  void _generateTimeSlots() {
    _timeSlots.clear();
    final startTime = DateTime(2024, 1, 1, 8, 0);
    final endTime = DateTime(2024, 1, 1, 17, 0);
    const step = Duration(minutes: 30);
    const block = Duration(minutes: 120); // Duração fixa de 2 horas

    DateTime currentSlot = startTime;
    while (currentSlot.add(block).isBefore(endTime.add(step)) ||
        currentSlot.add(block).isAtSameMomentAs(endTime)) {
      _timeSlots.add(DateFormat('HH:mm').format(currentSlot));
      currentSlot = currentSlot.add(step);
    }
  }

  // Função para verificar se o bloco está livre
  bool _isBlockAvailable(DateTime start, Map<String, String> bookedSlots) {
    const block = Duration(minutes: 120); // Duração fixa de 2 horas
    DateTime check = start;
    while (check.isBefore(start.add(block))) {
      final slotStr = DateFormat('HH:mm').format(check);
      if (bookedSlots.containsKey(slotStr)) {
        return false;
      }
      check = check.add(const Duration(minutes: 30));
    }
    return true;
  }

  Future<void> _loadBookedTimeSlots() async {
    setState(() => _isLoading = true);
    try {
      final startOfDay = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      final endOfDay = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        23,
        59,
        59,
      );

      debugPrint(
          'Checando compromissos entre ${startOfDay.toString()} e ${endOfDay.toString()}');

      final querySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('dateTime', isGreaterThanOrEqualTo: startOfDay)
          .where('dateTime', isLessThan: endOfDay)
          .get();

      debugPrint('Encontrado ${querySnapshot.docs.length} compromissos');

      final Map<String, String> bookedSlots = {};
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data['status'] == 'scheduled') {
          final dateTime = (data['dateTime'] as Timestamp).toDate();
          dynamic serviceField = data['service'];
          String service;
          if (serviceField == null) {
            service = 'Serviço';
          } else if (serviceField is List) {
            // Novo formato: lista de serviços
            service = serviceField.isNotEmpty &&
                    serviceField[0] is Map &&
                    serviceField[0]['title'] != null
                ? serviceField[0]['title'] as String
                : 'Serviço';
          } else {
            service = serviceField as String;
          }
          final timeSlot = DateFormat('HH:mm').format(dateTime);
          bookedSlots[timeSlot] = service;
          debugPrint('Booked slot: $timeSlot for service: $service');
        }
      }

      setState(() {
        _bookedTimeSlots = bookedSlots;
      });
    } catch (e) {
      debugPrint('Erro ao carregar horários : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar horários: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserCars() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final snapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('cars')
            .orderBy('createdAt', descending: true)
            .get();

        setState(() {
          _userCars = snapshot.docs
              .map((doc) => {...doc.data(), 'id': doc.id})
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading cars: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar carros: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      locale: const Locale('pt', 'BR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _mainColor,
            ),
          ),
          child: child!,
        );
      },
      selectableDayPredicate: (date) {
        // Retorna false para domingos (weekday == 7)
        return date.weekday != DateTime.sunday;
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null;
      });
      _loadBookedTimeSlots();
    }
  }

  Future<void> _scheduleService() async {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione um horário'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedCar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione um carro'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      final timeParts = _selectedTime!.split(':');
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );

      // Montar lista de serviços com título e tipo
      final List<Map<String, dynamic>> servicesToSave =
          widget.services.map((s) {
        final title = (s['title'] as String);
        final isLavagem = title.toLowerCase().contains('lavagem');
        return {
          'title': title,
          'type': isLavagem ? 'lavagem' : 'outro',
        };
      }).toList();

      // Adicionar opcionais selecionados
      Map<String, dynamic>? optionalServices;
      if (widget.services.any((service) {
        final title = (service['title'] as String).toLowerCase();
        return (title.contains('lavagem suv') ||
                title.contains('lavagem carro comum') ||
                title.contains('lavagem caminhonete')) &&
            !title.contains('leva e traz');
      })) {
        optionalServices = {
          'selectedCera': _selectedCera,
        };
      }

      // Calcular valor total dos serviços incluindo opcionais
      double totalAmount = _calculateTotalValue();

      // Determinar status baseado no valor
      String appointmentStatus = 'pending';
      if (totalAmount == 0) {
        appointmentStatus = 'no_payment';
      }

      // Salvar agendamento único e obter o id
      final appointmentData = {
        'userId': user.uid,
        'car': _selectedCar,
        'services': servicesToSave,
        'dateTime': dateTime,
        'status': appointmentStatus,
        'amount': totalAmount > 0 ? totalAmount : null,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Adicionar opcionais se existirem
      if (optionalServices != null) {
        appointmentData['optionalServices'] = optionalServices;
      }

      final docRef = await FirebaseFirestore.instance
          .collection('appointments')
          .add(appointmentData);

      if (mounted) {
        // Verificar se há serviços com valor para determinar o fluxo
        if (_hasServicesWithPrice() && totalAmount > 0) {
          // Redirecionar para tela de pagamento
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentScreen(
                amount: totalAmount,
                serviceTitle: _serviceTitles,
                serviceDescription: widget.services
                    .map((s) => s['description'] as String)
                    .join(', '),
                carId: _selectedCar!['id'],
                carModel: _selectedCar!['model'],
                carPlate: _selectedCar!['plate'],
                appointmentId: docRef.id,
              ),
            ),
          );
        } else {
          // Mostrar dialog de sucesso para serviços sem valor
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Agendamento Realizado!',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seu agendamento foi realizado com sucesso!',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detalhes do Agendamento:',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Serviços: $_serviceTitles',
                            style: GoogleFonts.poppins(fontSize: 14),
                            overflow: TextOverflow.visible,
                          ),
                          Text(
                            '• Data: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                          Text(
                            '• Horário: $_selectedTime',
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                          Text(
                            '• Carro: ${_selectedCar!['model']} - ${_selectedCar!['plate']}',
                            style: GoogleFonts.poppins(fontSize: 14),
                            overflow: TextOverflow.visible,
                          ),
                          Text(
                            '• Valor: Preço a combinar',
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Você pode acompanhar o status do seu agendamento na página "Meus Agendamentos".',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Fechar dialog
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) =>
                            HomeScreen(authService: widget.authService),
                      ),
                      (route) => false, // Remove todas as rotas anteriores
                    );
                  },
                  child: Text(
                    'Voltar ao Início',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: _mainColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error scheduling service: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao agendar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Agendar Serviços',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _mainColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBookedTimeSlots,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _mainColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _mainIcon,
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
                                    _serviceTitles,
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Selecione a data e horário desejados',
                                    style: GoogleFonts.poppins(
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Selecione o Carro',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_userCars.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.directions_car_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Nenhum carro cadastrado',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const CarsScreen(),
                                    ),
                                  );
                                  if (result == true) {
                                    _loadUserCars();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _mainColor,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(
                                  'Adicionar Carro',
                                  style: GoogleFonts.poppins(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          ..._userCars.map((car) {
                            final isSelected = car['id'] == _selectedCar?['id'];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedCar = car;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Checkbox(
                                          value: isSelected,
                                          onChanged: (bool? value) {
                                            setState(() {
                                              _selectedCar =
                                                  value! ? car : null;
                                            });
                                          },
                                          activeColor: _mainColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              car['name'],
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              '${car['model']} - ${car['plate']}',
                                              style: GoogleFonts.poppins(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CarsScreen(),
                                ),
                              );
                              if (result == true) {
                                _loadUserCars();
                              }
                            },
                            icon: Icon(
                              Icons.add,
                              color: _mainColor,
                            ),
                            label: Text(
                              'Adicionar outro carro',
                              style: GoogleFonts.poppins(
                                color: _mainColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    // Seção de opcionais (apenas para serviços de lavagem)
                    if (_hasWashingServices()) ...[
                      Text(
                        'Opcionais',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Adicionais de Cera',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _mainColor,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Radio<String>(
                                    value: 'carnauba',
                                    groupValue: _selectedCera,
                                    onChanged: (String? value) {
                                      setState(() {
                                        _selectedCera = value;
                                      });
                                    },
                                    activeColor: _mainColor,
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Cera de Carnaúba',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '+R\$ 30,00',
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Radio<String>(
                                    value: 'jetcera',
                                    groupValue: _selectedCera,
                                    onChanged: (String? value) {
                                      setState(() {
                                        _selectedCera = value;
                                      });
                                    },
                                    activeColor: _mainColor,
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Jet-Cera',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '+R\$ 10,00',
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _mainColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _mainColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.orange,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Selecione apenas um tipo de cera',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: _mainColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      'Data',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _dateFormat.format(_selectedDate),
                              style: GoogleFonts.poppins(fontSize: 16),
                            ),
                            Icon(
                              Icons.calendar_today,
                              color: _mainColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Horário',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _timeSlots.length,
                      itemBuilder: (context, index) {
                        final timeSlot = _timeSlots[index];
                        final isSelected = timeSlot == _selectedTime;
                        final slotTime = DateTime(
                          _selectedDate.year,
                          _selectedDate.month,
                          _selectedDate.day,
                          int.parse(timeSlot.split(':')[0]),
                          int.parse(timeSlot.split(':')[1]),
                        );
                        final isAvailable =
                            _isBlockAvailable(slotTime, _bookedTimeSlots);
                        if (!isAvailable) return const SizedBox.shrink();
                        return Tooltip(
                          message: 'Disponível',
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedTime = timeSlot;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? _mainColor : Colors.white,
                                border: Border.all(
                                  color: isSelected
                                      ? _mainColor
                                      : Colors.grey.shade300,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  timeSlot,
                                  style: GoogleFonts.poppins(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    // Seção de valor total
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _mainColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _mainColor.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_hasServicesWithPrice()) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Valor Total',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'R\$ ${_calculateTotalValue().toStringAsFixed(2).replaceAll('.', ',')}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: _mainColor,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Preço será definido após avaliação do veículo - agendamento sem pagamento',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.orange[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (widget.services.any((service) {
                            final title =
                                (service['title'] as String).toLowerCase();
                            return (title.contains('lavagem suv') ||
                                    title.contains('lavagem carro comum') ||
                                    title.contains('lavagem caminhonete')) &&
                                !title.contains('leva e traz');
                          })) ...[
                            if (_selectedCera != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _selectedCera == 'carnauba'
                                    ? '• Cera de Carnaúba (+R\$ 30,00)'
                                    : '• Jet-Cera (+R\$ 10,00)',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: _mainColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(0, 0, 0, 0).withValues(),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _scheduleService,
          style: ElevatedButton.styleFrom(
            backgroundColor: _mainColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.transparent),
                  ),
                )
              : Text(
                  'Confirmar Agendamento',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}
