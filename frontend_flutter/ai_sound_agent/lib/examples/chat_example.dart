import 'package:flutter/material.dart';
import '../widgets/chat_recording/chat_dialogue.dart';
import '../widgets/chat_recording/chat_input.dart';

class ChatDemoPage extends StatefulWidget {
  const ChatDemoPage({super.key});

  @override
  State<ChatDemoPage> createState() => _ChatDemoPageState();
}

class _ChatDemoPageState extends State<ChatDemoPage> {
  final GlobalKey<ChatDialogueState> _dialogueKey = GlobalKey<ChatDialogueState>();
  final GlobalKey<ChatInputState> _inputKey = GlobalKey<ChatInputState>();

  @override
  void initState() {
    super.initState();
    // 添加一些初始消息
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dialogueKey.currentState?.addMessage(
        name: '张三',
        content: '大家好！我是张三。',
        isMe: false,
      );
      
      _dialogueKey.currentState?.addMessage(
        name: '李四',
        content: '你好张三，我是李四。',
        isMe: false,
      );
      
      _dialogueKey.currentState?.addMessage(
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
        title: const Text('聊天对话框演示'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              _dialogueKey.currentState?.clear();
              _dialogueKey.currentState?.addMessage(
                name: '系统',
                content: '对话已清空',
                isMe: false,
                icon: Icons.cleaning_services,
              );
            },
            tooltip: '清空对话',
          ),
          IconButton(
            icon: const Icon(Icons.select_all),
            onPressed: () {
              _dialogueKey.currentState?.showSelection();
            },
            tooltip: '显示选择',
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              _dialogueKey.currentState?.hideSelection();
            },
            tooltip: '隐藏选择',
          ),
        ],
      ),
      body: Column(
        children: [
          // 聊天对话框
          Expanded(
            child: ChatDialogue(
              key: _dialogueKey,
            ),
          ),
          // 新的输入组件
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ChatInput(
              key: _inputKey,
              dialogueState: _dialogueKey.currentState!,
              onSend: () {
                // 发送成功后的回调
              },
            ),
          ),
        ],
      ),
    );
  }
}