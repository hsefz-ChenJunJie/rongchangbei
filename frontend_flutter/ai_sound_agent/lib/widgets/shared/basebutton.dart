import 'package:flutter/material.dart';

class BaseButton extends StatefulWidget {
  final IconData? icon;
  final String? text;
  final Color primaryColor;
  final Color secondaryColor;
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
    required this.primaryColor,
    required this.secondaryColor,
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
    if (_isPressed) {
      return widget.secondaryColor;
    } else if (_isHovered) {
      return widget.secondaryColor;
    } else {
      return widget.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                color: Colors.black.withOpacity(0.1),
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
                  color: Colors.white,
                ),
                if (widget.text != null) SizedBox(width: widget.spacing),
              ],
              if (widget.text != null)
                Text(
                  widget.text!,
                  style: widget.textStyle ??
                      const TextStyle(
                        color: Colors.white,
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

// 使用示例
class BaseButtonExamples extends StatelessWidget {
  const BaseButtonExamples({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Base Button Examples')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 20,
          children: [
            // 只有图标
            BaseButton(
              icon: Icons.favorite,
              primaryColor: Colors.red,
              secondaryColor: Colors.red.shade700,
              onPressed: () => print('Favorite button pressed'),
            ),
            
            // 只有文字
            BaseButton(
              text: '点击我',
              primaryColor: Colors.blue,
              secondaryColor: Colors.blue.shade700,
              onPressed: () => print('Text button pressed'),
            ),
            
            // 图标和文字
            BaseButton(
              icon: Icons.send,
              text: '发送',
              primaryColor: Colors.green,
              secondaryColor: Colors.green.shade700,
              onPressed: () => print('Send button pressed'),
            ),
            
            // 自定义大小
            BaseButton(
              icon: Icons.settings,
              text: '设置',
              primaryColor: Colors.purple,
              secondaryColor: Colors.purple.shade700,
              width: 200,
              height: 60,
              onPressed: () => print('Settings button pressed'),
            ),
          ],
        ),
      ),
    );
  }
}