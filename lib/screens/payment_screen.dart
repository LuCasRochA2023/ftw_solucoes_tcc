import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ftw_solucoes/widgets/pay_with_credit_card.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:ftw_solucoes/screens/login_screen.dart';
import 'package:ftw_solucoes/screens/register_screen.dart';
import '../services/auth/auth_service.dart';
import '../services/payment/payment_device_session_service.dart';
import '../services/payment/payment_payload_builder.dart';
import '../services/payment/payment_user_service.dart';
import 'package:flutter/services.dart';
import 'package:ftw_solucoes/screens/home_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../utils/backend_url.dart';
import '../utils/environment_config.dart';
import '../services/auth/connectivity_events.dart';

class PaymentScreen extends StatefulWidget {
  final double amount;
  final String serviceTitle;
  final String serviceDescription;
  final String carId;
  final String carModel;
  final String carPlate;
  final String appointmentId;
  final double? balanceToUse;
  final String? returnToRouteName;

  const PaymentScreen({
    Key? key,
    required this.amount,
    required this.serviceTitle,
    required this.serviceDescription,
    required this.carId,
    required this.carModel,
    required this.carPlate,
    required this.appointmentId,
    this.balanceToUse,
    this.returnToRouteName,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  // Cartão permanece no projeto, mas o fluxo está desativado na UI.
  // Exibimos apenas PIX para pagamento.
  static const bool _enableCardPayment = false;

  bool _isProcessing = false;
  String? _errorMessage;
  String? _pixQrCode;
  String? _paymentId;
  Timer? _statusTimer;
  int _selectedTab = 0; // 0 = Pix, 1 = Cartão (desabilitado se _enableCardPayment=false)
  bool _isInitialized = false; // Flag para evitar inicialização duplicada
  bool _isDisposed = false; // Flag para controlar se a tela foi descartada
  StreamSubscription<void>? _onlineSub;

  Future<void> _ensureAppointmentIsPending() async {
    try {
      if (widget.appointmentId.trim().isEmpty) return;
      final ref = FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId.trim());
      final snap = await ref.get();
      final status = snap.data()?['status']?.toString();
      // Não sobrescrever estados finais/administrativos.
      if (status == 'confirmed' || status == 'cancelled' || status == 'completed') {
        return;
      }
      if (status != 'pending') {
        await ref.update({'status': 'pending'});
      }
    } catch (e) {
      debugPrint('Erro ao garantir status pending do agendamento: $e');
    }
  }

  bool _walletDebitProcessed = false; // Evita debitar saldo 2x no mesmo fluxo

  String? _userCpf;


  // Evita vazar dados sensíveis em logs.
  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  List<Map<String, dynamic>> _buildPaymentItems() {
    return PaymentPayloadBuilder.buildPaymentItems(
      serviceTitle: widget.serviceTitle,
      serviceDescription: widget.serviceDescription,
      appointmentId: widget.appointmentId,
      amount: widget.amount,
      balanceToUse: widget.balanceToUse ?? 0.0,
    );
  }

  String _buildExternalReference() {
    return PaymentPayloadBuilder.buildExternalReference(widget.appointmentId);
  }

  String? _getDeviceSessionId() {
    return PaymentDeviceSessionService.getWebDeviceSessionId();
  }

  String? _deviceSessionIdMobile;

  Future<void> _ensureDeviceSessionIdMobile() async {
    if (_deviceSessionIdMobile != null && _deviceSessionIdMobile!.isNotEmpty) {
      return;
    }
    final mobileId = await PaymentDeviceSessionService
        .getOrCreateMobileDeviceSessionId(mounted: mounted);
    if (!mounted || mobileId == null) return;
    setState(() => _deviceSessionIdMobile = mobileId);
  }

  String? _effectiveDeviceSessionId() {
    return _getDeviceSessionId() ?? _deviceSessionIdMobile;
  }

  // Função para copiar QR code para área de transferência
  Future<void> _copyQrCodeToClipboard() async {
    if (_pixQrCode != null && _pixQrCode!.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: _pixQrCode!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Código PIX copiado para área de transferência!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    debugPrint('=== DEBUG: PaymentScreen initState ===');
    _onlineSub = ConnectivityEvents.instance.onOnline.listen((_) {
      // Quando a internet voltar, retornar para a tela anterior.
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
    // Inicializar imediatamente sem delay
    // Gera MP_DEVICE_SESSION_ID no mobile via WebView invisível (requisito do MP).
    unawaited(_ensureDeviceSessionIdMobile());
    _initializePayment();
  }

  // O destino do "voltar" é decidido pela tela anterior (ex.: reagendar volta ao histórico).

  Future<bool> _ensureRegisteredForPayment() async {
    final current = FirebaseAuth.instance.currentUser;
    // Se for anônimo, ainda é "convidado" (sem cadastro).
    if (current != null && !current.isAnonymous) return true;
    if (!mounted) return false;

    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Entrar para pagar'),
        content: const Text(
            'Para continuar com o pagamento, crie uma conta ou entre com seu email.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('register'),
            child: const Text('Criar conta'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('login'),
            child: const Text('Entrar'),
          ),
        ],
      ),
    );

    if (!mounted || action == null) return false;

    final authService = AuthService();
    if (action == 'login') {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) =>
              LoginScreen(authService: authService, popOnSuccess: true),
        ),
      );
    } else if (action == 'register') {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) =>
              RegisterScreen(authService: authService, popOnSuccess: true),
        ),
      );
    }

    final after = FirebaseAuth.instance.currentUser;
    return after != null && !after.isAnonymous;
  }

  Future<void> _initializePayment() async {
    if (_isInitialized) {
      debugPrint('=== DEBUG: Pagamento já inicializado, pulando... ===');
      return;
    }

    debugPrint('=== DEBUG: Inicializando pagamento ===');
    _isInitialized = true;

    // IMPORTANTE:
    // Se o usuário escolheu usar saldo (balanceToUse) junto com PIX/Cartão,
    // não podemos debitar o saldo aqui — só após o pagamento ser aprovado.

    final registered = await _ensureRegisteredForPayment();
    if (!registered) {
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    // Garantir que existe um agendamento pendente associado ao pagamento.
    await _ensureAppointmentIsPending();

    // Primeiro carregar o CPF, depois criar o pagamento
    await _loadUserCpf();
    await _criarPagamentoPix();
    debugPrint('=== DEBUG: Inicialização concluída ===');
  }

  @override
  void dispose() {
    _isDisposed = true;
    _statusTimer?.cancel();
    _onlineSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUserCpf() async {
    _log('=== DEBUG: Carregando CPF do usuário ===');
    try {
      final cpf = await PaymentUserService.loadCurrentUserCpf()
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() => _userCpf = cpf);
    } catch (e) {
      _log('Erro ao carregar CPF do usuário: $e');
      if (!mounted) return;
      setState(() => _userCpf = null);
    }
  }

  Future<void> _criarPagamentoPix() async {
    if (_isProcessing) {
      debugPrint(
          '=== DEBUG: Pagamento PIX já em processamento, pulando... ===');
      return;
    }

    debugPrint('=== DEBUG: Definindo _isProcessing como true ===');
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      debugPrint('=== DEBUG: Iniciando criação de pagamento PIX ===');
      debugPrint('BackendUrl.baseUrl: ${BackendUrl.baseUrl}');
      debugPrint(
          'EnvironmentConfig.activeBackendUrl: ${EnvironmentConfig.activeBackendUrl}');
      debugPrint('URL completa: ${BackendUrl.baseUrl}/create-payment');
      // Usar dados do usuário logado se disponível
      final user = FirebaseAuth.instance.currentUser;
      String userEmail = 'usuario@email.com';
      String userFirstName = 'Nome';
      String userLastName = 'Sobrenome';
      String userCpf = '12345678909'; // CPF válido para teste

      if (user != null) {
        userEmail = user.email ?? userEmail;
        if (user.displayName != null) {
          final nameParts = user.displayName!.split(' ');
          userFirstName = nameParts.first;
          userLastName = nameParts.skip(1).join(' ');
        }
      }

      // Verificar se temos CPF do perfil do usuário
      if (_userCpf != null && _userCpf!.isNotEmpty) {
        final cleanCpf = _userCpf!.replaceAll(RegExp(r'[^\d]'), '');
        if (cleanCpf.length == 11) {
          userCpf = cleanCpf;
        } else {
          _log('CPF do perfil inválido. Usando CPF de fallback.');
        }
      } else {
        debugPrint(
            'CPF não encontrado no perfil, usando CPF de teste: $userCpf');
        _log('Dica: Atualize seu perfil para usar seu CPF real');
      }

      final deviceSessionId = _effectiveDeviceSessionId();
      final headers = {
        'Content-Type': 'application/json',
        'x-idempotency-key': const Uuid().v4(),
        if (deviceSessionId != null) 'x-meli-session-id': deviceSessionId,
      };

      final items = _buildPaymentItems();
      final notificationUrl = EnvironmentConfig.mpNotificationUrlValue;
      final externalReference = _buildExternalReference();
      final requestBody = {
        'amount': widget.amount,
        'description': widget.serviceDescription,
        'paymentMethod': 'pix',
        // Itens do pedido (nome, código, categoria, descrição, preço)
        'items': items,
        // Alguns backends/MP usam additional_info.items
        'additional_info': {'items': items},
        if (notificationUrl.isNotEmpty) 'notificationUrl': notificationUrl,
        if (deviceSessionId != null) 'deviceId': deviceSessionId,
        // Ajuda conciliar pagamento/agendamento (camelCase conforme backend)
        'externalReference': externalReference,
        // Mantém compatibilidade caso o backend/MP espere snake_case
        'external_reference': externalReference,
        'metadata': {
          'appointmentId': widget.appointmentId,
          'carId': widget.carId,
          'carModel': widget.carModel,
          'carPlate': widget.carPlate,
        },
        'payer': {
          'email': userEmail,
          'firstName': userFirstName,
          'lastName': userLastName,
          'cpf': userCpf,
        }
      };
      _log('Enviando requisição de pagamento (PIX).');

      debugPrint('=== DEBUG: Enviando requisição para o backend ===');
      debugPrint('URL final: ${BackendUrl.baseUrl}/create-payment');
      debugPrint('Headers: $headers');
      _log('Enviando requisição de pagamento (PIX).');

      final response = await http
          .post(
            Uri.parse('${BackendUrl.baseUrl}/create-payment'),
            headers: headers,
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('=== DEBUG: Resposta recebida ===');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Headers: ${response.headers}');
      _log('Resposta PIX recebida (status=${response.statusCode}).');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Resposta do backend:');
        try {
          debugPrint('Tipo da resposta: ${data.runtimeType}');
          if (data is Map) {
            debugPrint('Keys da resposta: ${data.keys.toList()}');
          } else {
            debugPrint('Resposta não é um Map');
          }
        } catch (e) {
          debugPrint('Erro ao imprimir dados da resposta: $e');
        }

        // Verificação mais robusta do QR code
        String? qr;
        try {
          final pointOfInteraction = data['point_of_interaction'];
          if (pointOfInteraction != null &&
              pointOfInteraction is Map<String, dynamic>) {
            final transactionData = pointOfInteraction['transaction_data'];
            if (transactionData != null &&
                transactionData is Map<String, dynamic>) {
              final qrCode = transactionData['qr_code'];
              if (qrCode != null && qrCode is String) {
                qr = qrCode;
              }
            }
          }
        } catch (e) {
          debugPrint('Erro ao extrair QR code: $e');
          qr = null;
        }

        debugPrint('QR recebido: $qr');

        if (qr != null && qr.isNotEmpty) {
          debugPrint(
              '=== DEBUG: Definindo _isProcessing como false (sucesso) ===');

          // Verificação segura do ID do pagamento
          String? paymentId;
          try {
            final id = data['id'];
            if (id != null) {
              if (id is String) {
                paymentId = id;
              } else if (id is int) {
                paymentId = id.toString();
              } else if (id is double) {
                paymentId = id.toInt().toString();
              } else {
                debugPrint('Tipo inesperado para ID: ${id.runtimeType}');
                paymentId = null;
              }
            }
          } catch (e) {
            debugPrint('Erro ao extrair ID do pagamento: $e');
            paymentId = null;
          }

          setState(() {
            _pixQrCode = qr;
            _paymentId = paymentId;
            _isProcessing = false;
          });
          _startStatusPolling();
          debugPrint('QR Code gerado com sucesso!');
        } else {
          throw ('QR Code não foi gerado pelo backend');
        }
      } else {
        final errorData = jsonDecode(response.body);
        String userFriendlyMessage = 'Não foi possível processar o pagamento';

        // Tratamento específico de erros com mensagens amigáveis
        if (errorData['message'] != null) {
          userFriendlyMessage = errorData['message'];
        } else if (errorData['error'] != null) {
          final error = errorData['error'];
          if (error is String) {
            // Tratamento especial para erros conhecidos
            if (error.contains('Parâmetros obrigatórios ausentes')) {
              userFriendlyMessage =
                  'Dados incompletos. Verifique se todos os campos estão preenchidos corretamente.';
            } else if (error.contains('QR Code')) {
              userFriendlyMessage =
                  'Não foi possível gerar o QR Code PIX. Tente novamente.';
            } else {
              userFriendlyMessage = error;
            }
          } else if (error is Map && error['message'] != null) {
            userFriendlyMessage = error['message'];
          } else if (error is Map && error['error'] != null) {
            userFriendlyMessage = 'Erro: ${error['error']}';
          }
        }

        // Mapeamento de códigos de status para mensagens amigáveis
        switch (response.statusCode) {
          case 400:
            if (userFriendlyMessage.contains('QR Code')) {
              userFriendlyMessage =
                  'Não foi possível gerar o QR Code PIX. Verifique se a conta está configurada corretamente.';
            } else if (userFriendlyMessage.contains('BIN')) {
              userFriendlyMessage =
                  'Dados do cartão inválidos. Verifique o número, data de validade e CVV.';
            }
            break;
          case 401:
            userFriendlyMessage =
                'Erro de autenticação. Entre em contato com o suporte.';
            break;
          case 408:
            userFriendlyMessage =
                'A requisição demorou muito para responder. Tente novamente.';
            break;
          case 503:
            userFriendlyMessage =
                'Serviço temporariamente indisponível. Tente novamente em alguns instantes.';
            break;
          default:
            userFriendlyMessage =
                'Erro inesperado. Tente novamente ou entre em contato com o suporte.';
        }

        debugPrint('=== DEBUG: Definindo _isProcessing como false (erro) ===');
        setState(() {
          _errorMessage = userFriendlyMessage;
          _isProcessing = false;
        });

        _showRetryButton();
      }
    } catch (e) {
      debugPrint('=== DEBUG: Erro na requisição ===');
      debugPrint('Erro: $e');
      debugPrint('=== DEBUG: Definindo _isProcessing como false (exceção) ===');

      String userFriendlyMessage = 'Erro inesperado. Tente novamente.';

      // Tratamento específico de exceções
      if (e.toString().contains('TimeoutException')) {
        userFriendlyMessage =
            'A requisição demorou muito para responder. Verifique sua conexão com a internet e tente novamente.';
      } else if (e.toString().contains('SocketException')) {
        userFriendlyMessage =
            'Não foi possível conectar com o servidor. Verifique sua conexão com a internet.';
      } else if (e.toString().contains('HandshakeException')) {
        userFriendlyMessage =
            'Erro de conexão segura. Verifique sua conexão com a internet.';
      } else if (e.toString().contains('QR Code não foi gerado')) {
        userFriendlyMessage =
            'Não foi possível gerar o QR Code PIX. Tente novamente ou entre em contato com o suporte.';
      } else if (e.toString().contains('is not a subtype of type')) {
        userFriendlyMessage =
            'Erro no formato da resposta do servidor. Tente novamente ou entre em contato com o suporte.';
      }

      setState(() {
        _errorMessage = userFriendlyMessage;
        _isProcessing = false;
      });

      _showRetryButton();
    }
  }

  void _showRetryButton() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.refresh, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Erro no pagamento. Toque para tentar novamente.'),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Tentar',
            textColor: Colors.white,
            onPressed: () {
              _criarPagamentoPix();
            },
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();
    if (_paymentId == null || _isDisposed) return;

    _checkPixPaymentStatus();

    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_isDisposed) {
        _checkPixPaymentStatus();
      }
    });
  }

  Future<void> _checkPixPaymentStatus() async {
    if (_paymentId == null || _isDisposed) return;

    final status = await _consultarStatusPagamento();
    if (status == 'approved') {
      _statusTimer?.cancel();
      if (mounted && !_isDisposed) {
        await _onPaymentSuccess();
      }
    } else if (status == 'rejected' || status == 'cancelled') {
      _statusTimer?.cancel();
      if (mounted && !_isDisposed) {
        setState(() {
          _errorMessage = 'Pagamento foi rejeitado ou cancelado.';
          _isProcessing = false;
        });
      }
    }
  }

  Future<String?> _consultarStatusPagamento() async {
    if (_paymentId == null) return null;
    try {
      final deviceSessionId = _effectiveDeviceSessionId();
      final response = await http.get(
        Uri.parse('${BackendUrl.baseUrl}/payment-status/$_paymentId'),
        headers: {
          'x-idempotency-key': const Uuid().v4(),
          if (deviceSessionId != null) 'x-meli-session-id': deviceSessionId,
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _onPaymentSuccess() async {
    debugPrint('=== DEBUG: _onPaymentSuccess chamada ===');
    debugPrint('balanceToUse: ${widget.balanceToUse}');
    debugPrint('appointmentId: ${widget.appointmentId}');
    debugPrint('isDisposed: $_isDisposed');

    // Verificar se a tela foi descartada antes de processar
    if (_isDisposed) {
      debugPrint('=== DEBUG: Tela descartada, cancelando processamento ===');
      return;
    }

    try {
      // Se houver saldo a usar (pagamento misto), debitar SOMENTE agora (pagamento aprovado).
      await _debitWalletBalanceIfNeeded();

      // Salvar informações do pagamento para possível devolução futura
      await _savePaymentInfo();

      if (widget.appointmentId.isNotEmpty) {
        debugPrint('=== DEBUG: Atualizando status do agendamento ===');
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(widget.appointmentId)
            .update({'status': 'confirmed'});
      }
      if (mounted && !_isDisposed) {
        debugPrint('=== DEBUG: Navegando para HomeScreen ===');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(authService: AuthService()),
            settings: const RouteSettings(arguments: 'pagamento_sucesso'),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Erro ao processar pagamento com saldo: $e');
    }
  }

  Future<void> _debitWalletBalanceIfNeeded() async {
    if (_walletDebitProcessed) return;
    final walletToUse = widget.balanceToUse ?? 0.0;
    if (walletToUse <= 0) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw ('Usuário não autenticado');

    // Idempotência entre telas/dispositivos: marca no appointment que o débito do saldo já foi feito.
    final appointmentRef = FirebaseFirestore.instance
        .collection('appointments')
        .doc(widget.appointmentId);
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final transactionsRef =
        FirebaseFirestore.instance.collection('transactions');

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final appointmentDoc = await tx.get(appointmentRef);
      final alreadyDebited = appointmentDoc.data()?['walletDebitedAt'] != null;
      if (alreadyDebited) return;

      final userDoc = await tx.get(userRef);
      final currentBalance = (userDoc.data()?['balance'] ?? 0.0).toDouble();
      final finalBalance = currentBalance - walletToUse;
      if (finalBalance < 0) {
        throw ('Saldo insuficiente para completar o pagamento.');
      }

      tx.update(userRef, {'balance': finalBalance});

      final transactionDoc = transactionsRef.doc();
      tx.set(transactionDoc, {
        'userId': user.uid,
        'amount': walletToUse,
        'type': 'debit',
        'description': 'Pagamento (saldo) - ${widget.serviceTitle}',
        'appointmentId': widget.appointmentId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.update(appointmentRef, {
        'walletDebitedAt': FieldValue.serverTimestamp(),
        'walletDebitedAmount': walletToUse,
      });
    });

    _walletDebitProcessed = true;
  }

  Future<void> _savePaymentInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Determinar método de pagamento
      String paymentMethod;
      bool canRefund;

      // Mesmo usando saldo, aqui registramos o método do "restante" (PIX/Cartão).
      // O valor usado do saldo fica em balanceUsed.
      paymentMethod = 'pix';
      canRefund = true;

      // Salvar informações do pagamento para devolução futura
      await FirebaseFirestore.instance.collection('payments').add({
        'userId': user.uid,
        'appointmentId': widget.appointmentId,
        'amount': widget.amount,
        'paymentMethod': paymentMethod,
        'isMixedPayment': (widget.balanceToUse ?? 0.0) > 0,
        'serviceTitle': widget.serviceTitle,
        'serviceDescription': widget.serviceDescription,
        'carId': widget.carId,
        'carModel': widget.carModel,
        'carPlate': widget.carPlate,
        'status': 'paid',
        'canRefund': canRefund,
        'balanceUsed': widget.balanceToUse ?? 0.0, // Valor usado do saldo
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint(
          '=== DEBUG: Informações do pagamento salvas para devolução futura ===');
      debugPrint('PaymentMethod: $paymentMethod');
      debugPrint('CanRefund: $canRefund');
      debugPrint('BalanceUsed: ${widget.balanceToUse ?? 0.0}');
    } catch (e) {
      debugPrint('Erro ao salvar informações do pagamento: $e');
    }
  }

  String _formatCpf(String cpf) {
    try {
      final cleanCpf = cpf.replaceAll(RegExp(r'[^\d]'), '');
      if (cleanCpf.length == 11) {
        return cleanCpf.replaceAllMapped(
            RegExp(r'(\d{3})(\d{3})(\d{3})(\d{2})'), (Match m) {
          final group1 = m.group(1);
          final group2 = m.group(2);
          final group3 = m.group(3);
          final group4 = m.group(4);
          if (group1 != null &&
              group2 != null &&
              group3 != null &&
              group4 != null) {
            return '$group1.$group2.$group3-$group4';
          }
          return cleanCpf;
        });
      }
      return cpf;
    } catch (e) {
      _log('Erro ao formatar CPF: $e');
      return cpf;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Pagamento'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            if (!mounted) return;
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),

          // Informação sobre saldo usado (se aplicável)
          if (widget.balanceToUse != null && widget.balanceToUse! > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: Colors.blue[700],
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saldo usado: R\$ ${widget.balanceToUse!.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Valor restante: R\$ ${widget.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.blue[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPaymentOptionCard(
                  selected: !_enableCardPayment || _selectedTab == 0,
                  icon: Image.asset('assets/images/pix.png',
                      height: 40, width: 40),
                  label: 'Pix',
                  onTap: () => setState(() => _selectedTab = 0),
                  color: Colors.green,
                ),
                if (_enableCardPayment) ...[
                  const SizedBox(width: 24),
                  _buildPaymentOptionCard(
                    selected: _selectedTab == 1,
                    icon: const Icon(Icons.credit_card,
                        size: 40, color: Colors.white),
                    label: 'Cartão',
                    onTap: () => setState(() => _selectedTab = 1),
                    color: Colors.blue,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: (_enableCardPayment && _selectedTab == 1)
                  ? PayWithCreditCard(
                      amount: widget.amount,
                      serviceTitle: widget.serviceTitle,
                      serviceDescription: widget.serviceDescription,
                      carId: widget.carId,
                      carModel: widget.carModel,
                      carPlate: widget.carPlate,
                      appointmentId: widget.appointmentId,
                      balanceToUse: widget.balanceToUse ?? 0.0,
                      onPaymentSuccess: _onPaymentSuccess,
                    )
                  : _buildPixWidget(),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPaymentOptionCard({
    required bool selected,
    required Widget icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 3 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPixWidget() {
    debugPrint(
        '=== DEBUG: _buildPixWidget chamado - _isProcessing: $_isProcessing ===');

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Valor a pagar: R\$ ${widget.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // APENAS UMA MENSAGEM DE CARREGAMENTO
            if (_isProcessing) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Gerando QR Code PIX...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Isso pode levar alguns segundos',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[600],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Indicador do CPF sendo usado - APENAS QUANDO NÃO ESTÁ PROCESSANDO
              if (_userCpf != null && _userCpf!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'CPF: ${_formatCpf(_userCpf!)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            // QR Code
            if (_pixQrCode != null && _pixQrCode!.isNotEmpty && !_isProcessing)
              Container(
                constraints: const BoxConstraints(maxWidth: 300),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.3),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    QrImageView(
                      data: _pixQrCode!,
                      size: 180.0,
                      backgroundColor: Colors.white,
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Escaneie o QR Code acima',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _copyQrCodeToClipboard,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text(
                        'Copiar Código PIX',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red[600],
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Erro de Conexão',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Não foi possível conectar ao servidor de pagamento.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red[600],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing
                            ? null
                            : () {
                                setState(() {
                                  _errorMessage = null;
                                  _isProcessing = false;
                                });
                                _criarPagamentoPix();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.refresh, size: 20),
                        label: Text(
                          _isProcessing ? 'Tentando...' : 'Tentar Novamente',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

}