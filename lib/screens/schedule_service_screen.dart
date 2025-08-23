import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  DateTime _selectedDate = _getNextAvailableDate(DateTime.now());
  String? _selectedTime;
  bool _isLoading = false;
  Map<String, String> _bookedTimeSlots = {};
  Map<String, dynamic>? _selectedCar;
  List<Map<String, dynamic>> _userCars = [];
  final TextEditingController _balanceAmountController =
      TextEditingController();

  // Função para obter a próxima data disponível (não domingo)
  static DateTime _getNextAvailableDate(DateTime date) {
    DateTime currentDate = date;
    while (currentDate.weekday == DateTime.sunday) {
      currentDate = currentDate.add(const Duration(days: 1));
    }
    return currentDate;
  }

  // Variável para opcional de cera (apenas uma seleção)
  String? _selectedCera;

  final List<String> _timeSlots = [];
  DateFormat? _dateFormat;
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
    _initializeAsync();
  }

  void _initializeAsync() async {
    _serviceTitles = widget.services.map((s) => s['title']).join(', ');
    _mainColor = widget.services.first['color'] ?? Colors.blue;
    _mainIcon = widget.services.first['icon'] ?? Icons.build;
    await _initializeDateFormatting();
    await _generateTimeSlots();
    await _loadBookedTimeSlots();
    await _loadUserCars();
    if (mounted) {
      setState(() {}); // Atualiza a UI apenas uma vez após toda inicialização
    }
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

  Future<void> _generateTimeSlots() async {
    _timeSlots.clear();
    try {
      // Buscar horários disponíveis do Firebase
      final snapshot = await _firestore
          .collection('disponibilidade_clientes')
          .where('isAvailableForClients', isEqualTo: true)
          .get();

      final Set<String> availableSlots = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final date = data['date'] as String;
        final startTime = data['startTime'] as String;

        // Verificar se é para a data selecionada
        final selectedDateStr =
            '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
        if (date == selectedDateStr) {
          availableSlots.add(startTime);
        }
      }

      // Adicionar horários disponíveis
      _timeSlots.addAll(availableSlots.toList());
      _timeSlots.sort();

      // Se não há horários disponíveis, mostrar mensagem
      if (_timeSlots.isEmpty) {
        debugPrint(
            'Nenhum horário disponível encontrado para a data selecionada');
        // Não usar fallback - deixar a lista vazia para mostrar que não há disponibilidade
      }
    } catch (e) {
      debugPrint('Erro ao carregar horários: $e');
      // Fallback: horários padrão se houver erro
      _generateFallbackTimeSlots();
    }
  }

  void _generateFallbackTimeSlots() {
    _timeSlots.clear();
    final startTime = DateTime(2024, 1, 1, 8, 0);
    final endTime = DateTime(2024, 1, 1, 17, 0);
    const step = Duration(minutes: 30);
    const block = Duration(minutes: 120);

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
    if (!mounted) return;

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

      if (mounted) {
        setState(() {
          _bookedTimeSlots = bookedSlots;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar horários : $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar horários: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadUserCars() async {
    if (!mounted) return;

    try {
      final user = _auth.currentUser;
      if (user != null) {
        final snapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('cars')
            .orderBy('createdAt', descending: true)
            .get();

        if (mounted) {
          setState(() {
            _userCars = snapshot.docs
                .map((doc) => {...doc.data(), 'id': doc.id})
                .toList();
          });
        }
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
      initialDate: _getNextAvailableDate(_selectedDate),
      firstDate: _getNextAvailableDate(DateTime.now()),
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
      await _generateTimeSlots();
      await _loadBookedTimeSlots();
      if (mounted) {
        setState(() {}); // Força atualização da UI

        // Mostrar mensagem se não há horários disponíveis
        if (_timeSlots.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Nenhum horário disponível para ${_dateFormat?.format(picked) ?? 'esta data'}'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
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

    // Verificar saldo antes de agendar
    await _checkBalanceAndSchedule();
  }

  Future<void> _checkBalanceAndSchedule() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      // Buscar saldo do usuário
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final currentBalance = (userDoc.data()?['balance'] ?? 0.0).toDouble();
      final totalAmount = _calculateTotalValue();

      // Se não há valor para pagar, agendar normalmente
      if (totalAmount <= 0) {
        await _proceedWithSchedulingAndGetId();
        return;
      }

      // Se há saldo, mostrar pop-up de uso do saldo
      if (currentBalance > 0) {
        setState(() => _isLoading = false);
        await _showBalanceUsageDialog(currentBalance, totalAmount);
      } else {
        // Se não há saldo, agendar normalmente
        await _proceedWithSchedulingAndGetId();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao verificar saldo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showBalanceUsageDialog(
      double currentBalance, double totalAmount) async {
    // Inicializar o controller com o valor máximo disponível (não pode exceder o valor total)
    final maxBalanceToUse =
        currentBalance > totalAmount ? totalAmount : currentBalance;
    _balanceAmountController.text = maxBalanceToUse.toStringAsFixed(2);

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.account_balance_wallet,
              color: _mainColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Usar Saldo Disponível',
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
                'Você tem saldo disponível! Quanto deseja usar para este agendamento?',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),

              // Campo para editar valor do saldo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Valor do saldo a usar:',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _balanceAmountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        prefixText: 'R\$ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        hintText: '0,00',
                        suffixText:
                            'de R\$ ${(currentBalance > totalAmount ? totalAmount : currentBalance).toStringAsFixed(2)}',
                        suffixStyle: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}')),
                        // Limitar o valor máximo que pode ser digitado
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          final newValueText = newValue.text;
                          if (newValueText.isEmpty) return newValue;

                          final newValueDouble = double.tryParse(newValueText);
                          if (newValueDouble == null) return oldValue;

                          // Limitar ao valor máximo (mínimo entre saldo e valor total)
                          final maxValue = currentBalance > totalAmount
                              ? totalAmount
                              : currentBalance;
                          if (newValueDouble > maxValue) {
                            return TextEditingValue(
                              text: maxValue.toStringAsFixed(2),
                              selection: TextSelection.collapsed(
                                  offset: maxValue.toStringAsFixed(2).length),
                            );
                          }

                          return newValue;
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Card de informações
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Builder(
                  builder: (context) {
                    // Calcular valores baseados no input do usuário
                    final balanceToUse =
                        double.tryParse(_balanceAmountController.text) ?? 0.0;
                    final clampedBalance =
                        balanceToUse.clamp(0.0, currentBalance);
                    final actualRemainingAmount = totalAmount - clampedBalance;
                    final actualFinalBalance = currentBalance - clampedBalance;

                    return Column(
                      children: [
                        // Valor total do serviço
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Valor do serviço:',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'R\$ ${totalAmount.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Saldo a usar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Saldo a usar:',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[700],
                              ),
                            ),
                            Text(
                              'R\$ ${clampedBalance.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Saldo restante
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Saldo restante:',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'R\$ ${actualFinalBalance.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),

                        // Resultado
                        if (actualRemainingAmount > 0) ...[
                          // Precisa pagar mais
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Valor restante:',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[700],
                                ),
                              ),
                              Text(
                                'R\$ ${actualRemainingAmount.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[700],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          // Saldo cobre tudo
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Pagamento completo!',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[700],
                                ),
                              ),
                              Icon(
                                Icons.check_circle,
                                color: Colors.green[700],
                                size: 20,
                              ),
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _proceedWithSchedulingAndGetId();
            },
            child: Text(
              'Não usar saldo',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final balanceToUse =
                  double.tryParse(_balanceAmountController.text) ?? 0.0;
              if (balanceToUse <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Por favor, insira um valor válido para usar do saldo.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.of(context).pop();
              await _scheduleWithBalance(currentBalance, totalAmount);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _mainColor,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Usar saldo',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _scheduleWithBalance(
      double currentBalance, double totalAmount) async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      // Obter o valor que o usuário quer usar do saldo
      final balanceToUse =
          double.tryParse(_balanceAmountController.text) ?? 0.0;
      // Limitar o valor usado ao mínimo entre saldo disponível e valor total do serviço
      final clampedBalance = balanceToUse.clamp(
          0.0, currentBalance > totalAmount ? totalAmount : currentBalance);
      final remainingAmount = totalAmount - clampedBalance;

      // Agendar o serviço e obter o ID do agendamento
      final appointmentId = await _proceedWithSchedulingAndGetId();

      // Se ainda há valor para pagar, ir para tela de pagamento
      if (remainingAmount > 0 && appointmentId != null) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentScreen(
                amount: remainingAmount,
                serviceTitle: _serviceTitles,
                serviceDescription: widget.services
                    .map((s) => s['description'] as String)
                    .join(', '),
                carId: _selectedCar!['id'],
                carModel: _selectedCar!['model'],
                carPlate: _selectedCar!['plate'],
                appointmentId: appointmentId,
                balanceToUse:
                    clampedBalance, // Passar valor do saldo para a tela de pagamento
              ),
            ),
          );
        }
      } else if (appointmentId != null) {
        // Se não há valor restante, processar o pagamento completo com saldo
        await _processBalancePayment(clampedBalance, appointmentId);
        if (mounted) {
          _showSuccessDialog();
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao usar saldo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processBalancePayment(
      double balanceToUse, String appointmentId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      final currentBalance = (await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get())
              .data()?['balance'] ??
          0.0;

      final finalBalance = currentBalance - balanceToUse;

      // Atualizar saldo do usuário
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'balance': finalBalance});

      // Registrar transação de débito
      await FirebaseFirestore.instance.collection('transactions').add({
        'userId': user.uid,
        'amount': balanceToUse,
        'type': 'debit',
        'description': 'Pagamento de agendamento - $_serviceTitles',
        'appointmentId': appointmentId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Atualizar status do agendamento para confirmado
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({'status': 'confirmed'});
    } catch (e) {
      throw Exception('Erro ao processar pagamento com saldo: $e');
    }
  }

  Future<String?> _proceedWithSchedulingAndGetId() async {
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
          _showSuccessDialog();
        }
      }

      return docRef.id;
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

    return null;
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(
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
                                    // ignore: deprecated_member_use
                                    groupValue: _selectedCera,
                                    // ignore: deprecated_member_use
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
                                    // ignore: deprecated_member_use
                                    groupValue: _selectedCera,
                                    // ignore: deprecated_member_use
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
                                  color: Color.fromRGBO(
                                      (_mainColor.r * 255).round(),
                                      (_mainColor.g * 255).round(),
                                      (_mainColor.b * 255).round(),
                                      0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Color.fromRGBO(
                                        (_mainColor.r * 255).round(),
                                        (_mainColor.g * 255).round(),
                                        (_mainColor.b * 255).round(),
                                        0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
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
                              _dateFormat?.format(_selectedDate) ??
                                  '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
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
                    if (_timeSlots.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 48,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhum horário disponível',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Para esta data não há horários cadastrados no sistema.\nSelecione outra data ou entre em contato conosco.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
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
                        color: Color.fromRGBO(
                            (_mainColor.r * 255).round(),
                            (_mainColor.g * 255).round(),
                            (_mainColor.b * 255).round(),
                            0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Color.fromRGBO(
                              (_mainColor.r * 255).round(),
                              (_mainColor.g * 255).round(),
                              (_mainColor.b * 255).round(),
                              0.3),
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
                                  const Icon(
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
