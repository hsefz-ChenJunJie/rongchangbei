import 'package:flutter/material.dart';

// This file is used to store the theme color constants.
enum ThemeColor {
  defaultRed(
    Colors.red,
    Colors.redAccent,
    Color(0xFFB71C1C), // Colors.red[700]的确定值
  ),
  defaultGreen(
    Colors.green,
    Color.fromARGB(255, 194, 231, 213),
    Color.fromARGB(255, 48, 131, 54), // Colors.green[700]的确定值
  ),
  defaultBlue(
    Colors.blue,
    Colors.cyan,
    Color(0xFF0D47A1), // Colors.blue[700]的确定值
  );

  final Color baseColor;
  final Color lighterColor;
  final Color darkerColor;
  final Color textColor;

  const ThemeColor(
    this.baseColor,
    this.lighterColor,
    this.darkerColor,
    this.textColor
  );

  // 获取颜色方案
  ColorScheme get colorScheme => ColorScheme.light(
        primary: baseColor,
        secondary: lighterColor,
        tertiary: darkerColor,
        onPrimary: textColor,
      );

  // 创建主题数据
  ThemeData get themeData => ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
      );
}

// 颜色工具类
class ColorUtils {
  // 将十六进制颜色字符串转换为Color对象
  static Color hexToColor(String hex) {
    final String hexColor = hex.replaceAll('#', '');
    
    if (hexColor.length == 6) {
      return Color(int.parse('0xFF$hexColor'));
    } else if (hexColor.length == 8) {
      return Color(int.parse('0x$hexColor'));
    } else {
      throw FormatException('Invalid hex color format. Use #RRGGBB or #AARRGGBB');
    }
  }

  

  // 获取颜色的亮度值
  static double getLuminance(Color color) {
    return color.computeLuminance();
  }

  // 判断颜色是否为亮色
  static bool isLightColor(Color color) {
    return getLuminance(color) > 0.5;
  }

  // 根据背景色自动选择黑色或白色文字
  static Color getContrastColor(Color backgroundColor) {
    return isLightColor(backgroundColor) ? Colors.black : Colors.white;
  }

  // 生成颜色的不同亮度版本
  static Color lighten(Color color, [double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    
    final HSLColor hsl = HSLColor.fromColor(color);
    final HSLColor lighter = hsl.withLightness(
      (hsl.lightness + amount).clamp(0.0, 1.0),
    );
    
    return lighter.toColor();
  }

  static Color darken(Color color, [double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    
    final HSLColor hsl = HSLColor.fromColor(color);
    final HSLColor darker = hsl.withLightness(
      (hsl.lightness - amount).clamp(0.0, 1.0),
    );
    
    return darker.toColor();
  }
}

// 向后兼容的别名
@Deprecated('Use ColorUtils.hexToColor instead')
Color hexToColor(String hex) => ColorUtils.hexToColor(hex);
