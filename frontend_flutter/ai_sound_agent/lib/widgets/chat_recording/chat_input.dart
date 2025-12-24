import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:idialogue/services/theme_manager.dart';
import '../shared/base_line_input.dart';
import 'chat_dialogue.dart';
import 'role_selector.dart';
import 'role_manager.dart';

class ChatInput extends StatefulWidget {
  final ChatDialogueState dialogueState;
  final VoidCallback? onSend;
  final VoidCallback? onPlusButtonPressed;
  final Function(String)? onAppendText;

  const ChatInput({
    super.key,
    required this.dialogueState,
    this.onSend,
    this.onPlusButtonPressed,
    this.onAppendText,
  });

  @override
  State<ChatInput> createState() => ChatInputState();
}

class ChatInputState extends State<ChatInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  
  String _suggestion = '';
  bool _isShowingSuggestion = false;
  bool _isShowingAIPanel = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
    _controller.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _isShowingSuggestion) {
      _clearSuggestion();
    }
  }

  void _handleTextChange() {
    if (_isShowingSuggestion && _controller.text.isNotEmpty) {
      final currentText = _controller.text;
      final cursorPosition = _controller.selection.baseOffset;
      
      // 如果用户继续输入，清除建议
      if (_suggestion.isNotEmpty && 
          (currentText.length > cursorPosition || 
           !currentText.substring(0, cursorPosition).endsWith(_suggestion))) {
        _clearSuggestion();
      }
    }
  }

  void _clearSuggestion() {
    setState(() {
      _isShowingSuggestion = false;
      _suggestion = '';
    });
  }

  // 清空输入框
  void clear() {
    _controller.clear();
    _clearSuggestion();
  }

  // 设置文本
  void setText(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    _clearSuggestion();
  }

  // 追加文本
  void appendText(String text) {
    final currentText = _controller.text;
    _controller.text = currentText + text;
    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    _clearSuggestion();
  }

  // 在光标处添加文本
  void addText(String text) {
    if (!_focusNode.hasFocus) {
      appendText(text);
      return;
    }

    final currentText = _controller.text;
    final cursorPosition = _controller.selection.baseOffset;
    
    if (cursorPosition < 0 || cursorPosition > currentText.length) {
      appendText(text);
      return;
    }

    final newText = currentText.substring(0, cursorPosition) + 
                   text + 
                   currentText.substring(cursorPosition);
    
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(offset: cursorPosition + text.length);
    _clearSuggestion();
  }

  // 获取当前角色 - 现在使用全局角色管理器
  ChatRole getCurrentRole() {
    return RoleManager.instance.currentRole;
  }

  // 发送消息
  void send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final currentRole = getCurrentRole();
    
    widget.dialogueState.addMessage(
      name: currentRole.name,
      content: text,
      isMe: currentRole.id == 'me',
    );
    
    widget.onSend?.call();
  }

  // 发送并清空
  void sendAndClear() {
    send();
    clear();
  }

  // 显示建议
  void showSuggestion(String suggestion) {
    if (suggestion.isEmpty) {
      _clearSuggestion();
      return;
    }

    setState(() {
      _suggestion = suggestion;
      _isShowingSuggestion = true;
    });
  }

  // 切换AI面板显示状态
  void toggleUserOpinionPanel() {
    setState(() {
      _isShowingAIPanel = !_isShowingAIPanel;
    });
  }

  // 获取当前用户意见
  String getUserOpinion() {
    return _controller.text;
  }

  // 设置用户意见
  void setUserOpinion(String opinion) {
    _controller.text = opinion;
    _controller.selection = TextSelection.collapsed(offset: opinion.length);
  }

  // 追加用户意见
  void appendUserOpinion(String opinion) {
    final currentText = _controller.text;
    if (currentText.isEmpty) {
      _controller.text = opinion;
    } else {
      _controller.text = currentText + ' ' + opinion;
    }
    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
  }

  @override
  Widget build(BuildContext context) {
    // 获取屏幕高度，限制最大高度为屏幕高度的15%
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.15;
    final ThemeManagerInstance = ThemeManager();
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 角色选择和AI面板按钮区域
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                // 使用ListenableBuilder监听角色变化
                ListenableBuilder(
                  listenable: RoleManager.instance,
                  builder: (context, _) {
                    return const RoleSelector();
                  },
                ),
                const SizedBox(width: 8), // 在角色选择器和按钮之间添加间距
                // AI生成面板按钮 (加号按钮)
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.add, color: ThemeManagerInstance.darkTextColor, size: 20),
                    tooltip: '打开AI生成面板',
                    onPressed: widget.onPlusButtonPressed, // 使用传入的回调
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ),
                const Spacer(),
                // 发送按钮
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: sendAndClear,
                    padding: const EdgeInsets.all(8), // 减小内边距
                    constraints: const BoxConstraints(), // 移除默认约束
                  ),
                ),
              ],
            ),
          ),
          
          // 输入区域
          Expanded( // 使用Expanded来填充剩余空间
            child: Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                  if (!_isShowingSuggestion) {
                    sendAndClear();
                  } else {
                    // 应用建议
                    final currentText = _controller.text;
                    final newText = currentText + _suggestion;
                    _controller.text = newText;
                    _controller.selection = TextSelection.collapsed(offset: newText.length);
                    _clearSuggestion();
                  }
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch, // 让子组件填满高度
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        BaseLineInput(
                          label: '输入消息',
                          placeholder: '输入消息...',
                          controller: _controller,
                          maxLines: null, // 改为null让输入框自动适应
                          contentPadding: const EdgeInsets.fromLTRB(12, 8, 8, 8), // 减小内边距，移除右侧空间给按钮
                          labelStyle: TextStyle(
                            fontSize: 12, // 减小字体大小
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                          ),
                          placeholderStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          textStyle: TextStyle(
                            fontSize: 14, // 减小字体大小
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          onChanged: (value) {
                            if (_isShowingSuggestion) {
                              _clearSuggestion();
                            }
                          },
                        ),
                        if (_isShowingSuggestion && _suggestion.isNotEmpty)
                          Positioned(
                            right: 12, // 调整位置
                            bottom: 8, // 调整位置
                            child: Text(
                              _suggestion,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 12, // 减小字体大小
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}