import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 模拟的语音识别服务
class ApiService {
  static Future<String> speechToText() async {
    // 实际项目中这里会调用真实的语音识别API
    await Future.delayed(const Duration(seconds: 2)); // 模拟识别延迟
    return "这是语音识别后的文本，你可以修改后发送";
  }
}

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '聊天记录',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const ChatScreen(),
    );
  }
}

// 消息模型
class Message {
  final String sender;
  final String text;
  final DateTime time;
  final bool isMe;

  Message({
    required this.sender,
    required this.text,
    required this.time,
    required this.isMe,
  });
}

// 角色模型
class Role {
  final String name;
  final IconData icon;

  Role({required this.name, required this.icon});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<Message> _messages = [];
  final List<Role> _roles = [
    Role(name: "我自己", icon: Icons.person),
    Role(name: "老板", icon: Icons.business_center),
    Role(name: "项目经理", icon: Icons.work),
    Role(name: "客户", icon: Icons.people),
  ];
  Role _selectedRole = Role(name: "我自己", icon: Icons.person);
  bool _isRecording = false;

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;
    
    _textController.clear();
    setState(() {
      _messages.insert(0, Message(
        sender: _selectedRole.name,
        text: text,
        time: DateTime.now(),
        isMe: _selectedRole.name == "我自己",
      ));
    });
  }

  Future<void> _startRecording() async {
    setState(() => _isRecording = true);
    try {
      final recognizedText = await ApiService.speechToText();
      setState(() {
        _textController.text = recognizedText;
        _isRecording = false;
      });
    } catch (e) {
      setState(() => _isRecording = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("语音识别失败，请重试")),
      );
    }
  }

  void _showRoleSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("选择对话角色", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _roles.map((role) {
                  return ChoiceChip(
                    label: Text(role.name),
                    selected: _selectedRole.name == role.name,
                    avatar: Icon(role.icon, color: Colors.white),
                    onSelected: (selected) {
                      setState(() => _selectedRole = role);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("添加新角色"),
                onPressed: () => _addNewRole(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _addNewRole(BuildContext context) {
    TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("添加新角色"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: "角色名称",
            hintText: "例如：同事",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                setState(() {
                  _roles.add(Role(
                    name: nameController.text.trim(),
                    icon: Icons.person_add,
                  ));
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("已添加 ${nameController.text}")),
                );
              }
            },
            child: const Text("添加"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("对话记录"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Align(
        alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Card(
            color: message.isMe ? Colors.lightGreen[100] : Colors.white,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _roles.firstWhere((r) => r.name == message.sender).icon,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        message.sender,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(message.text),
                  const SizedBox(height: 4),
                  Text(
                    "${message.time.hour}:${message.time.minute.toString().padLeft(2, '0')}",
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          // 角色选择按钮
          IconButton(
            icon: Icon(_selectedRole.icon, color: Colors.green),
            onPressed: () => _showRoleSelector(context),
          ),
          
          // 语音识别按钮
          IconButton(
            icon: _isRecording
                ? const CircularProgressIndicator(strokeWidth: 2)
                : const Icon(Icons.mic, color: Colors.green),
            onPressed: _isRecording ? null : _startRecording,
          ),
          
          // 输入框
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: "输入消息...",
                border: InputBorder.none,
              ),
              minLines: 1,
              maxLines: 5,
            ),
          ),
          
          // 发送按钮
          IconButton(
            icon: const Icon(Icons.send, color: Colors.green),
            onPressed: () => _handleSubmitted(_textController.text),
          ),
        ],
      ),
    );
  }
}