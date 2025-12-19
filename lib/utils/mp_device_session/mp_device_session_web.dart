// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js' as js;

String? getMpDeviceSessionIdImpl() {
  final v = js.context['MP_DEVICE_SESSION_ID'];
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return s;
}
