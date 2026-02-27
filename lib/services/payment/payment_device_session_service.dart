import '../../utils/mp_device_session/mp_device_session.dart';
import '../../utils/mp_device_session/mp_device_session_mobile.dart';

class PaymentDeviceSessionService {
  const PaymentDeviceSessionService._();

  static String? getWebDeviceSessionId() {
    try {
      return getMpDeviceSessionId();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getOrCreateMobileDeviceSessionId({
    required bool mounted,
  }) async {
    final webId = getWebDeviceSessionId();
    if (webId != null) return null;

    final v = await MpDeviceSessionMobile.instance.getOrCreate();
    if (!mounted) return null;
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }
}
