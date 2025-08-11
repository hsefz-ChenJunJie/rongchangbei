import 'package:flutter/material.dart';
import 'chat_input.dart';
import 'chat_dialogue.dart';

class ChatInputExample extends StatefulWidget {
  const ChatInputExample({super.key});

  @override
  State<ChatInputExample> createState() => _ChatInputExampleState();
}

class _ChatInputExampleState extends State<ChatInputExample> {
  final GlobalKey<ChatDialogueState> _dialogueKey = GlobalKey<ChatDialogueState>();
  final GlobalKey<ChatInputState> _inputKey = GlobalKey<ChatInputState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天输入示例'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            onPressed: () {
              _dialogueKey.currentState?.clear();
            },
            tooltip: '清空对话',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ChatDialogue(key: _dialogueKey),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ChatInput(
              key: _inputKey,
              dialogueState: _dialogueKey.currentState!,
              onSend: () {
                // 可以在这里添加发送后的回调逻辑
                // 消息已发送
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'chat_input_example_demo',
        onPressed: () {
          // 演示API用法
          _showDemoMenu();
        },
        child: const Icon(Icons.code),
      ),
    );
  }

  void _showDemoMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.text_fields),
                title: const Text('设置文本'),
                onTap: () {
                  _inputKey.currentState?.setText('这是预设的文本');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('追加文本'),
                onTap: () {
                  _inputKey.currentState?.appendText(' - 追加的内容');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('在光标处插入'),
                onTap: () {
                  _inputKey.currentState?.addText('[插入]');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.lightbulb),
                title: const Text('显示建议'),
                onTap: () {
                  _inputKey.currentState?.showSuggestion(' 建议的补全内容');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_add),
                title: const Text('添加测试角色'),
                onTap: () {
                  _inputKey.currentState?.addRole(
                    const ChatRole(
                      id: 'test',
                      name: '测试用户',
                      color: Colors.purple,
                      icon: Icons.bug_report,
                    ),
                  );
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cleaning_services),
                title: const Text('清空输入'),
                onTap: () {
                  _inputKey.currentState?.clear();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}