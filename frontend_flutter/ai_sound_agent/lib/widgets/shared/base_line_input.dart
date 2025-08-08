import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'base_elevated_button.dart';
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
                contentPadding: widget.contentPadding ?? const EdgeInsets.fromLTRB(12, 16, 12, 12),
                isDense: true,
              ),
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

// 使用示例
class BaseLineInputExamples extends StatefulWidget {
  const BaseLineInputExamples({Key? key}) : super(key: key);

  @override
  State<BaseLineInputExamples> createState() => _BaseLineInputExamplesState();
}

class _BaseLineInputExamplesState extends State<BaseLineInputExamples> {
  final TextEditingController _controller1 = TextEditingController(text: '');
  final TextEditingController _controller2 = TextEditingController(text: '预设文本');
  String _text3 = '';

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Base Line Input Examples')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          spacing: 24,
          children: [
            // 基本用法
            BaseLineInput(
              label: '用户名',
              placeholder: '请输入用户名',
              onChanged: (value) {
                print('用户名: $value');
              },
            ),

            // 带控制器
            BaseLineInput(
              label: '邮箱',
              controller: _controller1,
              placeholder: '请输入邮箱地址',
              keyboardType: TextInputType.emailAddress,
              onChanged: (value) {
                print('邮箱: $value');
              },
            ),

            // 预设文本
            BaseLineInput(
              label: '描述',
              text: '预设文本',
              placeholder: '请输入描述',
              maxLines: 3,
              onChanged: (value) {
                print('描述: $value');
              },
            ),

            // 密码输入
            BaseLineInput(
              label: '密码',
              placeholder: '请输入密码',
              obscureText: true,
              onChanged: (value) {
                print('密码: $value');
              },
            ),

            // 自定义样式
            BaseLineInput(
              label: '电话号码',
              placeholder: '请输入电话号码',
              keyboardType: TextInputType.phone,
              borderColor: Colors.purple,
              focusColor: Colors.purple,
              labelColor: Colors.purple,
              onChanged: (value) {
                print('电话: $value');
              },
            ),

            // 禁用状态
            BaseLineInput(
              label: '禁用输入',
              text: '这是禁用状态的文本',
              placeholder: '无法输入',
              enabled: false,
            ),

            // 显示当前值
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BaseLineInput(
                  label: '动态显示',
                  placeholder: '输入内容会显示在下面',
                  text: _text3,
                  onChanged: (value) {
                    setState(() {
                      _text3 = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '当前输入: $_text3',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),

            // 操作按钮
            Row(
              spacing: 8,
              children: [
                BaseElevatedButton(
                  onPressed: () {
                    setState(() {
                      _controller1.text = '新设置的文本';
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('设置邮箱文本'),
                ),
                BaseElevatedButton(
                  onPressed: () {
                    _controller1.clear();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('清空邮箱'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}