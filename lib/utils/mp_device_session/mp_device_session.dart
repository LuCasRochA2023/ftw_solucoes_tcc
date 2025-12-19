import 'mp_device_session_stub.dart'
    if (dart.library.js) 'mp_device_session_web.dart';

/// Retorna o `MP_DEVICE_SESSION_ID` (Mercado Pago) quando rodando no Web.
/// Em Android/iOS/Desktop retorna `null`.
String? getMpDeviceSessionId() => getMpDeviceSessionIdImpl();
