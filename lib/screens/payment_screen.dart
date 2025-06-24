import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:ftw_solucoes/screens/mercado_pago_secure_fields_page.dart';
import 'package:ftw_solucoes/screens/success_screen.dart';
import 'package:ftw_solucoes/screens/profile_screen.dart';
import '../services/auth_service.dart';

class PaymentScreen extends StatefulWidget {
  final double amount;
  final String serviceTitle;
  final String serviceDescription;
  final String carId;
  final String carModel;
  final String carPlate;

  const PaymentScreen({
    Key? key,
    required this.amount,
    required this.serviceTitle,
    required this.serviceDescription,
    required this.carId,
    required this.carModel,
    required this.carPlate,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  String? _errorMessage;
  String _selectedPaymentMethod = 'credit_card';
  String? _pixQrCode;
  String? _pixQrCodeImage;

  Future<void> _processCreditCardPayment() async {
    debugPrint('Iniciando processamento do pagamento...');

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      debugPrint('Obtendo usuário atual...');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      debugPrint('Obtendo dados do usuário do Firestore...');
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

      debugPrint('CPF: $cpf');
      debugPrint('Telefone: $phone');
      debugPrint('Endereço: $address');

      if (cpf == null || phone == null || address == null) {
        throw Exception(
            'Por favor, complete seu cadastro no perfil antes de fazer o pagamento');
      }

      final phoneParts = phone.replaceAll(RegExp(r'[^\d]'), '').split('');
      final areaCode = phoneParts.take(2).join();
      final phoneNumber = phoneParts.skip(2).join();

      debugPrint('DDD: $areaCode, Número: $phoneNumber');

      final idempotencyKey = const Uuid().v4();
      debugPrint('Chave de idempotência gerada: $idempotencyKey');

      final tokenResult = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => MercadoPagoSecureFieldsPage(
            amount: widget.amount,
            userData: {
              'cpf': cpf,
              'phone': phone,
              'address': address,
              'email': user.email,
              'name': user.displayName,
            },
          ),
        ),
      );

      debugPrint('Resultado da tokenização: $tokenResult');

      if (tokenResult == null) {
        throw Exception('Operação cancelada');
      }

      if (tokenResult.containsKey('error')) {
        throw Exception(tokenResult['error']);
      }

      final token = tokenResult['token'];
      debugPrint('Token obtido: $token');

      final paymentData = {
        'transaction_amount': widget.amount,
        'token': token,
        'description': 'Pagamento FTW Soluções',
        'installments': 1,
        'payment_method_id': 'master',
        'payer': {
          'email': user.email,
          'identification': {
            'type': 'CPF',
            'number': cpf.replaceAll(RegExp(r'[^\d]'), ''),
          },
          'first_name': user.displayName?.split(' ').first ?? '',
          'last_name': user.displayName?.split(' ').skip(1).join(' ') ?? '',
          'address': {
            'zip_code':
                address['cep']?.toString().replaceAll(RegExp(r'[^\d]'), '') ??
                    '',
            'street_name': address['street'] ?? '',
            'street_number': address['number']?.toString() ?? '',
            'neighborhood': address['neighborhood'] ?? '',
            'city': address['city'] ?? '',
            'federal_unit': address['state'] ?? '',
          },
          'phone': {
            'area_code': areaCode,
            'number': phoneNumber,
          },
        },
        'metadata': {
          'user_id': user.uid,
          'order_id': idempotencyKey,
        },
      };

      debugPrint('Enviando dados do pagamento para a API...');
      debugPrint('Dados do pagamento: ${jsonEncode(paymentData)}');

      final response = await http.post(
        Uri.parse('https://ftw-back-end-5.onrender.com/payment/v2'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Idempotency-Key': idempotencyKey,
        },
        body: jsonEncode(paymentData),
      );

      debugPrint('Resposta da API: ${response.statusCode}');
      debugPrint('Corpo da resposta: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (!mounted) return;

        debugPrint(
            'Pagamento processado com sucesso. ID: ${responseData['id']}');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SuccessScreen(
              paymentId: responseData['id'].toString(),
            ),
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        debugPrint('Erro na resposta da API: ${errorData['message']}');
        throw Exception(errorData['message'] ?? 'Erro ao processar pagamento');
      }
    } catch (e) {
      debugPrint('Erro ao processar pagamento: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
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
            'Por favor, complete seu cadastro no perfil antes de fazer o pagamento');
      }

      final idempotencyKey = const Uuid().v4();

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
        'metadata': {
          'user_id': user.uid,
          'order_id': idempotencyKey,
        },
      };

      final response = await http.post(
        Uri.parse('https://ftw-back-end-5.onrender.com/payment/v2'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Idempotency-Key': idempotencyKey,
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

  void _navigateToProfile() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          authService: AuthService(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagamento'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade900),
                        textAlign: TextAlign.center,
                      ),
                      if (_errorMessage!.contains('complete seu cadastro'))
                        TextButton(
                          onPressed: _navigateToProfile,
                          child: const Text('Ir para o Perfil'),
                        ),
                    ],
                  ),
                ),
              Text(
                'Valor a pagar: R\$ ${widget.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(
                          () => _selectedPaymentMethod = 'credit_card'),
                      child: Card(
                        elevation:
                            _selectedPaymentMethod == 'credit_card' ? 4 : 1,
                        color: _selectedPaymentMethod == 'credit_card'
                            ? Colors.blue.shade50
                            : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.credit_card,
                                size: 32,
                                color: _selectedPaymentMethod == 'credit_card'
                                    ? Colors.blue
                                    : Colors.grey,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Cartão de Crédito',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () =>
                          setState(() => _selectedPaymentMethod = 'pix'),
                      child: Card(
                        elevation: _selectedPaymentMethod == 'pix' ? 4 : 1,
                        color: _selectedPaymentMethod == 'pix'
                            ? Colors.blue.shade50
                            : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/images/pix.png',
                                height: 32,
                                width: 32,
                                color: _selectedPaymentMethod == 'pix'
                                    ? Colors.blue
                                    : Colors.grey,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'PIX',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              if (_selectedPaymentMethod == 'credit_card')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _processCreditCardPayment,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Pagar com Cartão',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                )
              else if (_selectedPaymentMethod == 'pix')
                Column(
                  children: [
                    if (_pixQrCodeImage != null)
                      Image.memory(
                        base64Decode(_pixQrCodeImage!),
                        height: 200,
                        width: 200,
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _processPixPayment,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: _isProcessing
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Gerar PIX',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    if (_pixQrCode != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _buildAccountInfoRow('Código PIX', _pixQrCode!),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Escaneie o código QR com seu aplicativo de pagamento',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar Código PIX'),
                      ),
                    ],
                  ],
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
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
