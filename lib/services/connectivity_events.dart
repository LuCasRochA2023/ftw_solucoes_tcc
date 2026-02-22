import 'dart:async';

/// Evento global simples para notificar quando a internet voltou.
///
/// Usado para que telas que dependem de rede possam recarregar seus dados.
class ConnectivityEvents {
  ConnectivityEvents._();

  static final ConnectivityEvents instance = ConnectivityEvents._();

  final StreamController<void> _onlineController =
      StreamController<void>.broadcast();

  Stream<void> get onOnline => _onlineController.stream;

  void notifyOnline() {
    if (_onlineController.isClosed) return;
    _onlineController.add(null);
  }
}

