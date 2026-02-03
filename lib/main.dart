import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/auth_service.dart';

Future<void> initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // App Check: como você não quer registrar este app no Firebase App Check agora,
    // deixamos App Check ativo somente em debug (provider debug).
    // Em release, não ativamos App Check para não quebrar chamadas por falta de configuração.
    if (!kReleaseMode) {
      if (Platform.isAndroid) {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.debug,
        );
      } else if (Platform.isIOS) {
        await FirebaseAppCheck.instance.activate(
          appleProvider: AppleProvider.debug,
        );
      }
    }

    debugPrint('Firebase inicializado com sucesso');
  } catch (e) {
    debugPrint('Erro ao inicializar Firebase: $e');

    try {
      await Firebase.initializeApp();
      debugPrint('Firebase inicializado com configurações padrão');
    } catch (e) {
      debugPrint('Erro ao inicializar Firebase com configurações padrão: $e');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // Se falhar carregar o .env, o app ainda pode subir (mas vai cair em fallback).
    debugPrint('Erro ao carregar .env: $e');
  }
  await initializeFirebase();

  FirebaseAuth.instance.authStateChanges().listen(
    (User? user) {
      debugPrint(
          'Estado de autenticação alterado: ${user?.uid ?? 'Sem usuário'}');
    },
    onError: (error) {
      debugPrint('Erro no listener de autenticação: $error');
    },
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return MaterialApp(
      title: 'FTW Soluções',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      locale: const Locale('pt', 'BR'),
      home: UpdateGate(
        child: StreamBuilder<User?>(
          stream: authService.authStateChanges,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SplashScreen(nextScreen: null);
            }

            return SplashScreen(
                nextScreen: snapshot.hasData
                    ? HomeScreen(authService: authService)
                    : LoginScreen(authService: authService));
          },
        ),
      ),
    );
  }
}

class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  bool _ready = false;
  bool _mustUpdate = false;
  Object? _lastError;
  InstallStatus? _installStatus;
  StreamSubscription<InstallStatus>? _installSub;
  int? _currentBuild;
  int? _minRequiredBuild;
  String? _forceUpdateMessage;

  @override
  void initState() {
    super.initState();
    // Aguarda o app subir (Activity pronta) antes de chamar o Play Core.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _installSub ??= InAppUpdate.installUpdateListener.listen((status) async {
        if (!mounted) return;
        setState(() => _installStatus = status);

        // Quando o download do update (flexible) terminar, instalamos imediatamente.
        if (status == InstallStatus.downloaded) {
          try {
            await InAppUpdate.completeFlexibleUpdate();
            if (!mounted) return;
            setState(() {
              _ready = true;
              _mustUpdate = false;
              _lastError = null;
            });
          } catch (e) {
            if (!mounted) return;
            setState(() {
              _ready = !kReleaseMode;
              _mustUpdate = kReleaseMode;
              _lastError = e;
            });
          }
        }
      });
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _installSub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // Em iOS também queremos bloquear por versão mínima (Remote Config).
    if (!Platform.isAndroid && !Platform.isIOS) {
      setState(() => _ready = true);
      return;
    }

    await _checkMinimumRequiredVersion();

    // Se for versão antiga e estamos em release, mantém bloqueado.
    if (_mustUpdate) {
      // Android: ainda tenta disparar update via Play Core se disponível.
      if (Platform.isAndroid) {
        unawaited(_tryStartInAppUpdateIfAvailable());
      }
      return;
    }

    // Se não precisa bloquear, ainda pode atualizar via Play Core (Android).
    if (Platform.isAndroid) {
      await _tryStartInAppUpdateIfAvailable(allowUnlockWhenNoUpdate: true);
    } else {
      setState(() => _ready = true);
    }
  }

  Future<void> _checkMinimumRequiredVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;

      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 5),
          minimumFetchInterval:
              kReleaseMode ? const Duration(hours: 1) : Duration.zero,
        ),
      );
      await rc.setDefaults(<String, dynamic>{
        'min_android_build': 0,
        'min_ios_build': 0,
        'force_update_message':
            'Atualização obrigatória. Atualize para continuar.',
      });
      await rc.fetchAndActivate();

      final minRequired = Platform.isAndroid
          ? rc.getInt('min_android_build')
          : rc.getInt('min_ios_build');

      final msg = rc.getString('force_update_message');

      final mustBlock = kReleaseMode && currentBuild < minRequired;

      setState(() {
        _currentBuild = currentBuild;
        _minRequiredBuild = minRequired;
        _forceUpdateMessage = msg.isEmpty
            ? 'Atualização obrigatória. Atualize para continuar.'
            : msg;
        _mustUpdate = mustBlock;
        _ready = !mustBlock;
        _lastError = null;
      });
    } catch (e) {
      // Se o RC falhar, não travamos o app à força (evita lockout).
      // O bloqueio ainda pode acontecer via Play Core quando o update estiver disponível.
      setState(() {
        _mustUpdate = false;
        _ready = false; // ainda vamos tentar Play Core no fluxo normal
        _lastError = e;
      });
    }
  }

  Future<void> _tryStartInAppUpdateIfAvailable({
    bool allowUnlockWhenNoUpdate = false,
  }) async {
    try {
      final info = await InAppUpdate.checkForUpdate();

      final hasUpdate =
          info.updateAvailability == UpdateAvailability.updateAvailable ||
              info.updateAvailability ==
                  UpdateAvailability.developerTriggeredUpdateInProgress;

      if (!hasUpdate) {
        if (allowUnlockWhenNoUpdate) {
          setState(() {
            _ready = true;
            _lastError = null;
          });
        }
        return;
      }

      AppUpdateResult result;
      if (info.immediateUpdateAllowed) {
        if (kReleaseMode) {
          setState(() {
            _ready = false;
            _mustUpdate = true;
            _lastError = null;
          });
        }
        result = await InAppUpdate.performImmediateUpdate();
      } else if (info.flexibleUpdateAllowed) {
        if (kReleaseMode) {
          setState(() {
            _ready = false;
            _mustUpdate = true;
            _lastError = null;
          });
        }
        result = await InAppUpdate.startFlexibleUpdate();
        // A instalação do flexible é disparada pelo listener quando ficar "downloaded".
      } else {
        result = AppUpdateResult.inAppUpdateFailed;
      }

      if (result == AppUpdateResult.success) {
        setState(() {
          _ready = true;
          _mustUpdate = false;
          _lastError = null;
        });
      } else {
        setState(() {
          _ready = !kReleaseMode;
          _mustUpdate = kReleaseMode;
          _lastError = 'AppUpdateResult: $result';
        });
      }
    } catch (e) {
      setState(() {
        _ready = !kReleaseMode;
        _mustUpdate = kReleaseMode;
        _lastError = e;
      });
    }
  }

  Future<void> _openStore() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (Platform.isAndroid) {
        final packageName = info.packageName;
        final market = Uri.parse('market://details?id=$packageName');
        final web = Uri.parse(
            'https://play.google.com/store/apps/details?id=$packageName');
        if (await canLaunchUrl(market)) {
          await launchUrl(market, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(web, mode: LaunchMode.externalApplication);
        }
        return;
      }

      // iOS: precisa do App Store ID (ex: 1234567890). Sem ele, mostramos mensagem.
      // Configure aqui quando tiver:
      const iosAppStoreId = null; // ex: '1234567890'
      if (iosAppStoreId is String && iosAppStoreId.isNotEmpty) {
        final url = Uri.parse('https://apps.apple.com/app/id$iosAppStoreId');
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      setState(() => _lastError = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  _mustUpdate
                      ? (_forceUpdateMessage ??
                          'Atualização obrigatória. Atualize para continuar.')
                      : 'Verificando atualizações...',
                  textAlign: TextAlign.center,
                ),
                if (_mustUpdate &&
                    _currentBuild != null &&
                    _minRequiredBuild != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Versão atual: $_currentBuild • Mínima: $_minRequiredBuild',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (_installStatus != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Status: ${_installStatus!.name}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (_lastError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Detalhes: $_lastError',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (_mustUpdate) ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: Platform.isAndroid ? _bootstrap : _openStore,
                    child: Text(Platform.isAndroid ? 'Atualizar agora' : 'Abrir loja'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('FTW Soluções Automotivas'),
      ),
    );
  }
}
