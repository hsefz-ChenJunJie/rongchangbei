import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/theme_manager.dart';

class BaseLineInput extends StatefulWidget {
  final String label;
  final String text;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final int? maxLength;
  final bool enabled;
  final Color borderColor;
  final Color focusColor;
  final Color labelColor;
  final Color textColor;
  final Color placeholderColor;
  final double borderWidth;
  final double borderRadius;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? labelStyle;
  final TextStyle? textStyle;
  final TextStyle? placeholderStyle;
  final Widget? icon;

  const BaseLineInput({
    Key? key,
    required this.label,
    this.text = '',
    this.placeholder = '',
    this.onChanged,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.borderColor = Colors.grey,
    this.focusColor = Colors.blue,
    this.labelColor = Colors.grey,
    this.textColor = Colors.black87,
    this.placeholderColor = Colors.grey,
    this.borderWidth = 1.0,
    this.borderRadius = 8.0,
    this.contentPadding,
    this.labelStyle,
    this.textStyle,
    this.placeholderStyle,
    this.icon,
  }) : super(key: key);

  @override
  State<BaseLineInput> createState() => _BaseLineInputState();
}

class _BaseLineInputState extends State<BaseLineInput> {
  late TextEditingController _controller;
  bool _isFocused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController(text: widget.text);
    _hasText = widget.text.isNotEmpty;
    _controller.addListener(_handleTextChange);
  }

  @override
  void didUpdateWidget(BaseLineInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text && _controller.text != widget.text) {
      _controller.text = widget.text;
    }
  }

  void _handleTextChange() {
    final hasText = _controller.text.isNotEmpty;
    if (_hasText != hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
    widget.onChanged?.call(_controller.text);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  String get currentText => _controller.text;

  void setText(String text) {
    _controller.text = text;
  }

  void clear() {
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager();
    final baseColor = themeManager.baseColor;
    final darkerColor = themeManager.darkerColor;
    final lighterColor = themeManager.lighterColor;
    final darkTextColor = themeManager.darkTextColor;
    
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() {
          _isFocused = hasFocus;
        });
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _isFocused ? baseColor : darkerColor,
                width: widget.borderWidth,
              ),
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.icon != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: IconTheme(
                      data: IconThemeData(
                        color: darkTextColor.withValues(alpha: 0.6),
                        size: 20,
                      ),
                      child: widget.icon!,
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    obscureText: widget.obscureText,
                    keyboardType: widget.keyboardType,
                    inputFormatters: widget.inputFormatters,
                    maxLines: widget.maxLines,
                    maxLength: widget.maxLength,
                    enabled: widget.enabled,
                    style: widget.textStyle ?? TextStyle(
                      color: darkTextColor,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.placeholder,
                      hintStyle: widget.placeholderStyle ?? TextStyle(
                        color: darkTextColor.withValues(alpha: 0.6),
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: widget.contentPadding ?? EdgeInsets.fromLTRB(widget.icon != null ? 8 : 12, 16, 12, 12),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 8,
            top: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              color: lighterColor,
              child: Text(
                widget.label,
                style: widget.labelStyle ?? TextStyle(
                  fontSize: 12,
                  color: _isFocused ? baseColor : darkTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

