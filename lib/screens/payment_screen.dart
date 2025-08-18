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
  bool _isProcessing = false;
  String? _errorMessage;
  String? _pixQrCode;
  String? _paymentId;
  Timer? _statusTimer;
  int _selectedTab = 0; // 0 = Pix, 1 = Cartão
  bool _isInitialized = false; // Flag para evitar inicialização duplicada
  bool _isDisposed = false; // Flag para controlar se a tela foi descartada
  bool _isCancelling = false; // Flag para evitar cancelamento múltiplo
  bool _balanceRefunded = false; // Flag para evitar devolução múltipla do saldo

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
    print('=== DEBUG: PaymentScreen initState ===');
    _balanceRefunded =
        false; // Garantir que a flag seja inicializada como false
    // Inicializar imediatamente sem delay
    _initializePayment();
  }

  Future<void> _initializePayment() async {
    if (_isInitialized) {
      print('=== DEBUG: Pagamento já inicializado, pulando... ===');
      return;
    }

    print('=== DEBUG: Inicializando pagamento ===');
    _isInitialized = true;

    // Primeiro carregar o CPF, depois criar o pagamento
    await _loadUserCpf();
    await _criarPagamentoPix();
    print('=== DEBUG: Inicialização concluída ===');
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
    print('=== DEBUG: Carregando CPF do usuário ===');
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('Usuário autenticado: ${user.uid}');

        // Usar timeout mais curto para carregamento mais rápido
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 5));

        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          print('Dados do usuário: $data');
          final cpf = data['cpf'] ?? '';

          if (cpf.isNotEmpty) {
            setState(() {
              _userCpf = cpf;
            });
            print('CPF carregado do perfil: $cpf');
            print('CPF limpo: ${cpf.replaceAll(RegExp(r'[^\d]'), '')}');
            print('CPF armazenado em _userCpf: $_userCpf');
          } else {
            print('CPF não encontrado no perfil do usuário');
            setState(() {
              _userCpf = null;
            });
          }
        } else {
          print('Documento do usuário não encontrado');
          setState(() {
            _userCpf = null;
          });
        }
      } else {
        print('Usuário não autenticado');
        setState(() {
          _userCpf = null;
        });
      }
    } catch (e) {
      print('Erro ao carregar CPF do usuário: $e');
      setState(() {
        _userCpf = null;
      });
    }
  }

  Future<void> _criarPagamentoPix() async {
    if (_isProcessing) {
      print('=== DEBUG: Pagamento PIX já em processamento, pulando... ===');
      return;
    }

    print('=== DEBUG: Definindo _isProcessing como true ===');
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      print('=== DEBUG: Iniciando criação de pagamento PIX ===');
      print('BackendUrl.baseUrl: ${BackendUrl.baseUrl}');
      print(
          'EnvironmentConfig.activeBackendUrl: ${EnvironmentConfig.activeBackendUrl}');
      print('URL completa: ${BackendUrl.baseUrl}/create-payment');
      print('CPF atual: $_userCpf');

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
          print('Usando CPF do perfil: $userCpf');
        } else {
          print('CPF do perfil inválido: $_userCpf (limpo: $cleanCpf)');
          print('Usando CPF de teste: $userCpf');
        }
      } else {
        print('CPF não encontrado no perfil, usando CPF de teste: $userCpf');
        print('Dica: Atualize seu perfil para usar seu CPF real');
      }

      final headers = {
        'Content-Type': 'application/json',
        'x-idempotency-key': const Uuid().v4(),
      };

      final requestBody = {
        'amount': widget.amount,
        'description': widget.serviceDescription,
        'payer': {
          'email': userEmail,
          'firstName': userFirstName,
          'lastName': userLastName,
          'cpf': userCpf,
        }
      };
      print('Body: ${jsonEncode(requestBody)}');

      print('=== DEBUG: Enviando requisição para o backend ===');
      print('URL final: ${BackendUrl.baseUrl}/create-payment');
      print('Headers: $headers');
      print('Body: ${jsonEncode(requestBody)}');

      final response = await http
          .post(
            Uri.parse('${BackendUrl.baseUrl}/create-payment'),
            headers: headers,
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      print('=== DEBUG: Resposta recebida ===');
      print('Status Code: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Resposta do backend:');
        print(data);
        final qr =
            data['point_of_interaction']?['transaction_data']?['qr_code'];
        print('QR recebido: $qr');

        if (qr != null && qr.isNotEmpty) {
          print('=== DEBUG: Definindo _isProcessing como false (sucesso) ===');
          setState(() {
            _pixQrCode = qr;
            _paymentId = data['id'].toString();
            _isProcessing = false;
          });
          _startStatusPolling();
          print('✅ QR Code gerado com sucesso!');
        } else {
          throw Exception('QR Code não foi gerado pelo backend');
        }
      } else {
        final errorData = jsonDecode(response.body);
        String userFriendlyMessage = 'Não foi possível processar o pagamento';

        // Tratamento específico de erros com mensagens amigáveis
        if (errorData['message'] != null) {
          userFriendlyMessage = errorData['message'];
        } else if (errorData['error'] != null) {
          if (errorData['error']['message'] != null) {
            userFriendlyMessage = errorData['error']['message'];
          } else if (errorData['error']['error'] != null) {
            userFriendlyMessage = 'Erro: ${errorData['error']['error']}';
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

        print('=== DEBUG: Definindo _isProcessing como false (erro) ===');
        setState(() {
          _errorMessage = userFriendlyMessage;
          _isProcessing = false;
        });

        _showRetryButton();
      }
    } catch (e) {
      print('=== DEBUG: Erro na requisição ===');
      print('Erro: $e');
      print('=== DEBUG: Definindo _isProcessing como false (exceção) ===');

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
      final response = await http.get(
        Uri.parse('${BackendUrl.baseUrl}/payment-status/$_paymentId'),
        headers: {
          'x-idempotency-key': const Uuid().v4(),
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
    print('=== DEBUG: _onPaymentSuccess chamada ===');
    print('balanceToUse: ${widget.balanceToUse}');
    print('appointmentId: ${widget.appointmentId}');
    print('isDisposed: $_isDisposed');

    // Verificar se a tela foi descartada antes de processar
    if (_isDisposed) {
      print('=== DEBUG: Tela descartada, cancelando processamento ===');
      return;
    }

    try {
      // Se há saldo para usar, processar o pagamento com saldo
      if (widget.balanceToUse != null && widget.balanceToUse! > 0) {
        print('=== DEBUG: Processando pagamento com saldo ===');
        await _processBalancePayment();
      }

      if (widget.appointmentId.isNotEmpty) {
        print('=== DEBUG: Atualizando status do agendamento ===');
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(widget.appointmentId)
            .update({'status': 'confirmed'});
      }
      if (mounted && !_isDisposed) {
        print('=== DEBUG: Navegando para HomeScreen ===');
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
      print('Erro ao processar pagamento com saldo: $e');
    }
  }

  Future<void> _processBalancePayment() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      final currentBalance = (await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get())
              .data()?['balance'] ??
          0.0;

      final finalBalance = currentBalance - widget.balanceToUse!;

      // Atualizar saldo do usuário
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'balance': finalBalance});

      // Registrar transação de débito
      await FirebaseFirestore.instance.collection('transactions').add({
        'userId': user.uid,
        'amount': widget.balanceToUse!,
        'type': 'debit',
        'description': 'Pagamento de agendamento - ${widget.serviceTitle}',
        'appointmentId': widget.appointmentId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Erro ao processar pagamento com saldo: $e');
    }
  }

  Future<void> _cancelAppointmentAndRefundBalance() async {
    print('=== DEBUG: _cancelAppointmentAndRefundBalance chamada ===');
    print('=== DEBUG: _isCancelling: $_isCancelling ===');
    print('=== DEBUG: _balanceRefunded: $_balanceRefunded ===');

    // Evitar execução múltipla
    if (_isCancelling) {
      print('=== DEBUG: Cancelamento já em andamento, pulando... ===');
      return;
    }

    _isCancelling = true;
    print('=== DEBUG: Iniciando cancelamento do agendamento ===');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      // Cancelar agendamento
      if (widget.appointmentId.isNotEmpty) {
        print('=== DEBUG: Cancelando agendamento ${widget.appointmentId} ===');

        // Verificar se já foi cancelado
        final appointmentDoc = await FirebaseFirestore.instance
            .collection('appointments')
            .doc(widget.appointmentId)
            .get();

        if (appointmentDoc.exists &&
            appointmentDoc.data()?['status'] != 'cancelled') {
          await FirebaseFirestore.instance
              .collection('appointments')
              .doc(widget.appointmentId)
              .update({'status': 'cancelled'});
          print('=== DEBUG: Agendamento cancelado com sucesso ===');
        } else {
          print('=== DEBUG: Agendamento já estava cancelado ===');
        }
      }

      // Se há saldo que foi usado, devolver (apenas uma vez)
      print('=== DEBUG: Verificando condições para devolução ===');
      print('=== DEBUG: balanceToUse: ${widget.balanceToUse} ===');
      print('=== DEBUG: _balanceRefunded: $_balanceRefunded ===');

      if (widget.balanceToUse != null &&
          widget.balanceToUse! > 0 &&
          !_balanceRefunded) {
        print(
            '=== DEBUG: Processando devolução de saldo R\$ ${widget.balanceToUse!.toStringAsFixed(2)} ===');

        // Verificar se já existe uma transação de devolução para este agendamento
        final existingRefund = await FirebaseFirestore.instance
            .collection('transactions')
            .where('userId', isEqualTo: user.uid)
            .where('appointmentId', isEqualTo: widget.appointmentId)
            .where('type', isEqualTo: 'credit')
            .get();

        if (existingRefund.docs.isNotEmpty) {
          print('=== DEBUG: Devolução já foi processada anteriormente ===');
          _balanceRefunded = true;
        } else {
          // Usar transação do Firestore para garantir atomicidade
          await FirebaseFirestore.instance.runTransaction((transaction) async {
            // Buscar documento do usuário
            final userDoc = await transaction.get(
                FirebaseFirestore.instance.collection('users').doc(user.uid));

            final currentBalance =
                (userDoc.data()?['balance'] ?? 0.0).toDouble();
            final refundedBalance = currentBalance + widget.balanceToUse!;

            print(
                '=== DEBUG: Saldo atual: R\$ ${currentBalance.toStringAsFixed(2)} ===');
            print(
                '=== DEBUG: Saldo após devolução: R\$ ${refundedBalance.toStringAsFixed(2)} ===');

            // Atualizar saldo do usuário
            transaction.update(
                FirebaseFirestore.instance.collection('users').doc(user.uid),
                {'balance': refundedBalance});

            // Registrar transação de crédito (devolução)
            final transactionRef =
                FirebaseFirestore.instance.collection('transactions').doc();
            transaction.set(transactionRef, {
              'userId': user.uid,
              'amount': widget.balanceToUse!,
              'type': 'credit',
              'description':
                  'Devolução - Cancelamento de agendamento - ${widget.serviceTitle}',
              'appointmentId': widget.appointmentId,
              'createdAt': FieldValue.serverTimestamp(),
            });
          });

          _balanceRefunded = true;
          print('=== DEBUG: Saldo devolvido com sucesso ===');
        }
      } else if (widget.balanceToUse != null &&
          widget.balanceToUse! > 0 &&
          _balanceRefunded) {
        print('=== DEBUG: Saldo já foi devolvido nesta sessão ===');
      }

      print('=== DEBUG: Cancelamento concluído com sucesso ===');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.balanceToUse != null && widget.balanceToUse! > 0
                  ? 'Agendamento cancelado. R\$ ${widget.balanceToUse!.toStringAsFixed(2)} devolvido ao seu saldo.'
                  : 'Agendamento cancelado.',
            ),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('Erro ao cancelar agendamento: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao cancelar agendamento: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isCancelling = false; // Reset flag
    }
  }

  static String get mpPublicKey => EnvironmentConfig.mercadopagoPublicKeyValue;

  Future<String?> gerarTokenCartao({
    required String cardNumber,
    required String expirationMonth,
    required String expirationYear,
    required String cvv,
    required String cardholderName,
    required String cpf,
  }) async {
    print('=== DEBUG: Gerando token do cartão ===');

    final url = Uri.parse(
      'https://api.mercadopago.com/v1/card_tokens?public_key=$mpPublicKey',
    );

    final cleanCpf = cpf.replaceAll(RegExp(r'[^\d]'), '');
    final cleanCard = cardNumber.replaceAll(' ', '');

    if (cleanCpf.isEmpty) {
      print('Erro: CPF não fornecido para tokenização');
      return null;
    }

    print('CPF para tokenização: $cleanCpf');
    print('Nome do titular: $cardholderName');
    print(
        'Número do cartão: ${cleanCard.substring(0, 4)}...${cleanCard.substring(cleanCard.length - 4)}');
    print('Validade: $expirationMonth/$expirationYear');

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

    print('Request Body para tokenização: ${jsonEncode(requestBody)}');

    print('=== DEBUG: Enviando requisição para Mercado Pago (tokenização) ===');
    print('URL: $url');
    print('Headers: ${jsonEncode({'Content-Type': 'application/json'})}');
    print('Body: ${jsonEncode(requestBody)}');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    print('=== DEBUG: Resposta da tokenização ===');
    print('Status Code: ${response.statusCode}');
    print('Response Headers: ${response.headers}');
    print('Response Body: ${response.body}');

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      print('Token gerado com sucesso: ${data['id']}');
      return data['id'];
    } else {
      final errorData = jsonDecode(response.body);
      print('Erro ao gerar token: ${jsonEncode(errorData)}');
      return null;
    }
  }

  Future<void> _checkPaymentStatus(String paymentId) async {
    try {
      print('=== DEBUG: Verificando status do pagamento ===');
      print('Payment ID: $paymentId');

      final response = await http.get(
        Uri.parse('${BackendUrl.baseUrl}/payment-status/$paymentId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['status'] as String?;
        final statusDetail = data['status_detail'] as String?;

        print('Status atualizado: $status - $statusDetail');

        if (status == 'approved') {
          print('Pagamento aprovado!');
          await _onPaymentSuccess();
        } else if (status == 'in_process') {
          print('⏳ Ainda em processamento...');
          setState(() {
            _cardError =
                'Pagamento ainda em processamento. Aguarde mais um pouco.';
          });
        } else if (status == 'rejected') {
          print('Pagamento rejeitado');
          setState(() {
            _cardError = 'Pagamento rejeitado: $statusDetail';
          });
        }
      } else {
        print('Erro ao verificar status: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao verificar status do pagamento: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        print(
                            '=== DEBUG: Botão Voltar ao Início pressionado ===');

                        // Fechar dialog primeiro
                        Navigator.pop(context);
                        print('=== DEBUG: Dialog fechado ===');

                        // Apenas voltar para tela inicial, sem cancelar agendamento
                        print(
                            '=== DEBUG: Voltando para tela inicial sem cancelar ===');

                        // Voltar para tela inicial
                        if (mounted) {
                          print(
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
                          print(
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
                  selected: _selectedTab == 0,
                  icon: Image.asset('assets/images/pix.png',
                      height: 40, width: 40),
                  label: 'Pix',
                  onTap: () => setState(() => _selectedTab = 0),
                  color: Colors.green,
                ),
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
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _selectedTab == 0
                  ? _buildPixWidget()
                  : _buildCreditCardWidget(),
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
    print(
        '=== DEBUG: _buildPixWidget chamado - _isProcessing: $_isProcessing ===');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
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
                        'CPF: ${_userCpf!.replaceAll(RegExp(r'[^\d]'), '').replaceAllMapped(RegExp(r'(\d{3})(\d{3})(\d{3})(\d{2})'), (Match m) => '${m[1]}.${m[2]}.${m[3]}-${m[4]}')}',
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
                                  builder: (context) =>
                                      ProfileScreen(authService: AuthService()),
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
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
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
    );

    ;
  }

  Widget _buildCreditCardWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
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
                      validator: (v) =>
                          v == null || v.replaceAll(' ', '').length < 16
                              ? 'Número inválido'
                              : null,
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
                          validator: (v) =>
                              v == null || v.length < 5 ? 'Inválido' : null,
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
                          validator: (v) =>
                              v == null || v.length < 3 ? 'Inválido' : null,
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
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Obrigatório' : null,
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
                          print(
                              '=== DEBUG: Botão de pagamento pressionado ===');
                          print(
                              'Formulário válido: ${_formKey.currentState?.validate() ?? false}');
                          print('CPF carregado: $_userCpf');
                          print('Nome: ${_nameController.text}');
                          print('Cartão: ${_cardNumberController.text}');
                          print('Validade: ${_expiryController.text}');
                          print('CVV: ${_cvvController.text}');

                          print(
                              '=== DEBUG: Verificando validação do formulário ===');
                          final isValid =
                              _formKey.currentState?.validate() ?? false;
                          print('Formulário válido: $isValid');

                          if (isValid) {
                            // Verificar se o CPF foi carregado
                            print('=== DEBUG: Verificando CPF ===');
                            print('CPF atual: $_userCpf');
                            if (_userCpf == null || _userCpf!.isEmpty) {
                              print(
                                  'CPF não carregado, tentando carregar novamente...');
                              await _loadUserCpf();
                              print('CPF após recarregar: $_userCpf');
                              if (_userCpf == null || _userCpf!.isEmpty) {
                                setState(() {
                                  _cardError =
                                      'CPF não encontrado no perfil. Por favor, atualize seu perfil primeiro.';
                                });
                                return;
                              }
                            }

                            print(
                                '=== DEBUG: Verificando campos do formulário ===');
                            print('Nome: "${_nameController.text}"');
                            print('Cartão: "${_cardNumberController.text}"');
                            print('Validade: "${_expiryController.text}"');
                            print('CVV: "${_cvvController.text}"');

                            setState(() {
                              _isCardProcessing = true;
                              _cardError = null;
                              _cardSuccess = null;
                            });
                            final exp = _expiryController.text.split('/');
                            print('Validade dividida: $exp');
                            if (exp.length != 2) {
                              print('Erro: Validade inválida');
                              setState(() {
                                _cardError = 'Validade inválida';
                                _isCardProcessing = false;
                              });
                              return;
                            }
                            print('CPF antes da tokenização: $_userCpf');
                            print(
                                'CPF está vazio? ${_userCpf == null || _userCpf!.isEmpty}');
                            print(
                                'CPF é o de teste? ${_userCpf == '03557007197'}');
                            print(
                                'CPF limpo: ${_userCpf?.replaceAll(RegExp(r'[^\d]'), '')}');
                            print('=== DEBUG: Antes de gerar token ===');
                            print('CPF para tokenização: $_userCpf');
                            print('Nome do titular: ${_nameController.text}');
                            print(
                                'Número do cartão: ${_cardNumberController.text}');
                            print('Validade: ${_expiryController.text}');

                            final cardToken = await gerarTokenCartao(
                              cardNumber: _cardNumberController.text,
                              expirationMonth: exp[0],
                              expirationYear: exp[1],
                              cvv: _cvvController.text,
                              cardholderName: _nameController.text,
                              cpf: _userCpf!, // Usar CPF do usuário
                            );
                            print('=== DEBUG: Token gerado: $cardToken ===');
                            if (cardToken != null) {
                              try {
                                print('=== DEBUG: Chamando pagarComCartao ===');
                                await pagarComCartao(cardToken);
                                setState(() {
                                  _cardSuccess =
                                      'Pagamento realizado com sucesso!';
                                });
                              } catch (e) {
                                setState(() {
                                  _cardError =
                                      'Erro ao processar pagamento: $e';
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
      ),
    );
  }

  Widget _buildAccountInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Implementar lógica para gerar token do cartão
  // Future<String?> _generateCardToken() async {
  //   // Lógica para gerar token do cartão usando SDK do Mercado Pago
  //   // Exemplo:
  //   // try {
  //   //   final response = await http.post(
  //   //     Uri.parse('https://api.mercadopago.com/v1/card_tokens'),
  //   //     headers: {
  //   //       'Authorization': 'Bearer ${EnvironmentConfig.mercadopagoAccessTokenValue}',
  //   //       'Content-Type': 'application/json',
  //   //     },
  //   //     body: jsonEncode({
  //   //       'card_number': '4532 4567 8901 2345', // Número do cartão
  //   //       'expiration_month': '12', // Mês de validade
  //   //       'expiration_year': '25', // Ano de validade
  //   //       'security_code': '123', // Código CVV
  //   //       'cardholder': {
  //   //         'name': 'Nome do Cartão',
  //   //       },
  //   //     }),
  //   //   );
  //   //   if (response.statusCode == 200) {
  //   //     final data = jsonDecode(response.body);
  //   //     return data['id'];
  //   //   }
  //   // } catch (e) {
  //   //   print('Erro ao gerar token do cartão: $e');
  //   // }
  //   return null;
  // }

  // Implementar lógica para pagar com cartão
  Future<void> pagarComCartao(String cardToken) async {
    print('=== DEBUG: Iniciando pagamento com cartão ===');
    print('URL: ${BackendUrl.baseUrl}/create-creditcard-payment');

    final headers = {
      'Content-Type': 'application/json',
      'x-idempotency-key': const Uuid().v4(),
    };
    print('Headers: ${jsonEncode(headers)}');

    // Usar CPF do usuário carregado do perfil
    final cleanCpf = _userCpf?.replaceAll(RegExp(r'[^\d]'), '') ?? '';
    print('CPF para pagamento: $cleanCpf');
    print('CPF original do perfil: $_userCpf');

    if (cleanCpf.isEmpty) {
      setState(() {
        _cardError =
            'CPF não encontrado no perfil. Por favor, atualize seu perfil.';
        _isCardProcessing = false;
      });
      return;
    }

    if (cleanCpf == '03557007197') {
      setState(() {
        _cardError =
            'CPF de teste detectado. Por favor, use seu CPF real no perfil.';
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

    // Obter userId do Firebase Auth
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'unknown';

    final requestBody = {
      'amount': widget.amount,
      'paymentMethod': 'credit_card',
      'description': widget.serviceDescription,
      'payer': {
        'email': user?.email ?? 'email@gmail.com',
        'cpf': cleanCpf,
        'firstName': cardholderName.split(' ').first,
        'lastName': cardholderName.split(' ').skip(1).join(' ') ?? 'Sobrenome',
        'userId': userId,
      },
      'cardToken': cardToken,
      'cardNumber': cardNumber,
    };
    print('Body: ${jsonEncode(requestBody)}');

    print('=== DEBUG: Enviando requisição para o backend ===');
    print('URL: ${BackendUrl.baseUrl}/create-payment');
    print('Headers: ${jsonEncode(headers)}');
    print('Body: ${jsonEncode(requestBody)}');

    final response = await http.post(
      Uri.parse('${BackendUrl.baseUrl}/create-payment'),
      headers: headers,
      body: jsonEncode(requestBody),
    );

    print('=== DEBUG: Resposta do pagamento com cartão ===');
    print('Status Code: ${response.statusCode}');
    print('Response Headers: ${response.headers}');
    print('Response Body: ${response.body}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final status = data['status'] as String?;
      final statusDetail = data['status_detail'] as String?;

      print('=== DEBUG: Status do pagamento ===');
      print('Status: $status');
      print('Status Detail: $statusDetail');
      print('Payment ID: ${data['id']}');

      if (status == 'approved') {
        print('✅ Pagamento aprovado com sucesso!');
        await _onPaymentSuccess();
      } else if (status == 'in_process') {
        print('⏳ Pagamento em processamento');
        setState(() {
          _cardError =
              'Pagamento em processamento. Aguarde a confirmação. Status: $statusDetail';
        });
        // Aguardar um pouco e verificar novamente
        await Future.delayed(const Duration(seconds: 3));
        await _checkPaymentStatus(data['id'].toString());
      } else if (status == 'rejected') {
        print('❌ Pagamento rejeitado');
        setState(() {
          _cardError =
              'Pagamento rejeitado. Verifique os dados do cartão. Status: $statusDetail';
        });
      } else {
        setState(() {
          _cardError = 'Status inesperado: $status - $statusDetail';
        });
      }
    } else {
      final errorData = jsonDecode(response.body);
      String errorMessage = 'Erro ao processar pagamento';

      if (errorData['error'] == 'Erro de BIN do cartão') {
        errorMessage = errorData['message'] ??
            'O tipo de cartão não corresponde ao BIN informado. Verifique os dados do cartão.';
      } else if (errorData['error'] != null) {
        errorMessage = errorData['error'];
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
