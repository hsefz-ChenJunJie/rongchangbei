import 'package:flutter/material.dart';
import 'dp_manager.dart';
import '../widgets/chat_recording/chat_dialogue.dart';

class DPManagerExample extends StatefulWidget {
  const DPManagerExample({super.key});

  @override
  State<DPManagerExample> createState() => _DPManagerExampleState();
}

class _DPManagerExampleState extends State<DPManagerExample> {
  final DPManager _dpManager = DPManager();
  DialoguePackage? _defaultDp;
  List<String> _allDpNames = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeDPManager();
  }

  Future<void> _initializeDPManager() async {
    try {
      await _dpManager.init();
      await _loadData();
    } catch (e) {
      print('初始化失败: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // 获取默认对话包
      _defaultDp = await _dpManager.getDefaultDp();
      
      // 使用内置的dp文件列表
      _allDpNames = _dpManager.getAvailableDpFiles();
    } catch (e) {
      print('加载数据失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createNewDp() async {
    final name = 'test_${DateTime.now().millisecondsSinceEpoch}';
    try {
      await _dpManager.createNewDp(
        name,
        scenarioDescription: '测试对话情景',
        initialMessages: [
          Message(
            idx: 0,
            name: 'user',
            content: '你好，这是一个测试对话',
            time: '${DateTime.now().year}/${DateTime.now().month}/${DateTime.now().day} '
                   '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}',
            isMe: true,
          ),
        ],
      );
      await _loadData();
    } catch (e) {
      print('创建新对话包失败: $e');
    }
  }

  // 从ChatDialogue创建对话包的示例方法
  Future<void> _saveChatToDp(ChatDialogueState chatState, String name) async {
    try {
      final messages = chatState.getAllMessages();
      await _dpManager.createDpFromChatSelection(
        name,
        messages,
        scenarioDescription: '保存的聊天记录',
      );
      await _loadData();
    } catch (e) {
      print('保存聊天记录失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DP管理器示例'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DP目录: ${_dpManager.dpDirectoryPath}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  if (_defaultDp != null) ...[
                    const Text('默认对话包:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('名称: ${_defaultDp!.name}'),
                    Text('描述: ${_defaultDp!.scenarioDescription}'),
                    Text('消息数: ${_defaultDp!.messages.length}'),
                  ],
                  const SizedBox(height: 20),
                  const Text('所有对话包:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._allDpNames.map((name) => Text('- $name')).toList(),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _createNewDp,
                    child: const Text('创建新对话包'),
                  ),
                ],
              ),
            ),
    );
  }
}