import 'package:flutter/material.dart';
import '../../services/theme_manager.dart';

class ChatMessage {
  final String name;
  final String content;
  final DateTime time;
  final bool isMe;
  final IconData? icon;

  ChatMessage({
    required this.name,
    required this.content,
    DateTime? time,
    required this.isMe,
    this.icon,
  }) : time = time ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'idx': 0, // 将在组件中设置
      'name': name,
      'content': content,
      'time': '${time.year}/${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}',
      'is_me': isMe,
    };
  }
}

class ChatDialogue extends StatefulWidget {
  const ChatDialogue({super.key});

  @override
  State<ChatDialogue> createState() => ChatDialogueState();
}

class ChatDialogueState extends State<ChatDialogue> {
  final List<ChatMessage> _messages = [];
  final List<bool> _selectedMessages = [];
  bool _showSelection = false;
  final ScrollController _scrollController = ScrollController();

  // 添加一条新消息
  void addMessage({
    required String name,
    required String content,
    DateTime? time,
    required bool isMe,
    IconData? icon,
  }) {
    setState(() {
      final newMessage = ChatMessage(
        name: name,
        content: content,
        time: time,
        isMe: isMe,
        icon: icon ?? Icons.person,
      );
      
      _messages.add(newMessage);
      _selectedMessages.add(false);
      
      // 按时间排序
      _messages.sort((a, b) => a.time.compareTo(b.time));
      
      // 滚动到底部
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    });
  }

  // 批量添加消息
  void addMessages(List<Map<String, dynamic>> messages) {
    debugPrint('开始添加 ${messages.length} 条消息到对话');
    
    final newMessages = messages.map((msg) {
      try {
        // 获取时间字符串
        String timeStr = msg['time']?.toString() ?? '';
        debugPrint('原始时间字符串: "$timeStr"');
        
        // 处理空时间字符串
        if (timeStr.isEmpty) {
          timeStr = DateTime.now().toIso8601String();
          debugPrint('使用当前时间: $timeStr');
        }
        
        DateTime parsedTime;
        try {
          // 尝试解析ISO格式
          parsedTime = DateTime.parse(timeStr);
        } catch (e) {
          debugPrint('ISO解析失败，尝试其他格式: $e');
          try {
            // 尝试解析自定义格式 (2025/8/11 12:34:56)
            final parts = timeStr.split(' ');
            if (parts.length >= 2) {
              final dateParts = parts[0].split('/');
              final timeParts = parts[1].split(':');
              if (dateParts.length == 3 && timeParts.length == 3) {
                parsedTime = DateTime(
                  int.parse(dateParts[0]),
                  int.parse(dateParts[1]),
                  int.parse(dateParts[2]),
                  int.parse(timeParts[0]),
                  int.parse(timeParts[1]),
                  int.parse(timeParts[2]),
                );
              } else {
                throw FormatException('日期格式不正确');
              }
            } else {
              throw FormatException('时间格式不正确');
            }
          } catch (e2) {
            debugPrint('所有解析尝试失败，使用当前时间: $e2');
            parsedTime = DateTime.now();
          }
        }
        
        debugPrint('解析后的时间: $parsedTime');
        
        return ChatMessage(
          name: msg['name']?.toString() ?? '未知用户',
          content: msg['content']?.toString() ?? '',
          time: parsedTime,
          isMe: msg['isMe'] as bool? ?? false,
          icon: msg['isMe'] as bool? ?? false ? Icons.person : Icons.smart_toy,
        );
      } catch (e) {
        debugPrint('处理消息时出错: $e');
        debugPrint('消息内容: $msg');
        return ChatMessage(
          name: '错误用户',
          content: '消息格式错误: ${msg.toString()}',
          time: DateTime.now(),
          isMe: false,
          icon: Icons.error,
        );
      }
    }).toList();
    
    setState(() {
      _messages.addAll(newMessages);
      _messages.sort((a, b) => a.time.compareTo(b.time));
      
      // 添加对应的选择状态
      for (var i = 0; i < newMessages.length; i++) {
        _selectedMessages.add(false);
      }
    });
    
    debugPrint('成功添加 ${newMessages.length} 条消息，总消息数: ${_messages.length}');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // 清除所有消息
  void clear() {
    setState(() {
      _messages.clear();
      _selectedMessages.clear();
    });
  }

  // 删除最后一条消息
  void deleteLatestMessage() {
    if (_messages.isNotEmpty) {
      setState(() {
        _messages.removeLast();
        _selectedMessages.removeLast();
      });
    }
  }

  // 删除指定消息
  bool deleteMessage({int? index, DateTime? time}) {
    if (index != null && index >= 0 && index < _messages.length) {
      setState(() {
        _messages.removeAt(index);
        _selectedMessages.removeAt(index);
      });
      return true;
    }
    
    if (time != null) {
      for (int i = 0; i < _messages.length; i++) {
        if (_messages[i].time == time) {
          setState(() {
            _messages.removeAt(i);
            _selectedMessages.removeAt(i);
          });
          return true;
        }
      }
    }
    
    return false;
  }

  // 显示选择框
  void showSelection() {
    setState(() {
      _showSelection = true;
    });
  }

  // 隐藏选择框
  void hideSelection() {
    setState(() {
      _showSelection = false;
      // 清除所有选择
      for (int i = 0; i < _selectedMessages.length; i++) {
        _selectedMessages[i] = false;
      }
    });
  }

  // 全选
  void selectAll() {
    setState(() {
      for (int i = 0; i < _selectedMessages.length; i++) {
        _selectedMessages[i] = true;
      }
    });
  }

  // 反选
  void invertSelection() {
    setState(() {
      for (int i = 0; i < _selectedMessages.length; i++) {
        _selectedMessages[i] = !_selectedMessages[i];
      }
    });
  }

  // 获取选择的消息
  List<Map<String, dynamic>> getSelection() {
    if (!_showSelection) return [];
    
    List<Map<String, dynamic>> selected = [];
    for (int i = 0; i < _messages.length; i++) {
      if (_selectedMessages[i]) {
        final message = _messages[i];
        selected.add({
          'idx': i,
          'name': message.name,
          'content': message.content,
          'time': '${message.time.year}/${message.time.month}/${message.time.day} '
                  '${message.time.hour.toString().padLeft(2, '0')}:${message.time.minute.toString().padLeft(2, '0')}:${message.time.second.toString().padLeft(2, '0')}',
          'is_me': message.isMe,
        });
      }
    }
    return selected;
  }

  // 获取所有消息
  List<Map<String, dynamic>> getAllMessages() {
    List<Map<String, dynamic>> allMessages = [];
    for (int i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      allMessages.add({
        'idx': i,
        'name': message.name,
        'content': message.content,
        'time': '${message.time.year}/${message.time.month}/${message.time.day} '
                '${message.time.hour.toString().padLeft(2, '0')}:${message.time.minute.toString().padLeft(2, '0')}:${message.time.second.toString().padLeft(2, '0')}',
        'is_me': message.isMe,
      });
    }
    return allMessages;
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager();
    final baseColor = themeManager.baseColor;
    final lighterColor = themeManager.lighterColor;
    final darkTextColor = themeManager.darkTextColor;

    return Column(
      children: [
        Expanded(
          child: Container(
            color: lighterColor.withValues(alpha: 0.1),
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(
                  message: message,
                  index: index,
                  baseColor: baseColor,
                  darkTextColor: darkTextColor,
                );
              },
            ),
          ),
        ),
        if (_showSelection)
          Container(
            color: lighterColor.withValues(alpha: 0.2),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: hideSelection,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('退出选择'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: selectAll,
                  icon: const Icon(Icons.select_all, size: 16),
                  label: const Text('全选'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: baseColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: invertSelection,
                  icon: const Icon(Icons.flip_to_back, size: 16),
                  label: const Text('反选'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMessageBubble({
    required ChatMessage message,
    required int index,
    required Color baseColor,
    required Color darkTextColor,
  }) {
    final isMe = message.isMe;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_showSelection) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, right: 8),
              child: Checkbox(
                value: _selectedMessages[index],
                onChanged: (bool? value) {
                  setState(() {
                    _selectedMessages[index] = value ?? false;
                  });
                },
                activeColor: baseColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
          Expanded(
            child: Row(
              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) ...[
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: baseColor.withValues(alpha: 0.2),
                    child: Icon(
                      message.icon ?? Icons.person,
                      size: 16,
                      color: baseColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                GestureDetector(
                  onLongPress: () => _showMessageActions(context, index, baseColor),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isMe 
                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)
                            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(12),
                          topRight: const Radius.circular(12),
                          bottomLeft: Radius.circular(isMe ? 12 : 0),
                          bottomRight: Radius.circular(isMe ? 0 : 12),
                        ),
                        border: Border.all(
                          color: isMe 
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.9)
                              : baseColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe) ...[
                            Text(
                              message.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isMe 
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : baseColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          Text(
                            message.content,
                            style: TextStyle(
                              fontSize: 14,
                              color: isMe 
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${message.time.hour.toString().padLeft(2, '0')}:${message.time.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 10,
                              color: (isMe 
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface)
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.green[100],
                    child: Icon(
                      message.icon ?? Icons.person,
                      size: 16,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageActions(BuildContext context, int index, Color baseColor) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RenderBox messageBox = context.findRenderObject() as RenderBox;
    final position = messageBox.localToGlobal(Offset.zero, ancestor: overlay);
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + messageBox.size.height,
        position.dx + messageBox.size.width,
        position.dy + messageBox.size.height + 100,
      ),
      items: [
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text('删除消息'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'select',
          child: Row(
            children: [
              Icon(Icons.check_circle, color: baseColor),
              SizedBox(width: 8),
              Text('选择消息'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      
      switch (value) {
        case 'delete':
          setState(() {
            _messages.removeAt(index);
            _selectedMessages.removeAt(index);
          });
          break;
        case 'select':
          setState(() {
            _showSelection = true;
            _selectedMessages[index] = true;
          });
          break;
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}