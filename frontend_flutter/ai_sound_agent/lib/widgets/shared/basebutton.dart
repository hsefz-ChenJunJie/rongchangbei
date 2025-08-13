import 'package:flutter/material.dart';
import '../../services/theme_manager.dart';

class BaseButton extends StatefulWidget {
  final IconData? icon;
  final String? text;
  final Color? primaryColor;
  final Color? secondaryColor;
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final TextStyle? textStyle;
  final double iconSize;
  final double spacing;

  const BaseButton({
    Key? key,
    this.icon,
    this.text,
    this.primaryColor,
    this.secondaryColor,
    this.onPressed,
    this.width,
    this.height = 48,
    this.padding,
    this.borderRadius = 8.0,
    this.textStyle,
    this.iconSize = 24.0,
    this.spacing = 8.0,
  }) : super(key: key);

  @override
  State<BaseButton> createState() => _BaseButtonState();
}

class _BaseButtonState extends State<BaseButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  Color get _currentBackgroundColor {
    final themeManager = ThemeManager();
    final primaryColor = widget.primaryColor ?? themeManager.darkerColor;
    final secondaryColor = widget.secondaryColor ?? themeManager.baseColor;
    
    if (_isPressed) {
      return secondaryColor;
    } else if (_isHovered) {
      return secondaryColor;
    } else {
      return primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager();
    final textColor = themeManager.lightTextColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: widget.width,
          height: widget.height,
          padding: widget.padding ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _currentBackgroundColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: widget.iconSize,
                  color: textColor,
                ),
                if (widget.text != null) SizedBox(width: widget.spacing),
              ],
              if (widget.text != null)
                Text(
                  widget.text!,
                  style: widget.textStyle ??
                      TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

