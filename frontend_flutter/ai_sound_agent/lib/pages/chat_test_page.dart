import 'package:flutter/material.dart';
import '../widgets/chat_recording/chat_dialogue.dart';

class ChatTestPage extends StatefulWidget {
  const ChatTestPage({Key? key}) : super(key: key);

  @override
  State<ChatTestPage> createState() => _ChatTestPageState();
}

class _ChatTestPageState extends State<ChatTestPage> {
  final GlobalKey<ChatDialogueState> _chatKey = GlobalKey<ChatDialogueState>();
  final TextEditingController _nameController = TextEditingController(text: '张三');
  final TextEditingController _messageController = TextEditingController(text: '你好！');
  bool _isMe = false;

  @override
  void initState() {
    super.initState();
    // 添加一些初始消息
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatKey.currentState?.addMessage(
        name: '张三',
        content: '大家好！我是张三。',
        isMe: false,
      );
      
      _chatKey.currentState?.addMessage(
        name: '李四',
        content: '你好张三，我是李四。',
        isMe: false,
      );
      
      _chatKey.currentState?.addMessage(
        name: '我',
        content: '大家好，很高兴认识你们！',
        isMe: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天对话框测试'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              _chatKey.currentState?.clear();
            },
          ),
          IconButton(
            icon: const Icon(Icons.select_all),
            onPressed: () {
              _chatKey.currentState?.showSelection();
            },
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              _chatKey.currentState?.hideSelection();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 控制面板
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: '用户名',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          labelText: '消息内容',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: _isMe,
                      onChanged: (value) {
                        setState(() {
                          _isMe = value ?? false;
                        });
                      },
                    ),
                    const Text('是否是我发送的消息'),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        if (_nameController.text.isNotEmpty && _messageController.text.isNotEmpty) {
                          _chatKey.currentState?.addMessage(
                            name: _nameController.text,
                            content: _messageController.text,
                            isMe: _isMe,
                          );
                          _messageController.clear();
                        }
                      },
                      child: const Text('发送消息'),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        final selected = _chatKey.currentState?.getSelection() ?? [];
                        if (selected.isNotEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('选择了 ${selected.length} 条消息'),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('没有选择任何消息'),
                            ),
                          );
                        }
                      },
                      child: const Text('获取选择'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _chatKey.currentState?.deleteLatestMessage();
                      },
                      child: const Text('删除最后一条'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 聊天对话框
          Expanded(
            child: ChatDialogue(
              key: _chatKey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}