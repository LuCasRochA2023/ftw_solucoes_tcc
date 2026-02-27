import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ftw_solucoes/services/payment/payment_device_session_service.dart';
import 'package:ftw_solucoes/services/payment/payment_payload_builder.dart';
import 'package:ftw_solucoes/services/payment/payment_user_service.dart';
import 'package:ftw_solucoes/utils/backend_url.dart';
import 'package:ftw_solucoes/utils/environment_config.dart';
import 'package:ftw_solucoes/utils/network_feedback.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class PayWithCreditCard extends StatefulWidget {
  const PayWithCreditCard({
    super.key,
    required this.amount,
    required this.serviceTitle,
    required this.serviceDescription,
    required this.carId,
    required this.carModel,
    required this.carPlate,
    required this.appointmentId,
    required this.balanceToUse,
    required this.onPaymentSuccess,
  });

  /// Valor restante a pagar (fora o saldo).
  final double amount;
  final String serviceTitle;
  final String serviceDescription;
  final String carId;
  final String carModel;
  final String carPlate;
  final String appointmentId;

  /// Quanto foi pago com saldo (se houver).
  final double balanceToUse;

  /// Chamado quando o pagamento é aprovado e o agendamento deve ser confirmado.
  final Future<void> Function() onPaymentSuccess;

  @override
  State<PayWithCreditCard> createState() => _PayWithCreditCardState();
}

class _PayWithCreditCardState extends State<PayWithCreditCard> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isProcessing = false;
  String? _cardError;
  String? _cardSuccess;
  String? _userCpf;

  String? _deviceSessionIdMobile;

  static String get _mpPublicKey => EnvironmentConfig.mercadopagoPublicKeyValue;

  @override
  void initState() {
    super.initState();
    unawaited(_ensureDeviceSessionIdMobile());
    unawaited(_loadUserCpf());
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  String _onlyDigits(String s) => s.replaceAll(RegExp(r'\D'), '');

  String _maskCard(String? cardNumber) {
    final d = _onlyDigits(cardNumber ?? '');
    if (d.length < 8) return '****';
    return '${d.substring(0, 4)} **** **** ${d.substring(d.length - 4)}';
  }

  String _maskCpf(String? cpf) {
    final d = _onlyDigits(cpf ?? '');
    if (d.length < 11) return '***';
    return '***.***.${d.substring(d.length - 3)}-**';
  }

  String _maskToken(String? token) {
    final t = (token ?? '').trim();
    if (t.isEmpty) return '<empty>';
    if (t.length <= 8) return '***';
    return '${t.substring(0, 4)}***${t.substring(t.length - 4)}';
  }

  List<Map<String, dynamic>> _buildPaymentItems() {
    return PaymentPayloadBuilder.buildPaymentItems(
      serviceTitle: widget.serviceTitle,
      serviceDescription: widget.serviceDescription,
      appointmentId: widget.appointmentId,
      amount: widget.amount,
      balanceToUse: widget.balanceToUse,
    );
  }

  String _buildExternalReference() {
    return PaymentPayloadBuilder.buildExternalReference(widget.appointmentId);
  }

  String? _getDeviceSessionIdWeb() {
    return PaymentDeviceSessionService.getWebDeviceSessionId();
  }

  Future<void> _ensureDeviceSessionIdMobile() async {
    if (_getDeviceSessionIdWeb() != null) return;

    if (_deviceSessionIdMobile != null && _deviceSessionIdMobile!.isNotEmpty) {
      return;
    }

    final mobileId = await PaymentDeviceSessionService
        .getOrCreateMobileDeviceSessionId(mounted: mounted);
    if (!mounted || mobileId == null) return;
    setState(() => _deviceSessionIdMobile = mobileId);
  }

  String? _effectiveDeviceSessionId() {
    return _getDeviceSessionIdWeb() ?? _deviceSessionIdMobile;
  }

  Future<void> _loadUserCpf() async {
    try {
      final cpf = await PaymentUserService.loadCurrentUserCpf();
      if (!mounted) return;
      if (cpf != null && cpf.isNotEmpty) {
        setState(() => _userCpf = cpf);
        _log('CPF carregado do perfil: ${_maskCpf(cpf)}');
      } else {
        setState(() => _userCpf = null);
      }
    } catch (e) {
      _log('Erro ao carregar CPF: $e');
      if (mounted) setState(() => _userCpf = null);
    }
  }

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
    if (digits.length < 13 || digits.length > 19) {
      return 'Número do cartão inválido';
    }
    if (RegExp(r'^(\d)\1+$').hasMatch(digits)) {
      return 'Número do cartão inválido';
    }
    if (!_isValidLuhn(digits)) return 'Número do cartão inválido';
    return null;
  }

  String? _validateExpiry(String? v) {
    final raw = (v ?? '').trim();
    if (raw.isEmpty) return 'Informe a validade (MM/AA)';
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(raw)) {
      return 'Validade inválida (use MM/AA)';
    }
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
      return 'Configuração do Mercado Pago inválida (public key).';
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

  Future<String?> _tokenizeCard({
    required String cardNumber,
    required String expirationMonth,
    required String expirationYear,
    required String cvv,
    required String cardholderName,
    required String cpf,
  }) async {
    if (_mpPublicKey.trim().isEmpty) {
      setState(() => _cardError = 'Configuração do Mercado Pago ausente.');
      return null;
    }

    await _ensureDeviceSessionIdMobile();
    final deviceSessionId = _effectiveDeviceSessionId();

    final cleanCpf = _onlyDigits(cpf);
    final cleanCard = _onlyDigits(cardNumber);
    if (cleanCpf.isEmpty) return null;

    final url = Uri.parse(
      'https://api.mercadopago.com/v1/card_tokens?public_key=$_mpPublicKey',
    );

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

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (deviceSessionId != null) 'x-meli-session-id': deviceSessionId,
    };

    _log(
        'Tokenização: CPF=${_maskCpf(cleanCpf)} cartão=${_maskCard(cleanCard)}');

    final response = await http
        .post(url, headers: headers, body: jsonEncode(requestBody))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final id = (data is Map) ? data['id'] : null;
      final tokenId = id?.toString();
      _log('Token gerado: ${_maskToken(tokenId)}');
      return tokenId;
    }

    Map<String, dynamic>? errorData;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) errorData = decoded;
    } catch (_) {
      errorData = null;
    }
    setState(() {
      _cardError = _friendlyMpTokenizationError(response.statusCode, errorData);
    });
    return null;
  }

  Future<void> _checkPaymentStatus(String paymentId) async {
    try {
      final deviceSessionId = _effectiveDeviceSessionId();
      final response = await http.get(
        Uri.parse('${BackendUrl.baseUrl}/payment-status/$paymentId'),
        headers: {
          'Content-Type': 'application/json',
          if (deviceSessionId != null) 'x-meli-session-id': deviceSessionId,
        },
      );
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final status = (data is Map) ? data['status']?.toString() : null;
      final detail = (data is Map) ? data['status_detail']?.toString() : null;

      if (!mounted) return;
      if (status == 'approved') {
        setState(() {
          _cardError = null;
          _cardSuccess = 'Pagamento realizado com sucesso!';
        });
        await widget.onPaymentSuccess();
      } else if (status == 'in_process') {
        setState(() {
          _cardError =
              'Pagamento ainda em processamento. Aguarde mais um pouco.';
        });
      } else if (status == 'rejected') {
        setState(() {
          _cardSuccess = null;
          _cardError = _friendlyMpRejection(detail);
        });
      }
    } catch (e) {
      _log('Erro ao verificar status do pagamento: $e');
    }
  }

  Future<void> _payWithCard(String cardToken) async {
    await _ensureDeviceSessionIdMobile();
    final deviceSessionId = _effectiveDeviceSessionId();

    final headers = {
      'Content-Type': 'application/json',
      'x-idempotency-key': const Uuid().v4(),
      if (deviceSessionId != null) 'x-meli-session-id': deviceSessionId,
    };

    final cleanCpf = _onlyDigits(_userCpf ?? '');
    if (cleanCpf.length != 11) {
      setState(() =>
          _cardError = 'CPF não encontrado no perfil. Atualize seu perfil.');
      return;
    }

    final cardholderName = _nameController.text.trim();
    if (cardholderName.isEmpty) {
      setState(() => _cardError = 'Nome do titular é obrigatório');
      return;
    }

    final cardNumber = _onlyDigits(_cardNumberController.text);
    if (cardNumber.startsWith('4509') ||
        cardNumber.startsWith('3714') ||
        cardNumber.startsWith('4000')) {
      setState(
          () => _cardError = 'Cartão de teste detectado. Use um cartão real.');
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
      'items': items,
      'additional_info': {'items': items},
      if (notificationUrl.isNotEmpty) 'notificationUrl': notificationUrl,
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

    final response = await http
        .post(
          Uri.parse('${BackendUrl.baseUrl}/create-payment'),
          headers: headers,
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final status = (data is Map) ? data['status']?.toString() : null;
      final statusDetail =
          (data is Map) ? data['status_detail']?.toString() : null;
      final paymentId = (data is Map) ? data['id']?.toString() : null;

      if (!mounted) return;
      if (status == 'approved') {
        setState(() {
          _cardError = null;
          _cardSuccess = 'Pagamento realizado com sucesso!';
        });
        await widget.onPaymentSuccess();
      } else if (status == 'in_process') {
        setState(() {
          _cardSuccess = null;
          _cardError = 'Pagamento em processamento. Aguarde a confirmação.';
        });
        if (paymentId != null && paymentId.isNotEmpty) {
          await Future.delayed(const Duration(seconds: 3));
          await _checkPaymentStatus(paymentId);
        }
      } else if (status == 'rejected') {
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
      return;
    }

    String errorMessage = 'Erro ao processar pagamento';
    try {
      final errorData = jsonDecode(response.body);
      if (errorData is Map && errorData['message'] != null) {
        errorMessage = errorData['message'].toString();
      } else if (errorData is Map && errorData['error'] != null) {
        errorMessage = errorData['error'].toString();
      }
    } catch (_) {
      errorMessage = 'Erro ao processar pagamento';
    }
    setState(() => _cardError = errorMessage);
  }

  Future<void> _onPayPressed() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    if (_userCpf == null || _userCpf!.trim().isEmpty) {
      await _loadUserCpf();
    }
    if (_userCpf == null || _userCpf!.trim().isEmpty) {
      setState(() =>
          _cardError = 'CPF não encontrado no perfil. Atualize seu perfil.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _cardError = null;
      _cardSuccess = null;
    });

    try {
      final exp = _expiryController.text.split('/');
      if (exp.length != 2) {
        setState(() => _cardError = 'Validade inválida');
        return;
      }
      final month = exp[0].trim();
      final year = exp[1].trim();
      if (int.tryParse(month) == null || int.tryParse(year) == null) {
        setState(() => _cardError = 'Formato de data inválido');
        return;
      }

      final cardToken = await _tokenizeCard(
        cardNumber: _cardNumberController.text,
        expirationMonth: month,
        expirationYear: year,
        cvv: _cvvController.text,
        cardholderName: _nameController.text,
        cpf: _userCpf!,
      );

      _log('Token: ${_maskToken(cardToken)}');
      if (cardToken == null || cardToken.trim().isEmpty) return;

      await _payWithCard(cardToken.trim());
    } catch (e) {
      setState(() {
        _cardError = NetworkFeedback.isConnectionError(e)
            ? NetworkFeedback.connectionMessage
            : 'Erro ao processar pagamento.';
      });
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 8),
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
                label: _isProcessing
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
                onPressed: _isProcessing ? null : _onPayPressed,
              ),
            ),
          ],
        ),
      ),
    );
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
