import 'package:flutter/material.dart';
import 'package:ai_sound_agent/widgets/shared/bottom_navigator.dart';

// app info

const String appName = 'AI Sound Agent';
const String companyName = 'efzzz';



// api

const String hitokotoApi = 'https://v1.hitokoto.cn';
const String mainDefaultApi = 'http://127.0.0.1:8000';

// api default route

const String textToSpeechApiRoute = '/tts';
const String speechToTextApiRoute = '/stt';
const String largeLanguageModelApiRoute = '/llm';

// navigator pagetiles

const List<BottomNavItem> pagetiles = const [
  BottomNavItem(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: '首页',
  ),
  BottomNavItem(
    icon: Icons.compass_calibration_outlined,
    selectedIcon: Icons.compass_calibration,
    label: '发现',
  ),
  BottomNavItem(
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    label: '我的',
  ),
];
