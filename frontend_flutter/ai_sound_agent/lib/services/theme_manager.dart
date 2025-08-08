import 'package:flutter/material.dart';
import '../utils/theme_color_constants.dart';
import '../services/userdata_services.dart';

class ThemeManager extends ChangeNotifier {
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal();

  ThemeColor _currentThemeColor = ThemeColor.defaultColor;
  final Userdata _userData = Userdata();

  ThemeColor get currentThemeColor => _currentThemeColor;

  Future<void> loadTheme() async {
    try {
      await _userData.loadUserData();
      final colorName = _userData.preferences['color'] ?? 'defaultColor';
      _currentThemeColor = ThemeColor.values.firstWhere(
        (color) => color.name == colorName,
        orElse: () => ThemeColor.defaultColor,
      );
      notifyListeners();
    } catch (e) {
      print('加载主题失败: $e');
      _currentThemeColor = ThemeColor.defaultColor;
      notifyListeners();
    }
  }

  Future<void> updateTheme(String colorName) async {
    try {
      final newTheme = ThemeColor.values.firstWhere(
        (color) => color.name == colorName,
        orElse: () => ThemeColor.defaultColor,
      );
      
      if (_currentThemeColor != newTheme) {
        _currentThemeColor = newTheme;
        _userData.preferences['color'] = colorName;
        await _userData.saveUserData();
        notifyListeners();
      }
    } catch (e) {
      print('更新主题失败: $e');
    }
  }

  ThemeData get themeData {
    return ThemeData(
      primaryColor: _currentThemeColor.baseColor,
      scaffoldBackgroundColor: _currentThemeColor.lighterColor,
      colorScheme: ColorScheme.light(
        primary: _currentThemeColor.baseColor,
        secondary: _currentThemeColor.darkerColor,
        surface: _currentThemeColor.baseColor,
        onPrimary: _currentThemeColor.lightTextColor,
        onSecondary: _currentThemeColor.lightTextColor,
        onSurface: _currentThemeColor.darkTextColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _currentThemeColor.lighterColor,
        titleTextStyle: TextStyle(
          color: _currentThemeColor.darkTextColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(
          color: _currentThemeColor.darkTextColor,
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: _currentThemeColor.darkTextColor),
        bodyMedium: TextStyle(color: _currentThemeColor.darkTextColor),
        bodySmall: TextStyle(color: _currentThemeColor.darkTextColor),
        titleLarge: TextStyle(color: _currentThemeColor.darkTextColor),
        titleMedium: TextStyle(color: _currentThemeColor.darkTextColor),
        titleSmall: TextStyle(color: _currentThemeColor.darkTextColor),
      ),
      cardTheme: CardThemeData(
        color: _currentThemeColor.lighterColor.withOpacity(0.1),
        elevation: 2,
      ),
    );
  }

  // 获取当前主题的颜色配置
  Color get baseColor => _currentThemeColor.baseColor;
  Color get lighterColor => _currentThemeColor.lighterColor;
  Color get darkerColor => _currentThemeColor.darkerColor;
  Color get lightTextColor => _currentThemeColor.lightTextColor;
  Color get darkTextColor => _currentThemeColor.darkTextColor;
}