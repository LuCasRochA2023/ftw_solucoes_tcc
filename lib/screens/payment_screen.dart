import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
// Remover import e uso de MercadoPagoSecureFieldsPage e widgets Bricks
// Deixe apenas a lógica de exibir QR Code Pix e consultar status via backend
import 'package:ftw_solucoes/screens/success_screen.dart';
import 'package:ftw_solucoes/screens/profile_screen.dart';
import '../services/auth_service.dart';
import '../services/payment_service.dart';
import 'package:flutter/services.dart';
import 'package:ftw_solucoes/screens/home_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PaymentScreen extends StatefulWidget {
  final double amount;
  final String serviceTitle;
  final String serviceDescription;
  final String carId;
  final String carModel;
  final String carPlate;
  final String appointmentId;

  const PaymentScreen({
    Key? key,
    required this.amount,
    required this.serviceTitle,
    required this.serviceDescription,
    required this.carId,
    required this.carModel,
    required this.carPlate,
    required this.appointmentId,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  String? _errorMessage;
  String? _pixQrCode;
  String? _pixQrCodeImage;
  String? _paymentId;
  Timer? _statusTimer;
  int _selectedTab = 0; // 0 = Pix, 1 = Cartão

  // Campos do formulário de cartão
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isCardProcessing = false;
  String? _cardError;
  String? _cardSuccess;
  final _cpfController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _criarPagamentoPix();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    _cpfController.dispose();
    super.dispose();
  }

  Future<void> _criarPagamentoPix() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
    try {
      print('=== DEBUG: Iniciando requisição para criar pagamento PIX ===');
      print('URL: http://10.0.2.2:3001/create-payment');

      final headers = {
        'Content-Type': 'application/json',
        'x-idempotency-key': const Uuid().v4(),
      };
      print('Headers: ${jsonEncode(headers)}');

      final requestBody = {
        'amount': widget.amount,
        'description': widget.serviceDescription,
        'payer': {
          'email': 'usuario@email.com',
          'firstName': 'Nome',
          'lastName': 'Sobrenome',
          'cpf': '12345678900',
        }
      };
      print('Body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse('http://10.0.2.2:3001/create-payment'),
        headers: headers,
        body: jsonEncode(requestBody),
      );

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
        setState(() {
          _pixQrCode = qr;
          _paymentId = data['id'].toString();
        });
        _startStatusPolling();
      } else {
        setState(() {
          _errorMessage = 'Erro ao criar pagamento: ${response.body}';
        });
      }
    } catch (e) {
      print('=== DEBUG: Erro na requisição ===');
      print('Erro: $e');
      setState(() {
        _errorMessage = 'Erro ao criar pagamento: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();
    if (_paymentId == null) return;
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final status = await _consultarStatusPagamento();
      if (status == 'approved') {
        _statusTimer?.cancel();
        if (mounted) {
          await _onPaymentSuccess();
        }
      }
    });
  }

  Future<String?> _consultarStatusPagamento() async {
    if (_paymentId == null) return null;
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:3001/payment-status/$_paymentId'),
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

  Future<void> _processPixPayment() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('Dados do usuário não encontrados');
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final cpf = userData['cpf'] as String?;
      final phone = userData['phone'] as String?;
      final address = userData['address'] as Map<String, dynamic>?;

      if (cpf == null || phone == null || address == null) {
        throw Exception(
          'Por favor, complete seu cadastro no perfil antes de fazer o pagamento',
        );
      }

      final paymentData = {
        'transaction_amount': widget.amount,
        'payment_method_id': 'pix',
        'description': 'Pagamento FTW Soluções',
        'payer': {
          'email': user.email,
          'first_name': user.displayName?.split(' ').first ?? '',
          'last_name': user.displayName?.split(' ').skip(1).join(' ') ?? '',
          'identification': {
            'type': 'CPF',
            'number': cpf.replaceAll(RegExp(r'[^\d]'), ''),
          },
        },
        'metadata': {'user_id': user.uid, 'order_id': const Uuid().v4()},
      };

      final response = await http.post(
        Uri.parse('https://ftw-back-end-5.onrender.com/payment/v2'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(paymentData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        setState(() {
          _pixQrCode = responseData['point_of_interaction']['transaction_data']
              ['qr_code'];
          _pixQrCodeImage = responseData['point_of_interaction']
              ['transaction_data']['qr_code_base64'];
        });
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erro ao gerar PIX');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _onPaymentSuccess() async {
    // Atualizar status do agendamento para 'confirmed'
    if (widget.appointmentId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .update({'status': 'confirmed'});
    }
    // Navegar para tela Home
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(authService: AuthService()),
          settings: const RouteSettings(arguments: 'pagamento_sucesso'),
        ),
        (route) => false,
      );
    }
  }

  void _navigateToProfile() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(authService: AuthService()),
      ),
    );
  }

  static const String mpPublicKey =
      'APP_USR-fa719c8f-9ea0-488c-bdd7-a408c5477d3b'; // Troque pela sua public_key

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
        'https://api.mercadopago.com/v1/card_tokens?public_key=$mpPublicKey');
    print('URL: $url');
    print('Headers: {"Content-Type": "application/json"}');

    // Limpar o CPF para garantir consistência
    final cleanCpf = cpf.replaceAll(RegExp(r'[^\d]'), '');
    print('CPF original: $cpf');
    print('CPF limpo: $cleanCpf');

    final requestBody = {
      'card_number': cardNumber.replaceAll(' ', ''),
      'expiration_month': int.parse(expirationMonth),
      'expiration_year': int.parse('20$expirationYear'),
      'security_code': cvv,
      'cardholder': {
        'name': cardholderName,
        'identification': {
          'type': 'CPF',
          'number': cleanCpf,
        }
      }
    };
    print('Body: ${jsonEncode(requestBody)}');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    print('=== DEBUG: Resposta da geração de token ===');
    print('Status Code: ${response.statusCode}');
    print('Response Headers: ${response.headers}');
    print('Response Body: ${response.body}');
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['id']; // Este é o cardToken
    } else {
      print('Erro ao gerar token: ${response.body}');
      setState(() {
        _cardError = 'Erro ao gerar token do cartão: ${response.body}';
      });
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pagamento')),
      body: Column(
        children: [
          const SizedBox(height: 24),
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
                    color: color.withOpacity(0.3),
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
    return Center(
      child: Padding(
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
            const Text('Escaneie o QR Code Pix para pagar:',
                style: TextStyle(fontSize: 18)),
            const SizedBox(height: 24),
            if (_pixQrCode != null && _pixQrCode!.isNotEmpty)
              Center(
                child: QrImageView(
                  data: _pixQrCode!,
                  size: 200.0,
                ),
              ),
            if (_pixQrCode == null || _pixQrCode!.isEmpty)
              const Text(
                  'QR Code não recebido. Verifique o backend e os prints.'),
            const SizedBox(height: 24),
            if (_pixQrCode != null)
              Center(
                child: SelectableText(_pixQrCode!,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center),
              ),
            const SizedBox(height: 16),
            const Text('Após o pagamento, a confirmação é automática.',
                style: TextStyle(color: Colors.green)),
          ],
        ),
      ),
    );
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
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
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
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
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
                    TextFormField(
                      controller: _cpfController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(14),
                        _CpfInputFormatter(),
                      ],
                      decoration: InputDecoration(
                        labelText: 'CPF do Titular',
                        prefixIcon: const Icon(Icons.badge),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 18, horizontal: 16),
                        hintText: '123.456.789-00',
                      ),
                      validator: (v) =>
                          v == null || v.length < 14 ? 'CPF inválido' : null,
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
                          if (_formKey.currentState?.validate() ?? false) {
                            setState(() {
                              _isCardProcessing = true;
                              _cardError = null;
                              _cardSuccess = null;
                            });
                            final exp = _expiryController.text.split('/');
                            if (exp.length != 2) {
                              setState(() {
                                _cardError = 'Validade inválida';
                                _isCardProcessing = false;
                              });
                              return;
                            }
                            final cardToken = await gerarTokenCartao(
                              cardNumber: _cardNumberController.text,
                              expirationMonth: exp[0],
                              expirationYear: exp[1],
                              cvv: _cvvController.text,
                              cardholderName: _nameController.text,
                              cpf: _cpfController.text,
                            );
                            if (cardToken != null) {
                              try {
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
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
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
  //   //       'Authorization': 'Bearer YOUR_ACCESS_TOKEN', // Substitua pelo seu token
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
    print('URL: http://10.0.2.2:3001/create-creditcard-payment');

    final headers = {
      'Content-Type': 'application/json',
      'x-idempotency-key': const Uuid().v4(),
    };
    print('Headers: ${jsonEncode(headers)}');

    // Limpar o CPF para garantir consistência
    final cleanCpf = _cpfController.text.replaceAll(RegExp(r'[^\d]'), '');
    print('CPF para pagamento: $cleanCpf');

    final requestBody = {
      'amount': widget.amount,
      'description': widget.serviceDescription,
      'payer': {
        'email': 'usuario@email.com',
        'cpf': cleanCpf,
      },
      'cardToken': cardToken,
    };
    print('Body: ${jsonEncode(requestBody)}');

    final response = await http.post(
      Uri.parse('http://10.0.2.2:3001/create-creditcard-payment'),
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
      if (status == 'approved') {
        await _onPaymentSuccess();
      } else {
        setState(() {
          _cardError = 'Pagamento não aprovado. Status: $status';
        });
      }
    } else {
      setState(() {
        _cardError = 'Erro ao processar pagamento: ${response.body}';
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
      text = text.substring(0, 2) + '/' + text.substring(2, text.length);
    }
    if (text.length > 5) text = text.substring(0, 5);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 3) text = text.substring(0, 3) + '.' + text.substring(3);
    if (text.length > 7) text = text.substring(0, 7) + '.' + text.substring(7);
    if (text.length > 11)
      text = text.substring(0, 11) + '-' + text.substring(11);
    if (text.length > 14) text = text.substring(0, 14);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
