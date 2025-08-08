import 'package:flutter/material.dart';
import 'package:ai_sound_agent/app/pages/home_page.dart';
import 'package:ai_sound_agent/app/pages/settings_page.dart';

// 定义路由名称常量
class Routes {
  static const String home = '/';
  static const String settings = '/settings';
}

// 路由生成器
Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case Routes.home:
      return MaterialPageRoute(builder: (_) => const HomePage());
    case Routes.settings:
      return MaterialPageRoute(builder: (_) => const SettingsPage());
    default:
      return MaterialPageRoute(
        builder: (_) => Scaffold(
          body: Center(
            child: Text('未找到对应的路由: ${settings.name}'),
          ),
        ),
      );
  }
}
