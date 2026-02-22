import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/network_feedback.dart';
import '../services/connectivity_events.dart';

/// Banner global para indicar ausência de internet.
///
/// - Mostra faixa vermelha fixa embaixo quando offline.
/// - Botão "Tentar novamente" força uma checagem de conectividade.
class OfflineBottomBanner extends StatefulWidget {
  const OfflineBottomBanner({super.key, required this.child});

  final Widget child;

  @override
  State<OfflineBottomBanner> createState() => _OfflineBottomBannerState();
}

class _OfflineBottomBannerState extends State<OfflineBottomBanner>
    with WidgetsBindingObserver {
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _debounce;
  Timer? _monitorTimer;
  bool _pendingCheck = false;

  bool _offline = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkNow();
    _sub = _connectivity.onConnectivityChanged.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), _checkNow);
    });
    _startMonitor();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _stopMonitor();
    _sub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Ao voltar pro app, revalida conectividade.
    if (state == AppLifecycleState.resumed) {
      _startMonitor();
      _checkNow();
      return;
    }

    // Em background, para o monitor para economizar bateria.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopMonitor();
    }
  }

  void _startMonitor() {
    // Monitor leve para detectar "Wi‑Fi conectado sem internet" e mudanças
    // que não disparam onConnectivityChanged.
    _monitorTimer ??= Timer.periodic(const Duration(seconds: 4), (_) {
      _checkNow();
    });
  }

  void _stopMonitor() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  Future<void> _checkNow() async {
    if (!mounted) return;
    if (_checking) {
      _pendingCheck = true;
      return;
    }
    setState(() {
      _checking = true;
    });

    final wasOffline = _offline;
    bool offline = false;
    try {
      final results = await _connectivity.checkConnectivity();
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (!hasNetwork) {
        offline = true;
      } else {
        offline = !(await NetworkFeedback.hasInternet());
      }
    } catch (_) {
      // Se falhar checar, assume offline por segurança.
      offline = true;
    }

    if (!mounted) return;
    setState(() {
      _offline = offline;
      _checking = false;
      if (!offline) {
        // voltando online
      }
    });

    // Ao voltar do offline -> online, dispara evento global de recarregar dados.
    if (wasOffline && !offline) {
      ConnectivityEvents.instance.notifyOnline();
    }

    // Sem polling automático: rechecagens acontecem apenas via:
    // - evento de conectividade
    // - retorno do app (resumed)
    // - botão "Tentar novamente"

    // Se alguma mudança aconteceu enquanto checava, roda mais uma vez.
    if (_pendingCheck) {
      _pendingCheck = false;
      // Evita recursão profunda; agenda na microtask.
      scheduleMicrotask(_checkNow);
    }
  }

  Future<void> _retry() async {
    await _checkNow();
    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            ignoring: !_offline,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              offset: _offline ? Offset.zero : const Offset(0, 1),
              child: SafeArea(
                top: false,
                child: Material(
                  color: Colors.red.shade700,
                  elevation: 12,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sem internet',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                NetworkFeedback.connectionMessage,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: _checking ? null : _retry,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          child: _checking
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Tentar novamente',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

