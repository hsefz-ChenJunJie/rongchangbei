import 'package:flutter/material.dart';
import '../widgets/chat_recording/chat_input.dart';
import '../widgets/chat_recording/chat_dialogue.dart';

class TestChatInputWidth extends StatefulWidget {
  const TestChatInputWidth({super.key});

  @override
  State<TestChatInputWidth> createState() => _TestChatInputWidthState();
}

class _TestChatInputWidthState extends State<TestChatInputWidth> {
  late ChatDialogueState _dialogueState;

  @override
  void initState() {
    super.initState();
    _dialogueState = ChatDialogueState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChatInput宽度测试'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // 模拟宽屏容器
          Expanded(
            child: Container(
              color: Colors.grey[200],
              child: const Center(
                child: Text('内容区域'),
              ),
            ),
          ),
          
          // 宽屏测试区域
          Container(
            width: double.infinity,
            color: Theme.of(context).scaffoldBackgroundColor,
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: ChatInputTestWrapper(),
            ),
          ),
          
          // 窄屏测试区域
          Container(
            width: 300, // 模拟窄屏
            color: Colors.amber[50],
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: ChatInputTestWrapper(),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatInputTestWrapper extends StatefulWidget {
  const ChatInputTestWrapper({super.key});

  @override
  State<ChatInputTestWrapper> createState() => _ChatInputTestWrapperState();
}

class _ChatInputTestWrapperState extends State<ChatInputTestWrapper> {
  late ChatDialogueState _dialogueState;

  @override
  void initState() {
    super.initState();
    _dialogueState = ChatDialogueState();
  }

  @override
  Widget build(BuildContext context) {
    return ChatDialogue(
      state: _dialogueState,
      child: ChatInput(
        dialogueState: _dialogueState,
        onSend: () {
          debugPrint('消息已发送');
        },
      ),
    );
  }
}

// 简化版的 ChatDialogue
class ChatDialogue extends StatefulWidget {
  final Widget child;
  final ChatDialogueState state;

  const ChatDialogue({
    super.key,
    required this.child,
    required this.state,
  });

  @override
  State<ChatDialogue> createState() => ChatDialogueState();
}

class ChatDialogueState extends State<ChatDialogue> {
  final List<Map<String, dynamic>> _messages = [];

  void addMessage({
    required String name,
    required String content,
    bool isMe = false,
  }) {
    setState(() {
      _messages.add({
        'name': name,
        'content': content,
        'isMe': isMe,
        'timestamp': DateTime.now(),
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}