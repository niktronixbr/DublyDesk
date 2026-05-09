import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const _key = 'theme_mode';
  static final ThemeService instance = ThemeService._internal();

  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  ThemeService._internal() {
    _load();
  }

  /// Mantido por compatibilidade com chamadores antigos — devolve a mesma
  /// instância singleton.
  factory ThemeService() => instance;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == 'light') {
      _mode = ThemeMode.light;
      notifyListeners();
    }
  }

  Future<void> toggle() async {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _mode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }
}
