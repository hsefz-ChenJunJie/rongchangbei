import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/theme_manager.dart';

class BaseTextArea extends StatefulWidget {
  final String label;
  final String text;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool enabled;
  final bool expands;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final Color borderColor;
  final Color focusColor;
  final Color labelColor;
  final Color textColor;
  final Color placeholderColor;
  final Color? backgroundColor;
  final double borderWidth;
  final double borderRadius;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? labelStyle;
  final TextStyle? textStyle;
  final TextStyle? placeholderStyle;
  final bool showCounter;
  final bool autofocus;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final Widget? icon;

  const BaseTextArea({
    Key? key,
    required this.label,
    this.text = '',
    this.placeholder = '',
    this.onChanged,
    this.controller,
    this.keyboardType = TextInputType.multiline,
    this.inputFormatters,
    this.maxLines = 5,
    this.minLines = 3,
    this.maxLength,
    this.enabled = true,
    this.expands = false,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.borderColor = Colors.grey,
    this.focusColor = Colors.blue,
    this.labelColor = Colors.grey,
    this.textColor = Colors.black87,
    this.placeholderColor = Colors.grey,
    this.backgroundColor,
    this.borderWidth = 1.0,
    this.borderRadius = 8.0,
    this.contentPadding,
    this.labelStyle,
    this.textStyle,
    this.placeholderStyle,
    this.showCounter = true,
    this.autofocus = false,
    this.focusNode,
    this.onSubmitted,
    this.onTap,
    this.icon,
  }) : super(key: key);

  @override
  State<BaseTextArea> createState() => _BaseTextAreaState();
}

class _BaseTextAreaState extends State<BaseTextArea> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isFocused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController(text: widget.text);
    _focusNode = widget.focusNode ?? FocusNode();
    _hasText = widget.text.isNotEmpty;
    _controller.addListener(_handleTextChange);
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(BaseTextArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text && _controller.text != widget.text) {
      _controller.text = widget.text;
    }
  }

  void _handleTextChange() {
    if (!mounted) return;
    
    final hasText = _controller.text.isNotEmpty;
    if (_hasText != hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
    widget.onChanged?.call(_controller.text);
  }

  void _handleFocusChange() {
    if (!mounted) return;
    
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChange);
    _focusNode.removeListener(_handleFocusChange);
    if (widget.controller == null) {
      _controller.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
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

  void focus() {
    FocusScope.of(context).requestFocus(_focusNode);
  }

  void unfocus() {
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager();
    final baseColor = themeManager.baseColor;
    final darkerColor = themeManager.darkerColor;
    final lighterColor = themeManager.lighterColor;
    final darkTextColor = themeManager.darkTextColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? lighterColor,
                border: Border.all(
                  color: _isFocused ? baseColor : darkerColor,
                  width: widget.borderWidth,
                ),
                borderRadius: BorderRadius.circular(widget.borderRadius),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.icon != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 16),
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
                      focusNode: _focusNode,
                      keyboardType: widget.keyboardType,
                      inputFormatters: widget.inputFormatters,
                      maxLines: widget.maxLines,
                      minLines: widget.minLines,
                      maxLength: widget.maxLength,
                      enabled: widget.enabled,
                      expands: widget.expands,
                      textAlign: widget.textAlign,
                      textAlignVertical: widget.textAlignVertical ?? TextAlignVertical.top,
                      autofocus: widget.autofocus,
                      onSubmitted: widget.onSubmitted,
                      onTap: widget.onTap,
                      style: widget.textStyle ?? TextStyle(
                        color: darkTextColor,
                        fontSize: 16,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.placeholder,
                        hintStyle: widget.placeholderStyle ?? TextStyle(
                          color: darkTextColor.withValues(alpha: 0.6),
                          fontSize: 16,
                          height: 1.5,
                        ),
                        border: InputBorder.none,
                        contentPadding: widget.contentPadding ?? EdgeInsets.all(widget.icon != null ? 12 : 16),
                        counterText: widget.showCounter ? null : '',
                        isDense: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 12,
              top: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
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
      ],
    );
  }
}

