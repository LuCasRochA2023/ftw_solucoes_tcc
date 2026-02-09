import 'dart:async';
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
import 'profile_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import '../utils/validation_utils.dart';

class ScheduleServiceScreen extends StatefulWidget {
  final List<Map<String, dynamic>> services;
  final AuthService authService;
  final String? rescheduleAppointmentId; // ID do agendamento sendo reagendado

  const ScheduleServiceScreen({
    super.key,
    required this.services,
    required this.authService,
    this.rescheduleAppointmentId, // Parâmetro opcional para reagendamento
  });

  @override
  State<ScheduleServiceScreen> createState() => _ScheduleServiceScreenState();
}

class _ScheduleServiceScreenState extends State<ScheduleServiceScreen> {
  // Regra: agendamentos só podem ser feitos a partir do dia seguinte (amanhã).
  // Além disso, mantemos a regra de não permitir domingos/feriados.
  DateTime _selectedDate = _getMinBookingDate();
  String? _selectedTime;
  bool _isLoading = false;
  Map<String, String> _bookedTimeSlots = {};
  Map<String, dynamic>? _selectedCar;
  List<Map<String, dynamic>> _userCars = [];
  final TextEditingController _balanceAmountController =
      TextEditingController();

  StreamSubscription<User?>? _authSub;

  bool _isPermissionDenied(Object e) {
    // Firestore lança FirebaseException com code 'permission-denied'
    if (e is FirebaseException) return e.code == 'permission-denied';
    return e.toString().contains('permission-denied');
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static const Duration _pendingHoldDuration = Duration(minutes: 30);

  Future<void> _expireStalePendingAppointments(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final now = DateTime.now();
    final staleRefs = <DocumentReference<Map<String, dynamic>>>[];

    for (final doc in docs) {
      final data = doc.data();
      final status = data['status'] as String?;
      if (status != 'pending') continue;

      // Se estamos reagendando, nunca expirar/cancelar o próprio agendamento.
      if (widget.rescheduleAppointmentId != null &&
          doc.id == widget.rescheduleAppointmentId) {
        continue;
      }

      final createdAtTs = data['createdAt'];
      if (createdAtTs is! Timestamp) continue; // sem createdAt: não expirar

      final createdAt = createdAtTs.toDate();
      if (createdAt.isAfter(now)) continue; // clock skew

      if (now.difference(createdAt) > _pendingHoldDuration) {
        staleRefs.add(doc.reference);
      }
    }

    if (staleRefs.isEmpty) return;

    try {
      final batch = _firestore.batch();
      for (final ref in staleRefs) {
        batch.update(ref, {
          'status': 'cancelled',
          'cancelReason': 'pending_timeout',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      debugPrint(
          '=== DEBUG: Expirados ${staleRefs.length} agendamentos pending (timeout 30m) ===');
    } catch (e) {
      // Não bloquear a UI por falha de limpeza.
      debugPrint('Erro ao expirar pendências antigas: $e');
    }
  }

  bool _isPendingHoldActive(Map<String, dynamic> data) {
    final status = data['status'] as String?;
    if (status != 'pending') return false;

    final createdAtTs = data['createdAt'];
    if (createdAtTs is! Timestamp) {
      // Se não tem createdAt, por segurança considera como ainda ativo para não
      // liberar indevidamente um horário que pode estar em fluxo de pagamento.
      return true;
    }

    final createdAt = createdAtTs.toDate();
    final now = DateTime.now();
    if (createdAt.isAfter(now)) return true; // clock skew / server timestamp
    return now.difference(createdAt) <= _pendingHoldDuration;
  }

  bool _isBlockingStatus(Map<String, dynamic> data) {
    final status = data['status'] as String?;
    if (status == 'confirmed') return true;
    if (status == 'pending') return _isPendingHoldActive(data);
    return false;
  }

  bool _isSlotInPast(DateTime slotTime) {
    final now = DateTime.now();
    // Só bloqueia "horários passados" quando a data selecionada for hoje.
    if (!_isSameDay(_selectedDate, now)) return false;
    return slotTime.isBefore(now);
  }

  List<String> _getMissingProfileFields(Map<String, dynamic>? userData) {
    final missing = <String>[];
    if (userData == null) {
      return [
        'nome',
        'CPF',
        'telefone',
        'endereço (CEP, rua, número, bairro, cidade, UF)',
      ];
    }

    final name = (userData['name'] as String?)?.trim() ?? '';
    final cpf = (userData['cpf'] as String?)?.trim() ?? '';
    final phone = (userData['phone'] as String?)?.trim() ?? '';

    if (!ValidationUtils.isValidName(name)) missing.add('nome completo');
    if (!ValidationUtils.isValidCpf(cpf)) missing.add('CPF válido');
    if (!ValidationUtils.isValidPhone(phone)) missing.add('telefone válido');

    final address = userData['address'] as Map<String, dynamic>?;
    final cep = (address?['cep'] as String?)?.trim() ?? '';
    final street = (address?['street'] as String?)?.trim() ?? '';
    final number = (address?['number'] as String?)?.trim() ?? '';
    final neighborhood = (address?['neighborhood'] as String?)?.trim() ?? '';
    final city = (address?['city'] as String?)?.trim() ?? '';
    final state = (address?['state'] as String?)?.trim() ?? '';

    if (!ValidationUtils.isValidCep(cep)) missing.add('CEP válido');
    if (street.isEmpty) missing.add('rua');
    if (!ValidationUtils.isValidNumber(number)) missing.add('número');
    if (neighborhood.isEmpty) missing.add('bairro');
    if (city.isEmpty) missing.add('cidade');
    if (!ValidationUtils.isValidState(state)) missing.add('UF');

    return missing;
  }

  Future<bool> _ensureProfileComplete() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final userData = doc.data();
      final missing = _getMissingProfileFields(userData);

      if (missing.isEmpty) return true;

      if (!mounted) return false;
      final goToProfile = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Complete seu perfil',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Para agendar serviços, complete os dados do seu perfil:\n\n- ${missing.join('\n- ')}',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Agora não', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Ir para Perfil', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      );

      if (goToProfile == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ProfileScreen(authService: widget.authService),
          ),
        );
      }
      return false;
    } catch (e) {
      // Se não conseguir validar, não deixa agendar (evita agendamento sem dados).
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível validar seu perfil: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Future<bool> _ensureRegisteredToPickTime() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current != null && !current.isAnonymous) return true;
    if (!mounted) return false;

    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Entrar para escolher o horário',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Você pode acessar o app sem cadastro. Para selecionar um horário e continuar o agendamento, entre ou crie uma conta.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text('Cancelar', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('register'),
            child: Text('Criar conta', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('login'),
            child: Text('Entrar', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (!mounted) return false;
    if (action == null) return false;

    if (action == 'login') {
      if (!mounted) return false;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => LoginScreen(
            authService: widget.authService,
            popOnSuccess: true,
          ),
        ),
      );
    } else if (action == 'register') {
      if (!mounted) return false;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => RegisterScreen(
            authService: widget.authService,
            popOnSuccess: true,
          ),
        ),
      );
    }

    if (!mounted) return false;
    final after = FirebaseAuth.instance.currentUser;
    final ok = after != null && !after.isAnonymous;
    if (ok) {
      // Após login/registro, recarrega os carros sem precisar voltar a tela.
      await _loadUserCars();
    }
    return ok;
  }

  Future<bool> _ensureRegisteredToAddCar() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current != null && !current.isAnonymous) return true;
    if (!mounted) return false;

    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Entrar para adicionar carro',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Para cadastrar um carro, entre ou crie uma conta.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text('Cancelar', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('register'),
            child: Text('Criar conta', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('login'),
            child: Text('Entrar', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (!mounted) return false;
    if (action == null) return false;

    if (action == 'login') {
      if (!mounted) return false;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => LoginScreen(
            authService: widget.authService,
            popOnSuccess: true,
          ),
        ),
      );
    } else if (action == 'register') {
      if (!mounted) return false;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => RegisterScreen(
            authService: widget.authService,
            popOnSuccess: true,
          ),
        ),
      );
    }

    if (!mounted) return false;
    final after = FirebaseAuth.instance.currentUser;
    final ok = after != null && !after.isAnonymous;
    if (ok) {
      // Após login/registro, recarrega os carros sem precisar voltar a tela.
      await _loadUserCars();
    }
    return ok;
  }

  // Função para obter a próxima data disponível (não domingo e não feriado)
  static DateTime _getNextAvailableDate(DateTime date) {
    DateTime currentDate = DateTime(date.year, date.month, date.day);
    while (_isHolidayOrSunday(currentDate)) {
      currentDate = currentDate.add(const Duration(days: 1));
    }
    return currentDate;
  }

  // Data mínima para agendamento: amanhã (normalizado) e, se cair em domingo/feriado,
  // pula para o próximo dia disponível.
  static DateTime _getMinBookingDate() {
    final now = DateTime.now();
    final tomorrow =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    return _getNextAvailableDate(tomorrow);
  }

  // Variável para opcional de cera (apenas uma seleção)
  String? _selectedCera;

  static const List<String> _weekdayDefaultSlots = [
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
  ];

  static const List<String> _saturdayDefaultSlots = [
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '13:00',
    '14:00',
  ];

  static bool _isHolidayOrSunday(DateTime date) {
    return date.weekday == DateTime.sunday || _isBrazilHoliday(date);
  }

  static bool _isBrazilHoliday(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final year = normalizedDate.year;

    final Set<DateTime> fixedHolidays = {
      DateTime(year, 1, 1), // Confraternização Universal
      DateTime(year, 4, 21), // Tiradentes
      DateTime(year, 5, 1), // Dia do Trabalho
      DateTime(year, 9, 7), // Independência do Brasil
      DateTime(year, 10, 12), // Nossa Senhora Aparecida
      DateTime(year, 11, 2), // Finados
      DateTime(year, 11, 15), // Proclamação da República
      DateTime(year, 12, 25), // Natal
    };

    final easterSunday = _calculateEasterSunday(year);
    final Set<DateTime> movableHolidays = {
      easterSunday
          .subtract(const Duration(days: 48)), // Segunda-feira de Carnaval
      easterSunday
          .subtract(const Duration(days: 47)), // Terça-feira de Carnaval
      easterSunday.subtract(const Duration(days: 2)), // Sexta-feira Santa
      easterSunday, // Domingo de Páscoa
      easterSunday.add(const Duration(days: 60)), // Corpus Christi
    };

    return fixedHolidays.contains(normalizedDate) ||
        movableHolidays.contains(normalizedDate);
  }

  static DateTime _calculateEasterSunday(int year) {
    // Algoritmo de Gauss para calcular a data da Páscoa
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }

  static List<String> _getDefaultSlotsForDate(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
      case DateTime.tuesday:
      case DateTime.wednesday:
      case DateTime.thursday:
      case DateTime.friday:
        return _weekdayDefaultSlots;
      case DateTime.saturday:
        return _saturdayDefaultSlots;
      default:
        return const [];
    }
  }

  final List<String> _timeSlots = [];
  DateFormat? _dateFormat;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Mapa de preços dos serviços
  static const Map<String, double> _servicePrices = {
    'Lavagem SUV': 80.0,
    'Lavagem SUV Grande': 95.0,
    'Lavagem Carro Comum': 75.0,
    'Lavagem Caminhonete com Caçamba': 115.0,
    'Enceramento': 60.0,
    'Leva e Traz': 15.0,
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
    // Quando o usuário faz login/registro, recarrega carros automaticamente
    // sem precisar voltar a tela.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (!mounted) return;
      if (user != null && !user.isAnonymous) {
        // Pequeno delay para garantir tokens prontos após login.
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        await _loadUserCars();
      } else {
        // Se saiu/virou convidado, limpa seleção/lista na UI.
        setState(() {
          _userCars = [];
          _selectedCar = null;
        });
      }
    });
    _initializeAsync();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _initializeAsync() async {
    _serviceTitles = widget.services.map((s) => s['title']).join(', ');
    _mainColor = widget.services.first['color'] ?? Colors.blue;
    _mainIcon = widget.services.first['icon'] ?? Icons.build;
    await _initializeDateFormatting();

    // Garantir regra: nunca permitir que a data selecionada seja hoje ou anterior.
    final minDate = _getMinBookingDate();
    if (_selectedDate.isBefore(minDate)) {
      _selectedDate = minDate;
    }

    await _generateTimeSlots();
    await _loadBookedTimeSlots();
    await _loadUserCars();

    if (mounted) {
      setState(() {}); // Atualiza a UI apenas uma vez após toda inicialização
    }
  }

  double _calculateTotalValue() {
    double total = 0;

    double? _parsePrice(dynamic raw) {
      if (raw == null) return null;
      if (raw is num) return raw.toDouble();
      if (raw is String) {
        final s = raw.trim();
        if (s.isEmpty) return null;
        // Aceita formatos como "R$ 60,00", "60,00", "60.00"
        final cleaned = s
            .replaceAll('R\$', '')
            .replaceAll(RegExp(r'\s+'), '')
            .replaceAll('.', '')
            .replaceAll(',', '.');
        return double.tryParse(cleaned);
      }
      return null;
    }

    double _getServicePrice(Map<String, dynamic> service) {
      final title = (service['title'] ?? '').toString().trim();
      final fixed = _servicePrices[title];
      if (fixed != null) return fixed;

      // Fallback: se o serviço veio com preço na lista
      final fromPriceField = _parsePrice(service['price']);
      if (fromPriceField != null) return fromPriceField;

      // Fallback adicional: alguns fluxos usam "value"
      final fromValueField = _parsePrice(service['value']);
      if (fromValueField != null) return fromValueField;

      return 0.0;
    }

    // Calcular valor dos serviços
    for (final service in widget.services) {
      total += _getServicePrice(service);
    }

    // Adicionar opcional de cera (apenas para serviços de lavagem)
    bool hasWashingService = widget.services.any((service) {
      final title = (service['title'] ?? '').toString().toLowerCase();
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
      final title = (service['title'] ?? '').toString().trim();
      final fixed = _servicePrices[title];
      if (fixed != null && fixed > 0) return true;

      final fromPriceField = service['price'];
      if (fromPriceField is String && fromPriceField.contains('R\$')) return true;

      final fromValueField = service['value'];
      if (fromValueField is num && fromValueField.toDouble() > 0) return true;
    }
    return false;
  }

  bool _hasWashingServices() {
    return widget.services.any((service) {
      final title = (service['title'] ?? '').toString().toLowerCase();
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

    final bool isSunday = _selectedDate.weekday == DateTime.sunday;
    final bool isHoliday = _isBrazilHoliday(_selectedDate);

    if (isSunday || isHoliday) {
      debugPrint(
          'Nenhum horário disponível: ${_selectedDate.toIso8601String()} é domingo/feriado.');
      return;
    }

    final List<String> defaultSlots = _getDefaultSlotsForDate(_selectedDate);
    if (defaultSlots.isEmpty) {
      debugPrint(
          'Nenhum horário padrão definido para ${_selectedDate.weekday}.');
      return;
    }

    final Set<String> allowedSlots = defaultSlots.toSet();
    Set<String> slotsToUse = <String>{};

    try {
      debugPrint(
          'Gerando horários para data: ${_selectedDate.toIso8601String()}');

      final snapshot = await _firestore
          .collection('horarios_disponiveis')
          .where('isAvailableForClients', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('Nenhum horário configurado no Firestore. Usando padrão.');
        slotsToUse = Set<String>.from(allowedSlots);
      } else {
        debugPrint(
            'Encontrados ${snapshot.docs.length} documentos disponíveis');

        final selectedDateStr =
            '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

        for (var doc in snapshot.docs) {
          final data = doc.data();

          final dateTime = _extractDateTime(data);
          if (dateTime == null) {
            debugPrint('Documento ${doc.id} não possui data/hora válida');
            continue;
          }

          final normalizedDate = _normalizeDate(dateTime['date']!);
          if (normalizedDate == selectedDateStr) {
            final time = dateTime['time']!;
            if (allowedSlots.contains(time)) {
              slotsToUse.add(time);
              debugPrint('Horário adicionado: $time para data $normalizedDate');
            } else {
              debugPrint(
                  'Horário ignorado por não estar na lista padrão: $time');
            }
          }
        }

        if (slotsToUse.isEmpty) {
          debugPrint(
              'Nenhum horário válido encontrado para a data. Usando padrão.');
          slotsToUse = Set<String>.from(allowedSlots);
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar horários do Firestore: $e');
      slotsToUse = Set<String>.from(allowedSlots);
    }

    if (slotsToUse.isEmpty) {
      slotsToUse = Set<String>.from(allowedSlots);
    }

    _timeSlots.addAll(slotsToUse.toList()..sort());

    debugPrint(
        'Total de horários disponíveis para ${_dateFormat?.format(_selectedDate)}: ${_timeSlots.length}');
    if (_timeSlots.isNotEmpty) {
      debugPrint('Horários: $_timeSlots');
    }
  }

  /// Extrai data e hora de diferentes estruturas de documento
  Map<String, String>? _extractDateTime(Map<String, dynamic> data) {
    String? date;
    String? time;

    // Estrutura 1: date + startTime
    if (data['date'] != null && data['startTime'] != null) {
      date = data['date'] as String;
      time = data['startTime'] as String;
    }
    // Estrutura 2: data + horario (português)
    else if (data['data'] != null && data['horario'] != null) {
      date = data['data'] as String;
      time = data['horario'] as String;
    }
    // Estrutura 3: date + time
    else if (data['date'] != null && data['time'] != null) {
      date = data['date'] as String;
      time = data['time'] as String;
    }
    // Estrutura 4: dia + hora
    else if (data['dia'] != null && data['hora'] != null) {
      date = data['dia'] as String;
      time = data['hora'] as String;
    }
    // Estrutura 5: timestamp ou dateTime
    else if (data['timestamp'] != null || data['dateTime'] != null) {
      try {
        final timestamp = (data['timestamp'] ?? data['dateTime']) as Timestamp;
        final dateTime = timestamp.toDate();
        date =
            '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
        time =
            '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        debugPrint('Erro ao processar timestamp: $e');
        return null;
      }
    }

    if (date != null && time != null) {
      return {'date': date, 'time': time};
    }
    return null;
  }

  /// Normaliza diferentes formatos de data para YYYY-MM-DD
  String _normalizeDate(String date) {
    String normalized = date.trim();

    // Formato DD/MM/YYYY -> YYYY-MM-DD
    if (normalized.contains('/')) {
      final parts = normalized.split('/');
      if (parts.length == 3) {
        return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
      }
    }
    // Formato YYYY-M-D -> YYYY-MM-DD (adicionar zeros)
    else if (normalized.split('-').length == 3) {
      final parts = normalized.split('-');
      return '${parts[0]}-${parts[1].padLeft(2, '0')}-${parts[2].padLeft(2, '0')}';
    }

    return normalized;
  }

  // Função para verificar se o bloco está livre
  bool _isBlockAvailable(DateTime start, Map<String, String> bookedSlots) {
    debugPrint('=== DEBUG: Verificando disponibilidade do bloco ===');
    debugPrint('Horário de início: ${DateFormat('HH:mm').format(start)}');
    debugPrint('Slots ocupados: ${bookedSlots.keys.toList()}');

    final slotStr = DateFormat('HH:mm').format(start);

    if (bookedSlots.containsKey(slotStr)) {
      debugPrint('=== DEBUG: Slot ocupado: $slotStr ===');
      return false;
    }

    debugPrint('=== DEBUG: Slot disponível: $slotStr ===');
    return true;
  }

  /// Verifica se o usuário já tem agendamentos pendentes
  /// Lança exceção se já existe um agendamento pendente (exceto se for reagendamento)
  Future<void> _checkUserPendingAppointments() async {
    try {
      debugPrint(
          '=== DEBUG: Verificando agendamentos pendentes do usuário ===');
      debugPrint('RescheduleAppointmentId: ${widget.rescheduleAppointmentId}');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw ('Usuário não autenticado');

      // Buscar agendamentos pendentes do usuário
      final querySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      debugPrint(
          'Encontrados ${querySnapshot.docs.length} agendamentos pendentes do usuário');

      // Filtrar agendamentos pendentes, excluindo o que está sendo reagendado
      final otherPendingAppointments = querySnapshot.docs.where((doc) {
        return widget.rescheduleAppointmentId == null ||
            doc.id != widget.rescheduleAppointmentId;
      }).toList();

      debugPrint(
          'Agendamentos pendentes (excluindo reagendamento): ${otherPendingAppointments.length}');

      // Considerar apenas pendências "ativas" (hold de 30 minutos).
      final activePending = otherPendingAppointments.where((doc) {
        final data = doc.data();
        return _isPendingHoldActive(data);
      }).toList();

      if (activePending.isNotEmpty) {
        final pendingAppointment = activePending.first;
        final data = pendingAppointment.data();
        final appointmentDateTime = (data['dateTime'] as Timestamp).toDate();
        final timeSlot = DateFormat('HH:mm').format(appointmentDateTime);
        final dateSlot = DateFormat('dd/MM/yyyy').format(appointmentDateTime);

        debugPrint('=== DEBUG: Agendamento pendente encontrado ===');
        debugPrint('Horário: $timeSlot em $dateSlot');
        debugPrint('ID do agendamento: ${pendingAppointment.id}');

        throw ('Você já possui um agendamento pendente às $timeSlot em $dateSlot. '
            'Complete o pagamento do agendamento atual antes de fazer um novo.');
      }

      debugPrint('=== DEBUG: Nenhum agendamento pendente encontrado ===');
    } catch (e) {
      debugPrint('Erro ao verificar agendamentos pendentes: $e');
      rethrow; // Re-lançar a exceção para ser tratada na função chamadora
    }
  }

  /// Verificação atômica de disponibilidade de horário usando transações
  Future<bool> _checkTimeSlotAvailabilityAtomic(DateTime dateTime) async {
    try {
      debugPrint('=== DEBUG: Verificação atômica de disponibilidade ===');

      final result = await FirebaseFirestore.instance
          .runTransaction<bool>((transaction) async {
        // Buscar agendamentos no período durante a transação
        final startTime = dateTime.subtract(const Duration(hours: 1));
        final endTime = dateTime.add(const Duration(hours: 1));

        final querySnapshot = await FirebaseFirestore.instance
            .collection('appointments')
            .where('dateTime', isGreaterThanOrEqualTo: startTime)
            .where('dateTime', isLessThan: endTime)
            .get();

        // Filtrar agendamentos relevantes
        final relevantAppointments = querySnapshot.docs.where((doc) {
          final data = doc.data();
          final isRelevantStatus = _isBlockingStatus(data);

          // Se for reagendamento, excluir o agendamento que está sendo reagendado
          if (widget.rescheduleAppointmentId != null &&
              doc.id == widget.rescheduleAppointmentId) {
            return false;
          }

          return isRelevantStatus;
        }).toList();

        // Verificar sobreposições
        for (var doc in relevantAppointments) {
          final data = doc.data();
          final appointmentDateTime = (data['dateTime'] as Timestamp).toDate();
          final status = data['status'] as String?;
          final appointmentId = doc.id;

          debugPrint(
              '=== DEBUG: Verificação atômica - agendamento $appointmentId ===');
          debugPrint('Status: $status');
          debugPrint(
              'DateTime: ${DateFormat('dd/MM/yyyy HH:mm').format(appointmentDateTime)}');

          if (_hasTimeOverlap(dateTime, appointmentDateTime)) {
            // Verificar se há conflito de tipo de lavagem
            final newServices = {
              'services': widget.services
                  .map((s) => {
                        'title': s['title'],
                        'type': (s['title'] as String)
                                .toLowerCase()
                                .contains('lavagem')
                            ? 'lavagem'
                            : 'outro',
                      })
                  .toList(),
            };

            final hasLavagemConflict = _hasLavagemConflict(newServices, data);

            if (hasLavagemConflict) {
              debugPrint(
                  '=== DEBUG: CONFLITO DE LAVAGEM DETECTADO NA VERIFICAÇÃO ATÔMICA ===');
              debugPrint('Agendamento conflitante: $appointmentId');
              debugPrint('Status: $status');
              return false; // Horário não disponível
            } else {
              debugPrint(
                  '=== DEBUG: Sem conflito de lavagem na verificação atômica ===');
            }
          }
        }

        debugPrint('=== DEBUG: VERIFICAÇÃO ATÔMICA - HORÁRIO DISPONÍVEL ===');
        return true; // Horário disponível
      });

      debugPrint(
          '=== DEBUG: RESULTADO FINAL DA VERIFICAÇÃO ATÔMICA: $result ===');
      return result;
    } catch (e) {
      debugPrint('Erro na verificação atômica: $e');
      return false; // Em caso de erro, considerar como não disponível
    }
  }

  // Função para verificar se o horário está disponível (apenas agendamentos confirmados/pendentes)
  Future<bool?> _isTimeSlotAvailable(DateTime selectedDateTime) async {
    try {
      debugPrint('=== DEBUG: Verificando disponibilidade do horário ===');
      debugPrint('Data/Hora: $selectedDateTime');

      // Buscar agendamentos no mesmo dia
      final startOfDay = DateTime(
        selectedDateTime.year,
        selectedDateTime.month,
        selectedDateTime.day,
      );
      final endOfDay = DateTime(
        selectedDateTime.year,
        selectedDateTime.month,
        selectedDateTime.day,
        23,
        59,
        59,
      );

      // Verificar agendamentos existentes usando dateTime (sem filtro de status para evitar índice composto)
      final appointmentsQuery = await _firestore
          .collection('appointments')
          .where('dateTime', isGreaterThanOrEqualTo: startOfDay)
          .where('dateTime', isLessThan: endOfDay)
          .get();

      debugPrint(
          '=== DEBUG: Encontrados ${appointmentsQuery.docs.length} agendamentos no dia ===');

      // Verificar se há conflito de horário
      for (var doc in appointmentsQuery.docs) {
        // Se estamos reagendando, ignorar o próprio agendamento.
        if (widget.rescheduleAppointmentId != null &&
            doc.id == widget.rescheduleAppointmentId) {
          continue;
        }

        final data = doc.data();
        // Filtrar apenas agendamentos que realmente bloqueiam:
        // - confirmed: sempre
        // - pending: só por 30 minutos após createdAt
        if (!_isBlockingStatus(data)) {
          continue;
        }

        final appointmentDateTime = (data['dateTime'] as Timestamp).toDate();

        // Verificar se é o mesmo horário (com tolerância de 1 minuto)
        final timeDiff = selectedDateTime.difference(appointmentDateTime).abs();
        if (timeDiff.inMinutes < 1) {
          debugPrint(
              '=== DEBUG: Horário já tem agendamento confirmado/pendente ===');
          debugPrint('Agendamento conflitante: ${doc.id}');
          debugPrint('Status: ${data['status']}');
          debugPrint(
              'Horário do agendamento: ${DateFormat('HH:mm').format(appointmentDateTime)}');
          return false;
        }
      }

      debugPrint('=== DEBUG: Horário está disponível ===');
      return true;
    } catch (e) {
      debugPrint('Erro ao verificar disponibilidade: $e');
      // Se não temos permissão (ex.: App Check / regras), não exibir mensagem
      // e sinalizar que não foi possível verificar agora.
      if (_isPermissionDenied(e)) return null;
      return false;
    }
  }

  /// Verifica se um horário está disponível para agendamento
  /// Lança exceção se já existe um agendamento confirmado no mesmo horário
  Future<void> _checkTimeSlotAvailability(DateTime dateTime) async {
    try {
      debugPrint('=== DEBUG: Verificando disponibilidade do horário ===');
      debugPrint('Horário selecionado: ${dateTime.toString()}');
      debugPrint(
          'Horário formatado: ${DateFormat('dd/MM/yyyy HH:mm').format(dateTime)}');

      // Buscar agendamentos no mesmo horário (com tolerância de 1 hora)
      final startTime = dateTime.subtract(const Duration(hours: 1));
      final endTime = dateTime.add(const Duration(hours: 1));

      // Buscar todos os agendamentos no período e filtrar por status no código
      final querySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('dateTime', isGreaterThanOrEqualTo: startTime)
          .where('dateTime', isLessThan: endTime)
          .get();

      debugPrint(
          'Encontrados ${querySnapshot.docs.length} agendamentos no período');

      // Filtrar apenas agendamentos confirmados, pendentes e sem pagamento, excluindo o que está sendo reagendado
      final relevantAppointments = querySnapshot.docs.where((doc) {
        final data = doc.data();
        final status = data['status'] as String?;
        final isRelevantStatus = _isBlockingStatus(data);

        debugPrint('=== DEBUG: Verificando agendamento ${doc.id} ===');
        debugPrint('Status: $status');
        debugPrint('IsRelevantStatus: $isRelevantStatus');
        debugPrint(
            'RescheduleAppointmentId: ${widget.rescheduleAppointmentId}');

        // Se for reagendamento, excluir o agendamento que está sendo reagendado
        if (widget.rescheduleAppointmentId != null &&
            doc.id == widget.rescheduleAppointmentId) {
          debugPrint('Excluindo agendamento que está sendo reagendado');
          return false;
        }

        debugPrint('Incluindo agendamento: $isRelevantStatus');
        return isRelevantStatus;
      }).toList();

      debugPrint(
          'Agendamentos relevantes (confirmed/pending): ${relevantAppointments.length}');

      for (var doc in relevantAppointments) {
        final data = doc.data();
        final appointmentDateTime = (data['dateTime'] as Timestamp).toDate();
        final status = data['status'] as String?;
        final appointmentId = doc.id;

        // Verificar se há sobreposição de horário
        debugPrint(
            '=== DEBUG: Verificando sobreposição com agendamento $appointmentId ===');
        debugPrint('Status do agendamento: $status');
        debugPrint(
            'Horário novo: ${DateFormat('dd/MM/yyyy HH:mm').format(dateTime)}');
        debugPrint(
            'Horário existente: ${DateFormat('dd/MM/yyyy HH:mm').format(appointmentDateTime)}');

        debugPrint('=== DEBUG: Chamando verificação de sobreposição ===');
        final hasTimeOverlap = _hasTimeOverlap(dateTime, appointmentDateTime);
        debugPrint(
            '=== DEBUG: Resultado da verificação de sobreposição: $hasTimeOverlap ===');

        if (hasTimeOverlap) {
          // Verificar se há conflito de tipo de lavagem
          final newServices = {
            'services': widget.services
                .map((s) => {
                      'title': s['title'],
                      'type': (s['title'] as String)
                              .toLowerCase()
                              .contains('lavagem')
                          ? 'lavagem'
                          : 'outro',
                    })
                .toList(),
          };

          final hasLavagemConflict = _hasLavagemConflict(newServices, data);

          if (hasLavagemConflict) {
            final timeSlot = DateFormat('HH:mm').format(appointmentDateTime);
            final dateSlot =
                DateFormat('dd/MM/yyyy').format(appointmentDateTime);

            debugPrint('=== DEBUG: CONFLITO DE LAVAGEM DETECTADO ===');
            debugPrint('Horário conflitante: $timeSlot em $dateSlot');
            debugPrint('Status do agendamento: $status');
            debugPrint('ID do agendamento: $appointmentId');

            throw ('Horário não disponível! Já existe um agendamento de lavagem às $timeSlot em $dateSlot. '
                'Apenas um tipo de lavagem é permitido por horário. '
                'Por favor, escolha outro horário.');
          } else {
            debugPrint(
                '=== DEBUG: Sem conflito de lavagem - permitindo agendamento ===');
          }
        } else {
          debugPrint(
              '=== DEBUG: Sem conflito de horário para este agendamento ===');
        }
      }

      debugPrint(
          '=== DEBUG: TODOS OS AGENDAMENTOS VERIFICADOS - HORÁRIO DISPONÍVEL ===');

      // Verificação adicional usando transação atômica
      debugPrint('=== DEBUG: Iniciando verificação atômica ===');
      final isAvailableAtomic =
          await _checkTimeSlotAvailabilityAtomic(dateTime);
      debugPrint(
          '=== DEBUG: Resultado da verificação atômica: $isAvailableAtomic ===');

      if (!isAvailableAtomic) {
        debugPrint('=== DEBUG: CONFLITO DETECTADO NA VERIFICAÇÃO ATÔMICA ===');
        throw ('Horário não disponível! Conflito de lavagem detectado na verificação atômica. '
            'Apenas um tipo de lavagem é permitido por horário. '
            'Por favor, escolha outro horário.');
      }

      debugPrint(
          '=== DEBUG: VERIFICAÇÃO ATÔMICA CONCLUÍDA - HORÁRIO CONFIRMADO DISPONÍVEL ===');
    } catch (e) {
      debugPrint('Erro ao verificar disponibilidade: $e');
      rethrow; // Re-lançar a exceção para ser tratada na função chamadora
    }
  }

  /// Verifica se há sobreposição entre dois horários
  bool _hasTimeOverlap(DateTime newAppointment, DateTime existingAppointment) {
    // Cada agendamento ocupa 1 hora (60 minutos)
    const blockDuration = Duration(minutes: 60);

    // Calcular o fim do agendamento existente
    final existingEnd = existingAppointment.add(blockDuration);

    // Calcular o fim do novo agendamento
    final newEnd = newAppointment.add(blockDuration);

    // Logs para debug
    debugPrint('=== DEBUG: Verificação de sobreposição ===');
    debugPrint(
        'Novo agendamento: ${DateFormat('dd/MM/yyyy HH:mm').format(newAppointment)} - ${DateFormat('dd/MM/yyyy HH:mm').format(newEnd)}');
    debugPrint(
        'Agendamento existente: ${DateFormat('dd/MM/yyyy HH:mm').format(existingAppointment)} - ${DateFormat('dd/MM/yyyy HH:mm').format(existingEnd)}');
    debugPrint(
        'Condição 1: novo início < fim existente: ${newAppointment.isBefore(existingEnd)}');
    debugPrint(
        'Condição 2: novo fim > início existente: ${newEnd.isAfter(existingAppointment)}');

    // Há sobreposição se:
    // 1. O novo agendamento começa antes do fim do existente, E
    // 2. O fim do novo agendamento é depois do início do existente
    // OU se os horários são exatamente iguais
    final condition1 = newAppointment.isBefore(existingEnd);
    final condition2 = newEnd.isAfter(existingAppointment);
    final condition3 = newAppointment.isAtSameMomentAs(existingAppointment);

    final hasOverlap = (condition1 && condition2) || condition3;

    debugPrint('Condição 1 (novo início < fim existente): $condition1');
    debugPrint('Condição 2 (novo fim > início existente): $condition2');
    debugPrint('Condição 3 (horários iguais): $condition3');
    debugPrint('Resultado final: $hasOverlap');
    return hasOverlap;
  }

  /// Verifica se há conflito de tipo de lavagem
  bool _hasLavagemConflict(
      Map<String, dynamic> newServices, Map<String, dynamic> existingServices) {
    // Verificar se ambos os agendamentos contêm serviços de lavagem
    final newServicesList = newServices['services'] as List? ?? [];
    final existingServicesList = existingServices['services'] as List? ?? [];

    // Verificar se há serviços de lavagem no novo agendamento
    final hasNewLavagem = newServicesList.any((service) {
      final title = (service['title'] as String? ?? '').toLowerCase();
      return title.contains('lavagem');
    });

    // Verificar se há serviços de lavagem no agendamento existente
    final hasExistingLavagem = existingServicesList.any((service) {
      final title = (service['title'] as String? ?? '').toLowerCase();
      return title.contains('lavagem');
    });

    // Se ambos têm lavagem, há conflito
    final hasConflict = hasNewLavagem && hasExistingLavagem;

    debugPrint('=== DEBUG: Verificação de conflito de lavagem ===');
    debugPrint(
        'Novos serviços: ${newServicesList.map((s) => s['title']).toList()}');
    debugPrint(
        'Serviços existentes: ${existingServicesList.map((s) => s['title']).toList()}');
    debugPrint('Tem lavagem no novo: $hasNewLavagem');
    debugPrint('Tem lavagem no existente: $hasExistingLavagem');
    debugPrint('Há conflito: $hasConflict');

    return hasConflict;
  }

  Future<void> _loadBookedTimeSlots() async {
    if (!mounted) return;

    if (_isHolidayOrSunday(_selectedDate)) {
      setState(() {
        _bookedTimeSlots = {};
        _isLoading = false;
      });
      return;
    }

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

      // Limpar pendências antigas (pending > 30 minutos) para liberar horários.
      await _expireStalePendingAppointments(querySnapshot.docs);

      final Map<String, String> bookedSlots = {};
      for (var doc in querySnapshot.docs) {
        // Se estamos reagendando, não marcar o próprio agendamento como "ocupado"
        // (permite selecionar o mesmo horário que já está pendente).
        if (widget.rescheduleAppointmentId != null &&
            doc.id == widget.rescheduleAppointmentId) {
          continue;
        }

        final data = doc.data();
        final status = data['status'] as String?;

        debugPrint('=== DEBUG: Verificando agendamento para exibição ===');
        debugPrint('ID: ${doc.id}');
        debugPrint('Status: $status');
        debugPrint('DateTime: ${data['dateTime']}');

        // Considerar como ocupado:
        // - confirmed: sempre
        // - pending: apenas dentro do "hold" de 30 minutos após createdAt
        if (_isBlockingStatus(data)) {
          final dateTime = (data['dateTime'] as Timestamp).toDate();
          dynamic serviceField =
              data['services'] ?? data['service']; // Novo formato com fallback
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
          final statusText = status == 'confirmed'
              ? ' (Confirmado)'
              : (_isPendingHoldActive(data)
                  ? ' (Pendente)'
                  : ' (Pendente exp.)');
          bookedSlots[timeSlot] = service + statusText;
          debugPrint(
              'Booked slot: $timeSlot for service: $service - Status: $status');
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
      if (mounted) {
        setState(() {
          _bookedTimeSlots = {}; // fallback seguro
          _isLoading = false;
        });
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
    final minDate = _getMinBookingDate();
    final safeInitial =
        _selectedDate.isBefore(minDate) ? minDate : _selectedDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _getNextAvailableDate(safeInitial),
      firstDate: minDate,
      lastDate: DateTime(2026, 12, 31),
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
        // Bloquear hoje e qualquer dia anterior; além disso bloquear domingo/feriado.
        if (date.isBefore(minDate)) return false;
        return !_isHolidayOrSunday(date);
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

    // Validação extra: não permitir agendar em data/hora no passado.
    final parts = _selectedTime!.split(':');
    final selectedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    final minDate = _getMinBookingDate();
    if (selectedDateTime.isBefore(minDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Selecione uma data/horário a partir de ${_dateFormat?.format(minDate) ?? 'amanhã'}.'),
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

    // Só permite agendar se o perfil estiver completo.
    final profileOk = await _ensureProfileComplete();
    if (!profileOk) return;

    // Verificar saldo antes de agendar
    await _checkBalanceAndSchedule();
  }

  Future<void> _checkBalanceAndSchedule() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw ('Usuário não autenticado');

      // Buscar saldo do usuário
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final currentBalance = (userDoc.data()?['balance'] ?? 0.0).toDouble();
      final totalAmount = _calculateTotalValue();

      // Se não há valor para pagar, agendar normalmente
      if (totalAmount <= 0) {
        debugPrint('=== DEBUG: Serviço gratuito - agendando diretamente ===');
        await _proceedWithSchedulingAndGetId();
        return;
      }

      // Se há saldo, mostrar pop-up de uso do saldo
      if (currentBalance > 0) {
        debugPrint(
            '=== DEBUG: Há saldo - mostrando diálogo de uso do saldo ===');
        setState(() => _isLoading = false);
        await _showBalanceUsageDialog(currentBalance, totalAmount);
      } else {
        // Se não há saldo, agendar e redirecionar para pagamento
        debugPrint(
            '=== DEBUG: Não há saldo - agendando e redirecionando para pagamento ===');
        final appointmentId = await _proceedWithSchedulingAndGetId();
        debugPrint('=== DEBUG: AppointmentId obtido: $appointmentId ===');

        if (appointmentId != null && mounted) {
          debugPrint('=== DEBUG: Redirecionando para tela de pagamento ===');
          debugPrint('Valor total: R\$ ${totalAmount.toStringAsFixed(2)}');

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentScreen(
                amount: totalAmount,
                serviceTitle: _serviceTitles,
                serviceDescription: (widget.services
                            .map((s) => (s['description'] as String?)?.trim())
                            .whereType<String>()
                            .where((d) => d.isNotEmpty)
                            .join(', ')
                            .trim())
                        .isNotEmpty
                    ? widget.services
                        .map((s) => (s['description'] as String?)?.trim())
                        .whereType<String>()
                        .where((d) => d.isNotEmpty)
                        .join(', ')
                    : _serviceTitles,
                carId: _selectedCar!['id'],
                carModel: _selectedCar!['model'],
                carPlate: _selectedCar!['plate'],
                appointmentId: appointmentId,
              ),
            ),
          );
        } else {
          debugPrint(
              '=== DEBUG: Erro - AppointmentId é null ou widget não está montado ===');
        }
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
      if (user == null) throw ('Usuário não autenticado');

      // Obter o valor que o usuário quer usar do saldo
      final balanceToUse =
          double.tryParse(_balanceAmountController.text) ?? 0.0;
      // Limitar o valor usado ao mínimo entre saldo disponível e valor total do serviço
      final clampedBalance = balanceToUse.clamp(
          0.0, currentBalance > totalAmount ? totalAmount : currentBalance);
      final remainingAmount = totalAmount - clampedBalance;

      debugPrint('=== DEBUG: Valores calculados ===');
      debugPrint('balanceToUse (digitado): $balanceToUse');
      debugPrint('clampedBalance (limitado): $clampedBalance');
      debugPrint('totalAmount: $totalAmount');
      debugPrint('remainingAmount: $remainingAmount');
      debugPrint('remainingAmount > 0: ${remainingAmount > 0}');

      debugPrint('=== DEBUG: Cálculo de saldo ===');
      debugPrint('Saldo atual: R\$ ${currentBalance.toStringAsFixed(2)}');
      debugPrint(
          'Valor total do serviço: R\$ ${totalAmount.toStringAsFixed(2)}');
      debugPrint(
          'Valor digitado pelo usuário: R\$ ${balanceToUse.toStringAsFixed(2)}');
      debugPrint(
          'Valor limitado (clamped): R\$ ${clampedBalance.toStringAsFixed(2)}');
      debugPrint('Valor restante: R\$ ${remainingAmount.toStringAsFixed(2)}');

      // Agendar o serviço e obter o ID do agendamento (pular redirecionamento automático)
      final appointmentId =
          await _proceedWithSchedulingAndGetId(skipPaymentRedirect: true);

      // Se ainda há valor para pagar, ir para tela de pagamento
      debugPrint('=== DEBUG: Verificando redirecionamento ===');
      debugPrint('Valor restante > 0: ${remainingAmount > 0}');
      debugPrint('AppointmentId não é null: ${appointmentId != null}');

      if (remainingAmount > 0 && appointmentId != null) {
        // Se há valor restante, redirecionar para tela de pagamento
        debugPrint('=== DEBUG: Redirecionando para tela de pagamento ===');
        debugPrint('Valor a pagar: R\$ ${remainingAmount.toStringAsFixed(2)}');
        debugPrint(
            'Valor usado do saldo: R\$ ${clampedBalance.toStringAsFixed(2)}');

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentScreen(
                amount: remainingAmount,
                serviceTitle: _serviceTitles,
                serviceDescription: (widget.services
                            .map((s) => (s['description'] as String?)?.trim())
                            .whereType<String>()
                            .where((d) => d.isNotEmpty)
                            .join(', ')
                            .trim())
                        .isNotEmpty
                    ? widget.services
                        .map((s) => (s['description'] as String?)?.trim())
                        .whereType<String>()
                        .where((d) => d.isNotEmpty)
                        .join(', ')
                    : _serviceTitles,
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
        // Se não há valor restante (saldo cobre tudo), processar o pagamento completo com saldo
        debugPrint('=== DEBUG: Processando pagamento completo com saldo ===');
        debugPrint(
            'Valor usado do saldo: R\$ ${clampedBalance.toStringAsFixed(2)}');

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
      debugPrint('=== DEBUG: Processando pagamento com saldo ===');
      debugPrint('Valor a debitar: R\$ ${balanceToUse.toStringAsFixed(2)}');
      debugPrint('ID do agendamento: $appointmentId');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw ('Usuário não autenticado');

      final currentBalance = (await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get())
              .data()?['balance'] ??
          0.0;

      final finalBalance = currentBalance - balanceToUse;

      debugPrint('Saldo atual: R\$ ${currentBalance.toStringAsFixed(2)}');
      debugPrint('Saldo final: R\$ ${finalBalance.toStringAsFixed(2)}');

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

      // Recarregar horários ocupados após atualizar o status
      if (mounted) {
        await _loadBookedTimeSlots();
      }
    } catch (e) {
      throw ('Erro ao processar pagamento com saldo: $e');
    }
  }

  Future<String?> _proceedWithSchedulingAndGetId(
      {bool skipPaymentRedirect = false}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw ('Usuário não autenticado');

      final timeParts = _selectedTime!.split(':');
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );

      // Garantia no backend-side do app: não salvar agendamento antes da data mínima.
      final minDate = _getMinBookingDate();
      if (dateTime.isBefore(minDate)) {
        throw ('Data/horário inválido: selecione a partir de '
            '${_dateFormat?.format(minDate) ?? 'amanhã'}.');
      }

      // Verificar se o usuário já tem agendamentos pendentes
      await _checkUserPendingAppointments();

      // Verificar se já existe um agendamento confirmado no mesmo horário
      await _checkTimeSlotAvailability(dateTime);

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
        appointmentStatus =
            'confirmed'; // Agendamentos gratuitos são automaticamente confirmados
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

      // Se for um reagendamento, cancelar o agendamento anterior
      if (widget.rescheduleAppointmentId != null) {
        debugPrint(
            '=== DEBUG: Cancelando agendamento anterior para reagendamento ===');
        debugPrint(
            'AppointmentId a cancelar: ${widget.rescheduleAppointmentId}');

        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(widget.rescheduleAppointmentId)
            .update({'status': 'cancelled'});

        debugPrint('=== DEBUG: Agendamento anterior cancelado com sucesso ===');
      }

      final docRef = await FirebaseFirestore.instance
          .collection('appointments')
          .add(appointmentData);

      debugPrint('=== DEBUG: Agendamento criado com sucesso ===');
      debugPrint('ID do agendamento: ${docRef.id}');

      if (mounted) {
        // Recarregar horários ocupados após criar o agendamento
        await _loadBookedTimeSlots();

        // Verificar se há serviços com valor para determinar o fluxo
        if (!_hasServicesWithPrice() || totalAmount == 0) {
          // Mostrar dialog de sucesso para serviços sem valor
          debugPrint(
              '=== DEBUG: Serviço sem valor - mostrando diálogo de sucesso ===');
          _showSuccessDialog();
        } else if (!skipPaymentRedirect) {
          // Se há valor para pagar e não deve pular redirecionamento, ir para tela de pagamento
          debugPrint(
              '=== DEBUG: Serviço com valor - redirecionando para pagamento ===');
          debugPrint('Valor total: R\$ ${totalAmount.toStringAsFixed(2)}');

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentScreen(
                amount: totalAmount,
                serviceTitle: _serviceTitles,
                serviceDescription: (widget.services
                            .map((s) => (s['description'] as String?)?.trim())
                            .whereType<String>()
                            .where((d) => d.isNotEmpty)
                            .join(', ')
                            .trim())
                        .isNotEmpty
                    ? widget.services
                        .map((s) => (s['description'] as String?)?.trim())
                        .whereType<String>()
                        .where((d) => d.isNotEmpty)
                        .join(', ')
                    : _serviceTitles,
                carId: _selectedCar!['id'],
                carModel: _selectedCar!['model'],
                carPlate: _selectedCar!['plate'],
                appointmentId: docRef.id,
              ),
            ),
          );
        } else {
          debugPrint('=== DEBUG: Pular redirecionamento para pagamento ===');
        }
      }

      debugPrint('=== DEBUG: Retornando ID do agendamento: ${docRef.id} ===');
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
                      () {
                        final total = _calculateTotalValue();
                        if (total <= 0) return '• Valor: Preço a combinar';
                        return '• Valor: R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}';
                      }(),
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
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          'Agendar Serviços',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _mainColor,
        foregroundColor: Colors.white,
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
                                  final registered =
                                      await _ensureRegisteredToAddCar();
                                  if (!registered) return;
                                  if (!mounted) return;

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
                              final registered =
                                  await _ensureRegisteredToAddCar();
                              if (!registered) return;
                              if (!mounted) return;

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
                                    toggleable: true,
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
                                    toggleable: true,
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
                              'Para esta data não há horários habilitados pelo administrador.\nSelecione outra data ou entre em contato conosco.',
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
                          final isPast = _isSlotInPast(slotTime);
                          final canSelect = isAvailable && !isPast;
                          // Não esconder horários - mostrar todos, mas marcar os ocupados
                          return Tooltip(
                            message: isPast
                                ? 'Horário já passou'
                                : (isAvailable ? 'Disponível' : 'Ocupado'),
                            child: InkWell(
                              onTap: canSelect
                                  ? () async {
                                      final registered =
                                          await _ensureRegisteredToPickTime();
                                      if (!registered) return;
                                      if (!context.mounted) return;

                                      // Verificar se o horário ainda está disponível
                                      final isStillAvailable =
                                          await _isTimeSlotAvailable(slotTime);
                                      // null = não foi possível verificar (ex.: permission-denied)
                                      if (isStillAvailable == null) return;
                                      if (isStillAvailable == false) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Este horário não está mais disponível. Por favor, escolha outro horário.'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return;
                                      }

                                      if (!context.mounted) return;
                                      setState(() {
                                        _selectedTime = timeSlot;
                                      });
                                    }
                                  : null,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _mainColor
                                      : (canSelect
                                          ? Colors.white
                                          : Colors.grey.shade300),
                                  border: Border.all(
                                    color: isSelected
                                        ? _mainColor
                                        : (canSelect
                                            ? Colors.grey.shade300
                                            : Colors.red.shade300),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    timeSlot,
                                    style: GoogleFonts.poppins(
                                      color: isSelected
                                          ? Colors.white
                                          : (canSelect
                                              ? Colors.black87
                                              : Colors.grey.shade600),
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
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
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
      ),
    );
  }
}
