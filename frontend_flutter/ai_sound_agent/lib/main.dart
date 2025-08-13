import 'package:flutter/material.dart';
import 'package:ai_sound_agent/app/route.dart';
import 'package:ai_sound_agent/services/theme_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeManager().loadTheme();
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  void initState() {
    super.initState();
    ThemeManager().addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeManager().removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Sound Agent',
      theme: ThemeManager().themeData,
      initialRoute: Routes.home,
      routes: appRoutes,
    );
  }
}
