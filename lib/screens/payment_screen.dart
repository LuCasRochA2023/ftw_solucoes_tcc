import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:ftw_solucoes/screens/profile_screen.dart';
import '../services/auth_service.dart';
import 'package:flutter/services.dart';
import 'package:ftw_solucoes/screens/home_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../utils/backend_url.dart';
import '../utils/environment_config.dart';
import '../utils/mp_device_session/mp_device_session.dart';
import '../utils/mp_device_session/mp_device_session_mobile.dart';

class PaymentScreen extends StatefulWidget {
  final double amount;
  final String serviceTitle;
  final String serviceDescription;
  final String carId;
  final String carModel;
  final String carPlate;
  final String appointmentId;
  final double? balanceToUse;

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
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  // Mantemos o código de cartão no arquivo para uso futuro, mas desabilitamos
  // a opção na UI (somente PIX) conforme solicitado.
  static const bool _enableCardPayment = false;

  bool _isProcessing = false;
  String? _errorMessage;
  String? _pixQrCode;
  String? _paymentId;
  Timer? _statusTimer;
  int _selectedTab = 0; // 0 = Pix, 1 = Cartão (desabilitado se _enableCardPayment=false)
  bool _isInitialized = false; // Flag para evitar inicialização duplicada
  bool _isDisposed = false; // Flag para controlar se a tela foi descartada
  bool _walletDebitProcessed = false; // Evita debitar saldo 2x no mesmo fluxo

  // Campos do formulário de cartão
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isCardProcessing = false;
  String? _cardError;
  String? _cardSuccess;
  String? _userCpf;

  String _onlyDigits(String s) => s.replaceAll(RegExp(r'\D'), '');

  bool _isValidLuhn(String digits) {
    int sum = 0;
    bool alternate = false;
    for (int i = digits.length - 1; i >= 0; i--) {
      int n = int.tryParse(digits[i]) ?? 0;
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  String? _validateCardNumber(String? v) {
    final raw = (v ?? '').trim();
    if (raw.isEmpty) return 'Informe o número do cartão';
    final digits = _onlyDigits(raw);
    if (digits.length < 13 || digits.length > 19)
      return 'Número do cartão inválido';
    if (RegExp(r'^(\d)\1+$').hasMatch(digits))
      return 'Número do cartão inválido';
    if (!_isValidLuhn(digits)) return 'Número do cartão inválido';
    return null;
  }

  String? _validateExpiry(String? v) {
    final raw = (v ?? '').trim();
    if (raw.isEmpty) return 'Informe a validade (MM/AA)';
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(raw))
      return 'Validade inválida (use MM/AA)';
    final parts = raw.split('/');
    final month = int.tryParse(parts[0]);
    final year2 = int.tryParse(parts[1]);
    if (month == null || year2 == null) return 'Validade inválida';
    if (month < 1 || month > 12) return 'Mês inválido';
    final year = 2000 + year2;
    final now = DateTime.now();
    final lastMomentOfMonth =
        DateTime(year, month + 1, 1).subtract(const Duration(milliseconds: 1));
    if (lastMomentOfMonth.isBefore(now)) return 'Cartão vencido';
    return null;
  }

  String? _validateCvv(String? v) {
    final raw = (v ?? '').trim();
    if (raw.isEmpty) return 'Informe o CVV';
    final digits = _onlyDigits(raw);
    if (digits.length < 3 || digits.length > 4) return 'CVV inválido';
    return null;
  }

  String? _validateCardholderName(String? v) {
    final name = (v ?? '').trim();
    if (name.isEmpty) return 'Informe o nome do titular';
    if (name.length < 3) return 'Nome do titular inválido';
    final parts =
        name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length < 2) return 'Informe nome e sobrenome';
    return null;
  }

  String _friendlyMpTokenizationError(
      int statusCode, Map<String, dynamic>? data) {
    final msg = (data?['message'] as String?) ?? '';
    if (statusCode == 404 && msg.contains('not found public_key')) {
      return 'Configuração do Mercado Pago inválida (public key). Verifique o arquivo .env.';
    }
    if (statusCode == 400) {
      return 'Dados do cartão inválidos. Verifique número, validade e CVV.';
    }
    return 'Não foi possível validar o cartão. Tente novamente.';
  }

  String _friendlyMpRejection(String? statusDetail) {
    switch (statusDetail) {
      case 'cc_rejected_bad_filled_card_number':
        return 'Número do cartão inválido. Verifique e tente novamente.';
      case 'cc_rejected_bad_filled_date':
        return 'Validade inválida. Verifique mês/ano do cartão.';
      case 'cc_rejected_bad_filled_security_code':
        return 'CVV inválido. Verifique o código de segurança.';
      case 'cc_rejected_other_reason':
        return 'Pagamento recusado. Tente outro cartão ou contate o banco.';
      case 'cc_rejected_insufficient_amount':
        return 'Pagamento recusado por saldo insuficiente no cartão.';
      case 'cc_rejected_call_for_authorize':
        return 'Pagamento recusado. Entre em contato com o banco para autorizar.';
      case 'cc_rejected_high_risk':
        return 'Pagamento recusado por segurança. Tente outro cartão.';
      case 'cc_rejected_max_attempts':
        return 'Muitas tentativas. Aguarde um pouco e tente novamente.';
      case 'cc_rejected_blacklist':
        return 'Pagamento recusado. Tente outro cartão.';
      case 'cc_rejected_card_disabled':
        return 'Cartão desabilitado. Verifique com o banco.';
      case 'cc_rejected_card_error':
        return 'Erro no cartão. Verifique os dados ou tente outro cartão.';
      case 'cc_rejected_duplicated_payment':
        return 'Pagamento duplicado detectado. Verifique se já foi cobrado.';
      default:
        return 'Pagamento recusado. Verifique os dados ou tente outro cartão.';
    }
  }

  String _getItemCategoryId() {
    // Formato esperado no backend/MP (conforme exemplo do usuário)
    return 'services';
  }

  String _buildItemId() {
    // Ex.: "lavagem_001"
    final t = widget.serviceTitle.toLowerCase();
    if (t.contains('lavagem') && t.contains('carro comum'))
      return 'lavagem_001';
    if (t.contains('lavagem') && t.contains('suv')) return 'lavagem_002';
    if (t.contains('lavagem') && t.contains('caminhonete'))
      return 'lavagem_003';
    if (t.contains('leva') && t.contains('traz')) return 'leva_traz_001';

    // Fallback (nunca vazio)
    if (widget.appointmentId.isNotEmpty) return widget.appointmentId;
    return 'service_item';
  }

  List<Map<String, dynamic>> _buildPaymentItems() {
    // Formato EXATO solicitado:
    // "items":[{"id":"lavagem_001","title":"...","description":"...","category_id":"services","quantity":1,"unit_price":70.0}]
    final totalServicePrice = widget.amount + (widget.balanceToUse ?? 0.0);
    return [
      {
        'id': _buildItemId(),
        'title': widget.serviceTitle,
        'description': widget.serviceDescription,
        'category_id': _getItemCategoryId(),
        'quantity': 1,
        'unit_price': totalServicePrice,
      }
    ];
  }

  String _buildExternalReference() {
    // ID interno para correlação (ex.: "agendamento_98765")
    final id = widget.appointmentId.trim();
    if (id.isEmpty) return 'agendamento_desconhecido';
    if (id.startsWith('agendamento_')) return id;
    return 'agendamento_$id';
  }

  String? _getDeviceSessionId() {
    try {
      return getMpDeviceSessionId();
    } catch (_) {
      return null;
    }
  }

  String? _deviceSessionIdMobile;

  Future<void> _ensureDeviceSessionIdMobile() async {
    // No Web, já pegamos direto via JS context (MP_DEVICE_SESSION_ID).
    final webId = _getDeviceSessionId();
    if (webId != null) return;

    if (_deviceSessionIdMobile != null && _deviceSessionIdMobile!.isNotEmpty) {
      return;
    }

    final v = await MpDeviceSessionMobile.instance.getOrCreate();
    if (!mounted) return;
    if (v != null && v.trim().isNotEmpty) {
      setState(() {
        _deviceSessionIdMobile = v.trim();
      });
    }
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
    // Inicializar imediatamente sem delay
    // Gera MP_DEVICE_SESSION_ID no mobile via WebView invisível (requisito do MP).
    unawaited(_ensureDeviceSessionIdMobile());
    _initializePayment();
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

    // Primeiro carregar o CPF, depois criar o pagamento
    await _loadUserCpf();
    await _criarPagamentoPix();
    debugPrint('=== DEBUG: Inicialização concluída ===');
  }

  @override
  void dispose() {
    _isDisposed = true;
    _statusTimer?.cancel();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserCpf() async {
    debugPrint('=== DEBUG: Carregando CPF do usuário ===');
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        debugPrint('Usuário autenticado: ${user.uid}');

        // Usar timeout mais curto para carregamento mais rápido
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 5));

        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          debugPrint('Dados do usuário: $data');
          final cpf = data['cpf'] ?? '';

          if (cpf.isNotEmpty) {
            setState(() {
              _userCpf = cpf;
            });
            debugPrint('CPF carregado do perfil: $cpf');
            debugPrint('CPF limpo: ${cpf.replaceAll(RegExp(r'[^\d]'), '')}');
            debugPrint('CPF armazenado em _userCpf: $_userCpf');
          } else {
            debugPrint('CPF não encontrado no perfil do usuário');
            setState(() {
              _userCpf = null;
            });
          }
        } else {
          debugPrint('Documento do usuário não encontrado');
          setState(() {
            _userCpf = null;
          });
        }
      } else {
        debugPrint('Usuário não autenticado');
        setState(() {
          _userCpf = null;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar CPF do usuário: $e');
      setState(() {
        _userCpf = null;
      });
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
      debugPrint('CPF atual: $_userCpf');

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
          debugPrint('Usando CPF do perfil: $userCpf');
        } else {
          debugPrint('CPF do perfil inválido: $_userCpf (limpo: $cleanCpf)');
          debugPrint('Usando CPF de teste: $userCpf');
        }
      } else {
        debugPrint(
            'CPF não encontrado no perfil, usando CPF de teste: $userCpf');
        debugPrint('Dica: Atualize seu perfil para usar seu CPF real');
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
        if (notificationUrl != null) 'notificationUrl': notificationUrl,
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
      debugPrint('Body: ${jsonEncode(requestBody)}');

      debugPrint('=== DEBUG: Enviando requisição para o backend ===');
      debugPrint('URL final: ${BackendUrl.baseUrl}/create-payment');
      debugPrint('Headers: $headers');
      debugPrint('Body: ${jsonEncode(requestBody)}');

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
      debugPrint('Response Body: ${response.body}');

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

  static String get mpPublicKey => EnvironmentConfig.mercadopagoPublicKeyValue;

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
      debugPrint('Erro ao formatar CPF: $e');
      return cpf;
    }
  }

  Future<String?> gerarTokenCartao({
    required String cardNumber,
    required String expirationMonth,
    required String expirationYear,
    required String cvv,
    required String cardholderName,
    required String cpf,
  }) async {
    debugPrint('=== DEBUG: Gerando token do cartão ===');

    final url = Uri.parse(
      'https://api.mercadopago.com/v1/card_tokens?public_key=$mpPublicKey',
    );

    // MP pode exigir "Identificador do dispositivo" já na tokenização.
    // No Web vem do security.js; no mobile geramos via WebView invisível.
    await _ensureDeviceSessionIdMobile();
    final deviceSessionId = _effectiveDeviceSessionId();

    final cleanCpf = cpf.replaceAll(RegExp(r'[^\d]'), '');
    final cleanCard = cardNumber.replaceAll(' ', '');

    if (cleanCpf.isEmpty) {
      debugPrint('Erro: CPF não fornecido para tokenização');
      return null;
    }

    debugPrint('CPF para tokenização: $cleanCpf');
    debugPrint('Nome do titular: $cardholderName');
    debugPrint(
        'Número do cartão: ${cleanCard.substring(0, 4)}...${cleanCard.substring(cleanCard.length - 4)}');
    debugPrint('Validade: $expirationMonth/$expirationYear');

    final requestBody = {
      'card_number': cleanCard,
      'expiration_month': int.parse(expirationMonth),
      'expiration_year': expirationYear.length == 2
          ? int.parse('20$expirationYear')
          : int.parse(expirationYear),
      'security_code': cvv,
      'cardholder': {
        'name': cardholderName,
        'identification': {
          'type': 'CPF',
          'number': cleanCpf,
        },
      },
    };

    debugPrint('Request Body para tokenização: ${jsonEncode(requestBody)}');

    debugPrint(
        '=== DEBUG: Enviando requisição para Mercado Pago (tokenização) ===');
    debugPrint('URL: $url');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (deviceSessionId != null) 'x-meli-session-id': deviceSessionId,
    };
    debugPrint('Headers: ${jsonEncode(headers)}');
    debugPrint('Body: ${jsonEncode(requestBody)}');

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(requestBody),
    );

    debugPrint('=== DEBUG: Resposta da tokenização ===');
    debugPrint('Status Code: ${response.statusCode}');
    debugPrint('Response Headers: ${response.headers}');
    debugPrint('Response Body: ${response.body}');

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);

      // Verificação segura do ID do token
      String? tokenId;
      try {
        final id = data['id'];
        if (id != null) {
          if (id is String) {
            tokenId = id;
          } else if (id is int) {
            tokenId = id.toString();
          } else if (id is double) {
            tokenId = id.toInt().toString();
          } else {
            debugPrint('Tipo inesperado para ID do token: ${id.runtimeType}');
            tokenId = null;
          }
        }
      } catch (e) {
        debugPrint('Erro ao extrair ID do token: $e');
        tokenId = null;
      }

      debugPrint('Token gerado com sucesso: $tokenId');
      return tokenId;
    } else {
      Map<String, dynamic>? errorData;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          errorData = decoded;
        }
      } catch (_) {
        errorData = null;
      }
      debugPrint(
          'Erro ao gerar token: ${jsonEncode(errorData ?? response.body)}');
      if (mounted) {
        setState(() {
          _cardError =
              _friendlyMpTokenizationError(response.statusCode, errorData);
        });
      }
      return null;
    }
  }

  Future<void> _checkPaymentStatus(String paymentId) async {
    try {
      debugPrint('=== DEBUG: Verificando status do pagamento ===');
      debugPrint('Payment ID: $paymentId');

      final deviceSessionId = _effectiveDeviceSessionId();
      final response = await http.get(
        Uri.parse('${BackendUrl.baseUrl}/payment-status/$paymentId'),
        headers: {
          'Content-Type': 'application/json',
          if (deviceSessionId != null) 'x-meli-session-id': deviceSessionId,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['status'] as String?;
        final statusDetail = data['status_detail'] as String?;

        debugPrint('Status atualizado: $status - $statusDetail');

        if (status == 'approved') {
          debugPrint('Pagamento aprovado!');
          await _onPaymentSuccess();
        } else if (status == 'in_process') {
          debugPrint('Ainda em processamento...');
          setState(() {
            _cardError =
                'Pagamento ainda em processamento. Aguarde mais um pouco.';
          });
        } else if (status == 'rejected') {
          debugPrint('Pagamento rejeitado');
          setState(() {
            _cardError = 'Pagamento rejeitado: $statusDetail';
          });
        }
      } else {
        debugPrint('Erro ao verificar status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Erro ao verificar status do pagamento: $e');
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
          onPressed: () {
            // Se há saldo sendo usado, mostrar confirmação
            if (widget.balanceToUse != null && widget.balanceToUse! > 0) {
              final navigatorContext = context;
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cancelar Pagamento'),
                  content: Text(
                      'Você está usando R\$ ${widget.balanceToUse!.toStringAsFixed(2)} do seu saldo. '
                      'Se cancelar agora, você voltará para a tela inicial. O agendamento permanecerá ativo e o saldo não será alterado. '
                      'Deseja continuar?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Continuar Pagamento'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        debugPrint(
                            '=== DEBUG: Botão Voltar ao Início pressionado ===');

                        // Fechar dialog primeiro
                        Navigator.pop(context);
                        debugPrint('=== DEBUG: Dialog fechado ===');

                        // Apenas voltar para tela inicial, sem cancelar agendamento
                        debugPrint(
                            '=== DEBUG: Voltando para tela inicial sem cancelar ===');

                        // Voltar para tela inicial
                        if (mounted) {
                          debugPrint(
                              '=== DEBUG: Tentando voltar para tela inicial ===');
                          Navigator.pushAndRemoveUntil(
                            navigatorContext,
                            MaterialPageRoute(
                              builder: (context) =>
                                  HomeScreen(authService: AuthService()),
                            ),
                            (route) =>
                                false, // Remove todas as rotas anteriores
                          );
                          debugPrint(
                              '=== DEBUG: Navegação para tela inicial executada ===');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Voltar ao Início'),
                    ),
                  ],
                ),
              );
            } else {
              // Se não há saldo, voltar normalmente
              Navigator.pop(context);
            }
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
                  ? _buildCreditCardWidget()
                  : _buildPixWidget(),
            ),
          ),
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

              // Aviso se CPF não encontrado
              if (_userCpf == null || _userCpf!.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'CPF não encontrado no perfil. Atualize seu perfil para usar seu CPF real.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProfileScreen(
                                        authService: AuthService()),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.person),
                              label: const Text('Ir ao Perfil'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _criarPagamentoPix();
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tentar PIX'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildCreditCardWidget() {
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
            const Text(
              'Pagamento com Cartão',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _cardNumberController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(19),
                      _CardNumberInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Número do Cartão',
                      prefixIcon: const Icon(Icons.credit_card),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 18, horizontal: 16),
                      hintText: '1234 5678 9012 3456',
                    ),
                    validator: _validateCardNumber,
                  ),
                  const SizedBox(height: 20),
                  Column(
                    children: [
                      TextFormField(
                        controller: _expiryController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                          _ExpiryDateInputFormatter(),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Validade (MM/AA)',
                          prefixIcon: const Icon(Icons.date_range),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 18, horizontal: 16),
                          hintText: '12/25',
                        ),
                        validator: _validateExpiry,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _cvvController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: InputDecoration(
                          labelText: 'CVV',
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 18, horizontal: 16),
                          hintText: '123',
                        ),
                        validator: _validateCvv,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Nome no Cartão',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 18, horizontal: 16),
                    ),
                    validator: _validateCardholderName,
                  ),
                  const SizedBox(height: 20),
                  if (_userCpf != null && _userCpf!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.badge, color: Colors.grey),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CPF do Titular',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  _userCpf!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange[600]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CPF não encontrado',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.orange[700],
                                  ),
                                ),
                                Text(
                                  'Atualize seu perfil para incluir o CPF',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (_cardError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_cardError!,
                    style: const TextStyle(color: Colors.red)),
              ),
            if (_cardSuccess != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_cardSuccess!,
                    style: const TextStyle(color: Colors.green)),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.credit_card),
                label: _isCardProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Pagar com Cartão',
                        style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                onPressed: _isCardProcessing
                    ? null
                    : () async {
                        debugPrint(
                            '=== DEBUG: Botão de pagamento pressionado ===');
                        debugPrint(
                            'Formulário válido: ${_formKey.currentState?.validate() ?? false}');
                        debugPrint('CPF carregado: $_userCpf');
                        debugPrint('Nome: ${_nameController.text}');
                        debugPrint('Cartão: ${_cardNumberController.text}');
                        debugPrint('Validade: ${_expiryController.text}');
                        debugPrint('CVV: ${_cvvController.text}');

                        debugPrint(
                            '=== DEBUG: Verificando validação do formulário ===');
                        final isValid =
                            _formKey.currentState?.validate() ?? false;
                        debugPrint('Formulário válido: $isValid');

                        if (isValid) {
                          // Verificar se o CPF foi carregado
                          debugPrint('=== DEBUG: Verificando CPF ===');
                          debugPrint('CPF atual: $_userCpf');
                          if (_userCpf == null || _userCpf!.isEmpty) {
                            debugPrint(
                                'CPF não carregado, tentando carregar novamente...');
                            await _loadUserCpf();
                            debugPrint('CPF após recarregar: $_userCpf');
                            if (_userCpf == null || _userCpf!.isEmpty) {
                              setState(() {
                                _cardError =
                                    'CPF não encontrado no perfil. Por favor, atualize seu perfil primeiro.';
                              });
                              return;
                            }
                          }

                          debugPrint(
                              '=== DEBUG: Verificando campos do formulário ===');
                          debugPrint('Nome: "${_nameController.text}"');
                          debugPrint('Cartão: "${_cardNumberController.text}"');
                          debugPrint('Validade: "${_expiryController.text}"');
                          debugPrint('CVV: "${_cvvController.text}"');

                          setState(() {
                            _isCardProcessing = true;
                            _cardError = null;
                            _cardSuccess = null;
                          });
                          final exp = _expiryController.text.split('/');
                          debugPrint('Validade dividida: $exp');
                          if (exp.length != 2) {
                            debugPrint('Erro: Validade inválida');
                            setState(() {
                              _cardError = 'Validade inválida';
                              _isCardProcessing = false;
                            });
                            return;
                          }

                          // Verificar se são números válidos
                          final month = exp[0].trim();
                          final year = exp[1].trim();
                          if (month.isEmpty ||
                              year.isEmpty ||
                              int.tryParse(month) == null ||
                              int.tryParse(year) == null) {
                            debugPrint('Erro: Mês ou ano inválido');
                            setState(() {
                              _cardError = 'Formato de data inválido';
                              _isCardProcessing = false;
                            });
                            return;
                          }
                          debugPrint('CPF antes da tokenização: $_userCpf');
                          debugPrint(
                              'CPF está vazio? ${_userCpf == null || _userCpf!.isEmpty}');
                          debugPrint(
                              'CPF é o de teste? ${_userCpf == '03557007197'}');
                          debugPrint(
                              'CPF limpo: ${_userCpf?.replaceAll(RegExp(r'[^\d]'), '')}');
                          debugPrint('=== DEBUG: Antes de gerar token ===');
                          debugPrint('CPF para tokenização: $_userCpf');
                          debugPrint(
                              'Nome do titular: ${_nameController.text}');
                          debugPrint(
                              'Número do cartão: ${_cardNumberController.text}');
                          debugPrint('Validade: ${_expiryController.text}');

                          final cardToken = await gerarTokenCartao(
                            cardNumber: _cardNumberController.text,
                            expirationMonth: month,
                            expirationYear: year,
                            cvv: _cvvController.text,
                            cardholderName: _nameController.text,
                            cpf: _userCpf!, // Usar CPF do usuário
                          );
                          debugPrint('=== DEBUG: Token gerado: $cardToken ===');
                          if (cardToken != null) {
                            try {
                              debugPrint(
                                  '=== DEBUG: Chamando pagarComCartao ===');
                              await pagarComCartao(cardToken);
                            } catch (e) {
                              setState(() {
                                _cardError = 'Erro ao processar pagamento: $e';
                              });
                            } finally {
                              setState(() {
                                _isCardProcessing = false;
                              });
                            }
                          } else {
                            setState(() {
                              _isCardProcessing = false;
                            });
                          }
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> pagarComCartao(String cardToken) async {
    debugPrint('=== DEBUG: Iniciando pagamento com cartão ===');
    debugPrint('URL: ${BackendUrl.baseUrl}/create-creditcard-payment');

    await _ensureDeviceSessionIdMobile();
    final deviceSessionId = _effectiveDeviceSessionId();
    final headers = {
      'Content-Type': 'application/json',
      'x-idempotency-key': const Uuid().v4(),
      if (deviceSessionId != null) 'x-meli-session-id': deviceSessionId,
    };
    debugPrint('Headers: ${jsonEncode(headers)}');

    // Usar CPF do usuário carregado do perfil
    final cleanCpf = _userCpf?.replaceAll(RegExp(r'[^\d]'), '') ?? '';
    debugPrint('CPF para pagamento: $cleanCpf');
    debugPrint('CPF original do perfil: $_userCpf');

    if (cleanCpf.isEmpty) {
      setState(() {
        _cardError =
            'CPF não encontrado no perfil. Por favor, atualize seu perfil.';
        _isCardProcessing = false;
      });
      return;
    }

    final cardholderName = _nameController.text.trim();
    if (cardholderName.isEmpty) {
      setState(() {
        _cardError = 'Nome do titular é obrigatório';
        _isCardProcessing = false;
      });
      return;
    }

    // Verificar se estamos usando dados de teste
    final cardNumber = _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
    if (cardNumber.startsWith('4509') ||
        cardNumber.startsWith('3714') ||
        cardNumber.startsWith('4000')) {
      setState(() {
        _cardError =
            'Cartão de teste detectado. Por favor, use um cartão real para pagamentos.';
        _isCardProcessing = false;
      });
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'unknown';

    final items = _buildPaymentItems();
    final notificationUrl = EnvironmentConfig.mpNotificationUrlValue;
    final externalReference = _buildExternalReference();
    final requestBody = {
      'amount': widget.amount,
      'paymentMethod': 'credit_card',
      'description': widget.serviceDescription,
      // Itens do pedido (nome, código, categoria, descrição, preço)
      'items': items,
      'additional_info': {'items': items},
      if (notificationUrl != null) 'notificationUrl': notificationUrl,
      if (deviceSessionId != null) 'deviceId': deviceSessionId,
      'externalReference': externalReference,
      'external_reference': externalReference,
      'metadata': {
        'appointmentId': widget.appointmentId,
        'carId': widget.carId,
        'carModel': widget.carModel,
        'carPlate': widget.carPlate,
      },
      'payer': {
        'email': user?.email ?? 'email@gmail.com',
        'cpf': cleanCpf,
        'firstName': cardholderName.split(' ').first,
        'lastName': cardholderName.split(' ').skip(1).join(' '),
        'userId': userId,
      },
      'cardToken': cardToken,
      'cardNumber': cardNumber,
    };
    debugPrint('Body: ${jsonEncode(requestBody)}');

    debugPrint('=== DEBUG: Enviando requisição para o backend ===');
    debugPrint('URL: ${BackendUrl.baseUrl}/create-payment');
    debugPrint('Headers: ${jsonEncode(headers)}');
    debugPrint('Body: ${jsonEncode(requestBody)}');

    final response = await http.post(
      Uri.parse('${BackendUrl.baseUrl}/create-payment'),
      headers: headers,
      body: jsonEncode(requestBody),
    );

    debugPrint('=== DEBUG: Resposta do pagamento com cartão ===');
    debugPrint('Status Code: ${response.statusCode}');
    debugPrint('Response Headers: ${response.headers}');
    debugPrint('Response Body: ${response.body}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final status = data['status'] as String?;
      final statusDetail = data['status_detail'] as String?;

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
            debugPrint(
                'Tipo inesperado para ID do pagamento: ${id.runtimeType}');
            paymentId = null;
          }
        }
      } catch (e) {
        debugPrint('Erro ao extrair ID do pagamento: $e');
        paymentId = null;
      }

      debugPrint('=== DEBUG: Status do pagamento ===');
      debugPrint('Status: $status');
      debugPrint('Status Detail: $statusDetail');
      debugPrint('Payment ID: $paymentId');

      if (status == 'approved') {
        debugPrint('Pagamento aprovado com sucesso!');
        if (mounted) {
          setState(() {
            _cardError = null;
            _cardSuccess = 'Pagamento realizado com sucesso!';
          });
        }
        await _onPaymentSuccess();
      } else if (status == 'in_process') {
        debugPrint('Pagamento em processamento');
        setState(() {
          _cardSuccess = null;
          _cardError = 'Pagamento em processamento. Aguarde a confirmação.';
        });
        // Aguardar um pouco e verificar novamente
        if (paymentId != null) {
          await Future.delayed(const Duration(seconds: 3));
          await _checkPaymentStatus(paymentId);
        }
      } else if (status == 'rejected') {
        debugPrint('Pagamento rejeitado');
        setState(() {
          _cardSuccess = null;
          _cardError = _friendlyMpRejection(statusDetail);
        });
      } else {
        setState(() {
          _cardSuccess = null;
          _cardError =
              'Não foi possível concluir o pagamento. Tente novamente.';
        });
      }
    } else {
      final errorData = jsonDecode(response.body);
      String errorMessage = 'Erro ao processar pagamento';

      if (errorData['error'] == 'Erro de BIN do cartão') {
        errorMessage = errorData['message'] ??
            'O tipo de cartão não corresponde ao BIN informado. Verifique os dados do cartão.';
      } else if (errorData['error'] != null) {
        final error = errorData['error'];
        if (error is String) {
          // Tratamento especial para erros conhecidos
          if (error.contains('Parâmetros obrigatórios ausentes')) {
            errorMessage =
                'Dados do cartão incompletos. Verifique se todos os campos estão preenchidos corretamente.';
          } else {
            errorMessage = error;
          }
        } else {
          errorMessage = error.toString();
        }
      } else {
        errorMessage = response.body;
      }

      setState(() {
        _cardError = errorMessage;
      });
    }
  }
}

class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i != 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class _ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 2) {
      text = '${text.substring(0, 2)}/${text.substring(2, text.length)}';
    }
    if (text.length > 5) text = text.substring(0, 5);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
