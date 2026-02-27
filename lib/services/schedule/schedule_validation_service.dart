import '../../utils/validation_utils.dart';

class ScheduleValidationService {
  const ScheduleValidationService._();

  static List<String> getMissingProfileFields(Map<String, dynamic>? userData) {
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
}
