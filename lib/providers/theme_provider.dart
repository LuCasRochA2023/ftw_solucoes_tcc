import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider() {
    _loadThemeMode();
  }

  ThemeMode get themeMode => _themeMode;

  ThemeData get lightTheme => ThemeData.light(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black87),
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        colorScheme: ColorScheme.light(
          primary: Colors.blue[700]!,
          secondary: Colors.blue[400]!,
          surface: Colors.white,
          error: Colors.red[700]!,
        ),
      );

  ThemeData get darkTheme => ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.grey[900],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[850],
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.grey[850],
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        colorScheme: ColorScheme.dark(
          primary: Colors.blue[400]!,
          secondary: Colors.blue[200]!,
          surface: Colors.grey[850]!,
          error: Colors.red[400]!,
        ),
      );

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_themeKey) ?? 0;
      _themeMode = ThemeMode.values[themeIndex];
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao carregar tema: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, mode.index);
    } catch (e) {
      debugPrint('Erro ao salvar tema: $e');
    }
  }
}
