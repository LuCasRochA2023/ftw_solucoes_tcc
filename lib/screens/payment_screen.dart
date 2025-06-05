import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class PaymentScreen extends StatefulWidget {
  final List<Map<String, dynamic>> appointments;

  const PaymentScreen({
    super.key,
    required this.appointments,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  String _selectedPaymentMethod = 'credit_card';
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _cvvController = TextEditingController();
  final _cardHolderController = TextEditingController();

  static const String _accessToken =
      'TEST-3f79a14c-1b97-430c-8769-6b2bb1f3af55';
  static const String _publicKey =
      'TEST-665148440829077-030720-d493956b8822d1910fd1d8e22d605cdb-165782867';

  static const Map<String, String> _accountInfo = {
    'name': 'FTW Soluções Automotivas LTDA',
    'cnpj': '12.345.678/0001-90',
    'bank': 'Banco FTW',
    'agency': '0001',
    'account': '12345-6',
    'pix_key': 'ftw@exemplo.com.br',
  };

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    _cardHolderController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (_selectedPaymentMethod == 'credit_card' &&
        !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final total = widget.appointments.length * 100.0;
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      if (_selectedPaymentMethod == 'credit_card') {
        await _processCreditCardPayment(total, user);
      } else {
        await _processPixPayment(total, user);
      }

      for (var appointment in widget.appointments) {
        await FirebaseFirestore.instance
            .collection('appointments')
            .add(appointment);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pagamento realizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao processar pagamento: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<String> _createCardToken() async {
    final url = Uri.parse('https://api.mercadopago.com/v1/card_tokens');

    final cardNumber = _cardNumberController.text.replaceAll(' ', '');
    final expiryParts = _expiryDateController.text.split('/');
    final expiryMonth = expiryParts[0];
    final expiryYear = '20${expiryParts[1]}';

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'card_number': cardNumber,
        'expiration_month': int.parse(expiryMonth),
        'expiration_year': int.parse(expiryYear),
        'security_code': _cvvController.text,
        'cardholder': {'name': _cardHolderController.text}
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Erro ao gerar token do cartão');
    }

    final responseData = json.decode(response.body);
    return responseData['id'];
  }

  Future<void> _processCreditCardPayment(double total, User user) async {
    try {
      final cardToken = await _createCardToken();

      final url = Uri.parse('https://api.mercadopago.com/v1/payments');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'transaction_amount': total,
          'token': cardToken,
          'description': 'Serviços Automotivos FTW',
          'installments': 1,
          'payment_method_id': 'visa',
          'payer': {
            'email': user.email,
            'identification': {
              'type': 'CPF',
              'number': '12345678909' // Você deve coletar o CPF do usuário
            }
          }
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Erro ao processar pagamento');
      }

      final responseData = json.decode(response.body);
      if (responseData['status'] != 'approved') {
        throw Exception('Pagamento não aprovado: ${responseData['status']}');
      }
    } catch (e) {
      throw Exception('Erro no processamento do cartão: $e');
    }
  }

  Future<void> _processPixPayment(double total, User user) async {
    try {
      final url = Uri.parse('https://api.mercadopago.com/v1/payments');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'transaction_amount': total,
          'payment_method_id': 'pix',
          'payer': {
            'email': user.email,
            'first_name': user.displayName?.split(' ').first ?? 'Cliente',
            'last_name': user.displayName?.split(' ').last ?? 'FTW',
            'identification': {'type': 'CPF', 'number': '12345678909'}
          },
          'description': 'Serviços Automotivos FTW'
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Erro ao gerar PIX');
      }

      final responseData = json.decode(response.body);
      final qrCode =
          responseData['point_of_interaction']['transaction_data']['qr_code'];
      final qrCodeBase64 = responseData['point_of_interaction']
          ['transaction_data']['qr_code_base64'];

      setState(() {
        _pixQrCode = qrCode;
        _pixQrCodeImage = qrCodeBase64;
      });
    } catch (e) {
      throw Exception('Erro ao gerar PIX: $e');
    }
  }

  String? _pixQrCode;
  String? _pixQrCodeImage;

  Widget _buildPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Forma de Pagamento',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () =>
                    setState(() => _selectedPaymentMethod = 'credit_card'),
                child: Card(
                  elevation: _selectedPaymentMethod == 'credit_card' ? 4 : 1,
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
                        Text(
                          'Cartão de Crédito',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            color: _selectedPaymentMethod == 'credit_card'
                                ? Colors.blue
                                : Colors.grey,
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
                onTap: () => setState(() => _selectedPaymentMethod = 'pix'),
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
                        Text(
                          'PIX',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            color: _selectedPaymentMethod == 'pix'
                                ? Colors.blue
                                : Colors.grey,
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
      ],
    );
  }

  Widget _buildPixPayment() {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_pixQrCodeImage != null)
                  Image.memory(
                    base64Decode(_pixQrCodeImage!),
                    height: 200,
                    width: 200,
                  )
                else
                  Icon(
                    Icons.qr_code_2,
                    size: 100,
                    color: Colors.blue,
                  ),
                const SizedBox(height: 16),
                Text(
                  'QR Code PIX',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildAccountInfoRow(
                          'Empresa', _accountInfo['name'] ?? ''),
                      const Divider(),
                      _buildAccountInfoRow('CNPJ', _accountInfo['cnpj'] ?? ''),
                      const Divider(),
                      if (_pixQrCode != null)
                        _buildAccountInfoRow('Código PIX', _pixQrCode ?? '')
                      else
                        _buildAccountInfoRow(
                            'Chave PIX', _accountInfo['pix_key'] ?? ''),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Escaneie o código QR com seu aplicativo de pagamento',
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        final textToCopy =
                            _pixQrCode ?? _accountInfo['pix_key'] ?? '';
                        Clipboard.setData(ClipboardData(text: textToCopy));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Código PIX copiado!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: Text(
                        'Copiar Código PIX',
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
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
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  // Função para formatar o número do cartão
  String _formatCardNumber(String text) {
    if (text.isEmpty) return '';
    text = text.replaceAll(RegExp(r'\D'), '');
    final List<String> chunks = [];
    for (int i = 0; i < text.length; i += 4) {
      if (i + 4 < text.length) {
        chunks.add(text.substring(i, i + 4));
      } else {
        chunks.add(text.substring(i));
      }
    }
    return chunks.join(' ');
  }

  // Função para formatar a data de validade
  String _formatExpiryDate(String text) {
    if (text.isEmpty) return '';
    text = text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 2) {
      return '${text.substring(0, 2)}/${text.substring(2)}';
    }
    return text;
  }

  // Função para validar o número do cartão usando o algoritmo de Luhn
  bool _isValidCardNumber(String number) {
    number = number.replaceAll(RegExp(r'\D'), '');
    if (number.length < 13 || number.length > 19) return false;

    int sum = 0;
    bool alternate = false;
    for (int i = number.length - 1; i >= 0; i--) {
      int n = int.parse(number[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) {
          n = (n % 10) + 1;
        }
      }
      sum += n;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  // Função para validar a data de validade
  bool _isValidExpiryDate(String date) {
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(date)) return false;

    final parts = date.split('/');
    final month = int.tryParse(parts[0]);
    final year = int.tryParse(parts[1]);

    if (month == null || year == null) return false;
    if (month < 1 || month > 12) return false;

    // Converter ano de 2 dígitos para 4 dígitos
    final currentYear = DateTime.now().year % 100;
    final fullYear = 2000 + year;
    final currentMonth = DateTime.now().month;

    // Verificar se o cartão não está expirado
    if (year < currentYear || (year == currentYear && month < currentMonth)) {
      return false;
    }

    return true;
  }

  Widget _buildCreditCardForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Informações da conta de destino
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dados do Beneficiário',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildAccountInfoRow(
                          'Empresa', _accountInfo['name'] ?? ''),
                      const Divider(),
                      _buildAccountInfoRow('CNPJ', _accountInfo['cnpj'] ?? ''),
                      const Divider(),
                      _buildAccountInfoRow('Banco', _accountInfo['bank'] ?? ''),
                      const Divider(),
                      _buildAccountInfoRow(
                          'Agência', _accountInfo['agency'] ?? ''),
                      const Divider(),
                      _buildAccountInfoRow(
                          'Conta', _accountInfo['account'] ?? ''),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Dados do Cartão',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cardNumberController,
                decoration: InputDecoration(
                  labelText: 'Número do Cartão',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  hintText: '0000 0000 0000 0000',
                ),
                keyboardType: TextInputType.number,
                maxLength: 19,
                onChanged: (value) {
                  final formatted = _formatCardNumber(value);
                  if (formatted != value) {
                    _cardNumberController.value = TextEditingValue(
                      text: formatted,
                      selection:
                          TextSelection.collapsed(offset: formatted.length),
                    );
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o número do cartão';
                  }
                  if (!_isValidCardNumber(value)) {
                    return 'Número de cartão inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expiryDateController,
                      decoration: InputDecoration(
                        labelText: 'Data de Validade',
                        labelStyle: GoogleFonts.poppins(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: 'MM/AA',
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      onChanged: (value) {
                        final formatted = _formatExpiryDate(value);
                        if (formatted != value) {
                          _expiryDateController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(
                                offset: formatted.length),
                          );
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Insira a validade';
                        }
                        if (!_isValidExpiryDate(value)) {
                          return 'Data inválida';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _cvvController,
                      decoration: InputDecoration(
                        labelText: 'CVV',
                        labelStyle: GoogleFonts.poppins(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: '000',
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Insira o CVV';
                        }
                        if (value.length < 3 || value.length > 4) {
                          return 'CVV inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cardHolderController,
                decoration: InputDecoration(
                  labelText: 'Nome no Cartão',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  hintText: 'Como está escrito no cartão',
                ),
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o nome no cartão';
                  }
                  if (value.length < 3) {
                    return 'Nome muito curto';
                  }
                  if (!RegExp(r'^[A-Za-zÀ-ÿ\s]+$').hasMatch(value)) {
                    return 'Nome contém caracteres inválidos';
                  }
                  return null;
                },
                onChanged: (value) {
                  _cardHolderController.value = TextEditingValue(
                    text: value.toUpperCase(),
                    selection: _cardHolderController.selection,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.appointments.length * 100.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pagamento',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Resumo dos Serviços',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.appointments.length,
              itemBuilder: (context, index) {
                final appointment = widget.appointments[index];
                final dateTime = appointment['dateTime'] as DateTime;
                return Card(
                  child: ListTile(
                    title: Text(
                      appointment['service'] as String,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    subtitle: Text(
                      'Data: ${dateTime.day}/${dateTime.month}/${dateTime.year} às ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}',
                      style: GoogleFonts.poppins(),
                      textAlign: TextAlign.center,
                    ),
                    trailing: Text(
                      'R\$ 100,00',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Total:',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'R\$ ${total.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildPaymentMethodSelector(),
            const SizedBox(height: 24),
            if (_selectedPaymentMethod == 'credit_card')
              _buildCreditCardForm()
            else if (_selectedPaymentMethod == 'pix')
              _buildPixPayment(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isProcessing ? null : _processPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isProcessing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  _selectedPaymentMethod == 'credit_card'
                      ? 'Pagar com Cartão'
                      : 'Gerar QR Code PIX',
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
