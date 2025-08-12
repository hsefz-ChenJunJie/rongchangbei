import 'package:flutter/material.dart';
import 'package:ai_sound_agent/pages/home_page.dart';
import 'package:ai_sound_agent/pages/settings.dart';
import 'package:ai_sound_agent/pages/advanced_settings.dart';
import 'package:ai_sound_agent/pages/device_test_page.dart';
import 'package:ai_sound_agent/pages/main_processing.dart';
import 'package:ai_sound_agent/examples/text_area_example.dart';
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
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/settings': (context) => const Settings(),
        '/settings/advanced': (context) => const AdvancedSettingsPage(),
        '/device-test': (context) => const DeviceTestPage(),
        '/main-processing': (context) => const MainProcessingPage(),
        '/text-area-test': (context) => const TextAreaTestPage(),
      },
    );
  }
}
