import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._();
  ThemeController._();

  static const _key = 'themeMode'; // 'light' | 'dark' | 'system'
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_key)) {
      case 'light': _mode = ThemeMode.light; break;
      case 'dark':  _mode = ThemeMode.dark;  break;
      default:      _mode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> _persist(ThemeMode m) async {
    final prefs = await SharedPreferences.getInstance();
    final v = m == ThemeMode.light ? 'light' : m == ThemeMode.dark ? 'dark' : 'system';
    await prefs.setString(_key, v);
  }

  Future<void> set(ThemeMode m) async {
    _mode = m;
    notifyListeners();
    await _persist(m);
  }

  Future<void> toggleDark(bool on) => set(on ? ThemeMode.dark : ThemeMode.light);
  Future<void> useSystem() => set(ThemeMode.system);
}
