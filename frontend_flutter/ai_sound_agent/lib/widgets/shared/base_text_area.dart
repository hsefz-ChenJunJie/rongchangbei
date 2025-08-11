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
    final hasText = _controller.text.isNotEmpty;
    if (_hasText != hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
    widget.onChanged?.call(_controller.text);
  }

  void _handleFocusChange() {
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

// 使用示例
class BaseTextAreaExamples extends StatefulWidget {
  const BaseTextAreaExamples({Key? key}) : super(key: key);

  @override
  State<BaseTextAreaExamples> createState() => _BaseTextAreaExamplesState();
}

class _BaseTextAreaExamplesState extends State<BaseTextAreaExamples> {
  final TextEditingController _controller1 = TextEditingController(text: '');
  final TextEditingController _controller2 = TextEditingController(text: '这是一段预设的多行文本内容。\n可以包含多行文字，\n用于展示文本域的预设内容效果。');
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
      appBar: AppBar(title: const Text('Base Text Area Examples')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          spacing: 24,
          children: [
            // 基本用法
            BaseTextArea(
              label: '评论内容',
              placeholder: '请输入您的评论内容...',
              onChanged: (value) {
                print('评论: $value');
              },
            ),

            // 带图标
            BaseTextArea(
              label: '详细描述',
              placeholder: '请详细描述您的问题或建议...',
              maxLines: 4,
              minLines: 2,
              maxLength: 200,
              icon: const Icon(Icons.description),
              onChanged: (value) {
                print('描述: $value');
              },
            ),

            // 带图标和预设文本
            BaseTextArea(
              label: '反馈内容',
              text: '这是一段预设的多行文本内容。\n可以包含多行文字，\n用于展示文本域的预设内容效果。',
              placeholder: '请输入反馈内容...',
              maxLines: 6,
              icon: const Icon(Icons.feedback),
              onChanged: (value) {
                print('反馈: $value');
              },
            ),

            // 自定义样式
            BaseTextArea(
              label: '备注信息',
              placeholder: '请输入备注信息...',
              maxLines: 3,
              borderColor: Colors.purple,
              focusColor: Colors.purple,
              labelColor: Colors.purple,
              backgroundColor: Colors.purple.shade50,
              icon: const Icon(Icons.note, color: Colors.purple),
              onChanged: (value) {
                print('备注: $value');
              },
            ),

            // 禁用状态
            BaseTextArea(
              label: '禁用文本域',
              text: '这是禁用状态的文本内容，\n用户无法进行编辑。',
              placeholder: '无法输入',
              enabled: false,
              maxLines: 3,
              icon: const Icon(Icons.lock),
            ),

            // 展开填充
            BaseTextArea(
              label: '自适应高度',
              placeholder: '此文本域会根据内容自动调整高度...',
              expands: true,
              maxLines: null,
              minLines: null,
              maxLength: 500,
              icon: const Icon(Icons.auto_awesome),
              onChanged: (value) {
                print('自适应: $value');
              },
            ),

            // 显示当前值
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BaseTextArea(
                  label: '动态显示',
                  placeholder: '输入内容会显示在下面...',
                  text: _text3,
                  maxLines: 3,
                  maxLength: 100,
                  icon: const Icon(Icons.edit),
                  onChanged: (value) {
                    setState(() {
                      _text3 = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '当前输入:\n$_text3',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
              ],
            ),

            // 操作按钮
            Row(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _controller1.text = '这是通过按钮设置的新文本内容，\n包含多行文本，\n用于演示程序化设置文本的功能。';
                    });
                  },
                  child: const Text('设置描述文本'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _controller1.clear();
                  },
                  child: const Text('清空描述'),
                ),
                ElevatedButton(
                  onPressed: () {
                    FocusScope.of(context).requestFocus(FocusNode());
                  },
                  child: const Text('收起键盘'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}