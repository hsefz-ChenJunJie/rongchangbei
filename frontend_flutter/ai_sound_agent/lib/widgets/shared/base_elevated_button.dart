import 'package:flutter/material.dart';
import '../../utils/theme_color_constants.dart';

class BaseElevatedButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? icon;
  final String? label;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isSpecial;
  final ButtonStyle? style;
  final double? elevation;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double? width;
  final double? height;
  final bool expanded;

  const BaseElevatedButton({
    Key? key,
    this.onPressed,
    this.child,
    this.icon,
    this.label,
    this.backgroundColor,
    this.foregroundColor,
    this.isSpecial = false,
    this.style,
    this.elevation,
    this.padding,
    this.borderRadius = 8.0,
    this.width,
    this.height,
    this.expanded = false,
  })  : assert(child != null || (icon != null || label != null)),
        super(key: key);

  const BaseElevatedButton.icon({
    Key? key,
    required VoidCallback? onPressed,
    required Widget icon,
    required String label,
    Color? backgroundColor,
    Color? foregroundColor,
    bool isSpecial = false,
    ButtonStyle? style,
    double? elevation,
    EdgeInsetsGeometry? padding,
    double borderRadius = 8.0,
    double? width,
    double? height,
    bool expanded = false,
  }) : this(
          key: key,
          onPressed: onPressed,
          icon: icon,
          label: label,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          isSpecial: isSpecial,
          style: style,
          elevation: elevation,
          padding: padding,
          borderRadius: borderRadius,
          width: width,
          height: height,
          expanded: expanded,
        );

  ButtonStyle _getButtonStyle(BuildContext context) {
    if (style != null) return style!;

    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    ThemeColor themeColor = ThemeColor.defaultColor;
    for (var color in ThemeColor.values) {
      if (color.baseColor.value == primaryColor.value) {
        themeColor = color;
        break;
      }
    }

    if (isSpecial) {
      return ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor ?? Colors.white,
        padding: padding ?? const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        elevation: elevation ?? 2,
      );
    }

    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? themeColor.darkerColor,
      foregroundColor: foregroundColor ?? themeColor.lightTextColor,
      padding: padding ?? const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      elevation: elevation ?? 2,
    ).copyWith(
      backgroundColor: MaterialStateProperty.resolveWith<Color?>(
        (Set<MaterialState> states) {
          if (states.contains(MaterialState.pressed)) {
            return backgroundColor ?? themeColor.baseColor;
          }
          if (states.contains(MaterialState.hovered)) {
            return backgroundColor ?? themeColor.baseColor;
          }
          if (states.contains(MaterialState.focused)) {
            return backgroundColor ?? themeColor.baseColor;
          }
          if (states.contains(MaterialState.disabled)) {
            return (backgroundColor ?? themeColor.darkerColor).withValues(alpha: 0.5);
          }
          return backgroundColor ?? themeColor.darkerColor;
        },
      ),
      foregroundColor: MaterialStateProperty.resolveWith<Color?>(
        (Set<MaterialState> states) {
          if (states.contains(MaterialState.disabled)) {
            return (foregroundColor ?? themeColor.lightTextColor).withValues(alpha: 0.5);
          }
          return foregroundColor ?? themeColor.lightTextColor;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttonStyle = _getButtonStyle(context);

    Widget button;
    if (child != null) {
      button = ElevatedButton(
        onPressed: onPressed,
        style: buttonStyle,
        child: child,
      );
    } else if (icon != null && label != null) {
      button = ElevatedButton.icon(
        onPressed: onPressed,
        style: buttonStyle,
        icon: icon!,
        label: Text(
          label!,
          style: const TextStyle(fontSize: 16),
        ),
      );
    } else if (label != null) {
      button = ElevatedButton(
        onPressed: onPressed,
        style: buttonStyle,
        child: Text(
          label!,
          style: const TextStyle(fontSize: 16),
        ),
      );
    } else if (icon != null) {
      button = ElevatedButton(
        onPressed: onPressed,
        style: buttonStyle,
        child: icon,
      );
    } else {
      // 如果所有可选参数都为null，创建一个空按钮
      button = ElevatedButton(
        onPressed: onPressed,
        style: buttonStyle,
        child: const SizedBox(),
      );
    }

    if (width != null || height != null) {
      button = SizedBox(
        width: width,
        height: height,
        child: button,
      );
    }

    if (expanded) {
      button = SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    return button;
  }
}

