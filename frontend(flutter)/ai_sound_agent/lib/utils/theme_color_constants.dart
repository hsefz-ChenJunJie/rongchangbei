import 'package:flutter/material.dart';

// This file is used to store the theme color constants.
enum ThemeColor {
  defaultColor( // 一元纸币配色
    Color(0xff6a855b),
    Color(0xffdfe7d7),
    Color(0xff3e563b),
    Color(0xffb0ce95),
    Color(0xff46776d)
  ),
  defaultRedColor( // 百元大钞配色
    Color(0xffeb4035),
    Color(0xfff5abb7),
    Color(0xffbe0f2d),
    Color(0xffd55f6f),
    Color(0xffcf273c)
  ),
  peachpuffColor(
    Color(0xffffdab3),
    Color(0xffffe4c4),
    Color(0xffff8c00),
    Color(0xffffc080),
    Color(0xffffa54f)
  ),
  ffb9deColor(
    Color(0xffffb9de),
    Color(0xffffecf6),
    Color(0xffff6dba),
    Color(0xffffd3ea),
    Color(0xffff86c6)
  );


  final Color baseColor;
  final Color lighterColor;
  final Color darkerColor;
  final Color lightTextColor;
  final Color darkTextColor;


  const ThemeColor(
    this.baseColor,
    this.lighterColor,
    this.darkerColor,
    this.lightTextColor,
    this.darkTextColor
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
