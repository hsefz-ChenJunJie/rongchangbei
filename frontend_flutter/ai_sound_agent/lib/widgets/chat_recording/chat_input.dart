import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shared/base_line_input.dart';
import '../shared/base_elevated_button.dart';
import 'chat_dialogue.dart';

class ChatRole {
  final String id;
  final String name;
  final Color color;
  final IconData icon;

  const ChatRole({
    required this.id,
    required this.name,
    this.color = Colors.blue,
    this.icon = Icons.person,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatRole &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class ChatInput extends StatefulWidget {
  final ChatDialogueState dialogueState;
  final VoidCallback? onSend;

  const ChatInput({
    super.key,
    required this.dialogueState,
    this.onSend,
  });

  @override
  State<ChatInput> createState() => ChatInputState();
}

class ChatInputState extends State<ChatInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  
  // 角色管理
  final List<ChatRole> _roles = [
    const ChatRole(id: 'me', name: '我自己', color: Colors.green, icon: Icons.person),
    const ChatRole(id: 'boss', name: '老板', color: Colors.red, icon: Icons.business),
    const ChatRole(id: 'pm', name: '项目经理', color: Colors.orange, icon: Icons.group),
    const ChatRole(id: 'client', name: '客户', color: Colors.blue, icon: Icons.account_circle),
  ];
  
  ChatRole _currentRole = const ChatRole(id: 'me', name: '我自己', color: Colors.green, icon: Icons.person);
  String _suggestion = '';
  bool _isShowingSuggestion = false;

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

  // 发送消息
  void send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    widget.dialogueState.addMessage(
      name: _currentRole.name,
      content: text,
      isMe: _currentRole.id == 'me',
    );
    
    widget.onSend?.call();
  }

  // 发送并清空
  void sendAndClear() {
    send();
    clear();
  }

  // 切换角色
  void changeRole(ChatRole role) {
    setState(() {
      _currentRole = role;
    });
  }

  // 添加角色
  void addRole(ChatRole role) {
    setState(() {
      if (!_roles.contains(role)) {
        _roles.add(role);
      }
      _currentRole = role;
    });
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



  void _showRoleSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '选择角色',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: _roles.length,
                  itemBuilder: (context, index) {
                    final role = _roles[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: role.color.withValues(alpha: 0.2),
                        child: Icon(role.icon, color: role.color),
                      ),
                      title: Text(
                        role.name,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      trailing: _currentRole == role 
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: () {
                        changeRole(role);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: BaseElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: '添加新角色',
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _showAddRoleDialog(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddRoleDialog(BuildContext context) {
    final nameController = TextEditingController();
    Color selectedColor = Colors.blue;
    IconData selectedIcon = Icons.person;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                '添加新角色',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        labelText: '角色名称',
                        hintText: '例如：同事、助手',
                        labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                      ),
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '选择颜色',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        Colors.blue, Colors.red, Colors.green, 
                        Colors.orange, Colors.purple, Colors.pink,
                        Colors.teal, Colors.indigo, Colors.brown
                      ].map((color) => GestureDetector(
                        onTap: () => setState(() => selectedColor = color),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: selectedColor == color 
                                ? Border.all(color: Colors.black, width: 2)
                                : null,
                          ),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '选择图标',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        Icons.person, Icons.business, Icons.group,
                        Icons.account_circle, Icons.work, Icons.school,
                        Icons.support_agent, Icons.favorite
                      ].map((icon) => GestureDetector(
                        onTap: () => setState(() => selectedIcon = icon),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: selectedIcon == icon 
                                ? selectedColor.withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: selectedColor),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                BaseElevatedButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty) {
                      final newRole = ChatRole(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameController.text,
                        color: selectedColor,
                        icon: selectedIcon,
                      );
                      addRole(newRole);
                      Navigator.pop(context);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('添加'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 角色显示区域和发送按钮在同一行
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              // 角色选择按钮
              GestureDetector(
                onTap: _showRoleSelector,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _currentRole.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _currentRole.color.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_currentRole.icon, size: 16, color: _currentRole.color),
                      const SizedBox(width: 4),
                      Text(
                        _currentRole.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: _currentRole.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
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
                ),
              ),
            ],
          ),
        ),
        
        // 输入区域
        Focus(
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
            children: [
              Expanded(
                child: Stack(
                  children: [
                    BaseLineInput(
                      label: '输入消息',
                      placeholder: '输入消息...',
                      controller: _controller,
                      maxLines: 3,
                      contentPadding: const EdgeInsets.fromLTRB(12, 12, 48, 12),
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                      ),
                      placeholderStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      textStyle: TextStyle(
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
                        right: 48,
                        bottom: 12,
                        child: Text(
                          _suggestion,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}