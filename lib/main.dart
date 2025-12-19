import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'dart:io' show Platform;
import 'package:flutter_localizations/flutter_localizations.dart';
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

    if (Platform.isAndroid) {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
      );
    } else if (Platform.isIOS) {
      await FirebaseAppCheck.instance.activate(
        appleProvider: AppleProvider.debug,
      );
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
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase inicializado com sucesso');
  } catch (e) {
    debugPrint('Erro ao inicializar Firebase: $e');
    await Firebase.initializeApp();
    debugPrint('Firebase inicializado com configurações padrão');
  }

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
      home: StreamBuilder<User?>(
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
