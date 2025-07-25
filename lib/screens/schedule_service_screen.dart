import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../services/auth_service.dart';
import 'payment_screen.dart';
import 'cars_screen.dart';

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

  final List<String> _timeSlots = [];
  late DateFormat _dateFormat;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Mapa de preços dos serviços
  static const Map<String, double> _servicePrices = {
    'Lavagem': 50.0,
    'Espelhamento': 120.0,
    'Polimento': 150.0,
    'Higienização': 100.0,
    'Hidratação de Couro': 180.0,
    'Leva e Traz': 30.0,
  };

  int _totalDurationMinutes = 0;
  String _serviceTitles = '';
  Color _mainColor = Colors.blue;
  IconData _mainIcon = Icons.build;

  _ScheduleServiceScreenState()
      : _totalDurationMinutes = 0,
        _serviceTitles = '',
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
    _totalDurationMinutes = _calculateTotalDuration(widget.services);
    _serviceTitles = widget.services.map((s) => s['title']).join(', ');
    _mainColor = widget.services.first['color'] ?? Colors.blue;
    _mainIcon = widget.services.first['icon'] ?? Icons.build;
    _initializeDateFormatting();
    _generateTimeSlots();
    _loadBookedTimeSlots();
    _loadUserCars();
  }

  int _calculateTotalDuration(List<Map<String, dynamic>> services) {
    int total = 0;
    for (final s in services) {
      final title = (s['title'] as String).toLowerCase();
      if (title.contains('lavagem')) {
        total += 60;
      } else {
        total += 120;
      }
    }
    return total;
  }

  Future<void> _initializeDateFormatting() async {
    await initializeDateFormatting('pt_BR', null);
    _dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');
  }

  void _generateTimeSlots() {
    _timeSlots.clear();
    final startTime = DateTime(2024, 1, 1, 8, 0);
    final endTime = DateTime(2024, 1, 1, 17, 0);
    final step = const Duration(minutes: 30);
    final block = Duration(minutes: _totalDurationMinutes);

    DateTime currentSlot = startTime;
    while (currentSlot.add(block).isBefore(endTime.add(step)) ||
        currentSlot.add(block).isAtSameMomentAs(endTime)) {
      _timeSlots.add(DateFormat('HH:mm').format(currentSlot));
      currentSlot = currentSlot.add(step);
    }
  }

  // Função para verificar se o bloco está livre
  bool _isBlockAvailable(DateTime start, Map<String, String> bookedSlots) {
    final block = Duration(minutes: _totalDurationMinutes);
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

      // Montar lista de serviços com título, tipo e duração
      final List<Map<String, dynamic>> servicesToSave =
          widget.services.map((s) {
        final title = (s['title'] as String);
        final isLavagem = title.toLowerCase().contains('lavagem');
        return {
          'title': title,
          'type': isLavagem ? 'lavagem' : 'outro',
          'duration': isLavagem ? 60 : 120, // minutos
        };
      }).toList();

      // Salvar agendamento único e obter o id
      final docRef =
          await FirebaseFirestore.instance.collection('appointments').add({
        'userId': user.uid,
        'car': _selectedCar,
        'services': servicesToSave,
        'dateTime': dateTime,
        'duration': _totalDurationMinutes,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Calcular valor total dos serviços
      double totalAmount = 0;
      for (final s in widget.services) {
        final title = (s['title'] as String).toLowerCase();
        if (title.contains('lavagem')) {
          totalAmount += 50.0;
        } else if (title == 'leva e traz') {
          totalAmount += 30.0;
        } else if (title == 'espelhamento') {
          totalAmount += 120.0;
        } else if (title == 'polimento') {
          totalAmount += 150.0;
        } else if (title == 'higienização') {
          totalAmount += 100.0;
        } else if (title == 'hidratação de couro') {
          totalAmount += 180.0;
        } else {
          totalAmount += 100.0;
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentScreen(
              amount: totalAmount,
              serviceTitle: _serviceTitles,
              serviceDescription: 'Agendamento de $_serviceTitles',
              carId: _selectedCar!['id'],
              carModel: _selectedCar!['model'],
              carPlate: _selectedCar!['plate'],
              appointmentId: docRef.id,
            ),
          ),
        );
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
                                  const SizedBox(height: 8),
                                  Text(
                                    'Duração total: ${(_totalDurationMinutes / 60).floor()}h${_totalDurationMinutes % 60 != 0 ? ' ${_totalDurationMinutes % 60}min' : ''}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _mainColor,
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
