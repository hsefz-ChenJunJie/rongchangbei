import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:ai_sound_agent/services/userdata_services.dart';
import 'package:ai_sound_agent/services/dp_manager.dart';
import 'package:ai_sound_agent/widgets/chat_recording/chat_dialogue.dart';

class MainProcessingPage extends StatefulWidget {
  const MainProcessingPage({super.key});

  @override
  State<MainProcessingPage> createState() => _MainProcessingPageState();
}

class _MainProcessingPageState extends State<MainProcessingPage> {
  final GlobalKey<ChatDialogueState> _dialogueKey = GlobalKey<ChatDialogueState>();
  WebSocketChannel? _webSocketChannel;
  String? _sessionId;
  bool _isLoading = false;
  String _loadingStep = '';
  bool _isSidebarOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentDialogue();
    });
  }

  @override
  void dispose() {
    _webSocketChannel?.sink.close();
    super.dispose();
  }

  Future<void> _loadCurrentDialogue() async {
    try {
      setState(() {
        _isLoading = true;
        _loadingStep = '正在加载对话数据...';
      });

      // 第一步：正确加载历史对话
      final dpManager = DPManager();
      await dpManager.init(); // 确保初始化
      
      // 确保current.dp文件存在
      if (!await dpManager.exists('current')) {
        // 如果文件不存在，创建一个空的对话包
        final defaultDialoguePackage = DialoguePackage(
          type: 'dialogue_package',
          name: 'current',
          responseCount: 3,
          scenarioDescription: '默认对话场景',
          messages: [],
          modification: '',
          userOpinion: '',
          scenarioSupplement: '',
        );
        await dpManager.saveDp(defaultDialoguePackage);
      }

      // 使用DPManager加载current对话包
      final dialoguePackage = await dpManager.getDp('current');
      
      // 使用DPManager的toChatMessages方法转换为ChatMessage列表
      final chatMessages = dpManager.toChatMessages(dialoguePackage);
      
      // 使用ChatDialogue的addMessages方法批量添加消息
      if (chatMessages.isNotEmpty && _dialogueKey.currentState != null) {
        _dialogueKey.currentState!.addMessages(chatMessages);
      }

      setState(() {
        _loadingStep = '对话数据加载完成';
      });

      // 延迟一下让用户看到完成状态
      await Future.delayed(const Duration(milliseconds: 300));

      setState(() {
        _loadingStep = '正在加载用户配置...';
      });

      // 第二步：加载用户数据以获取用户名和base_url
      final userdata = Userdata();
      await userdata.loadUserData();
      final username = userdata.username;
      final baseUrl = userdata.preferences['base_url'] ?? 'ws://localhost:8000/conservation';

      setState(() {
        _loadingStep = '正在建立连接...';
      });

      // 第三步：建立WebSocket连接
      await _establishWebSocketConnection(
        baseUrl: baseUrl,
        username: username,
        dialoguePackage: dialoguePackage,
        historyMessages: chatMessages,
      );

      // 注意：加载状态将在收到session_created消息后才关闭
      setState(() {
        _loadingStep = '等待服务器响应...';
      });

    } catch (e) {
      debugPrint('加载current.dp或建立WebSocket连接时出错: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _establishWebSocketConnection({
    required String baseUrl,
    required String username,
    required DialoguePackage dialoguePackage,
    required List<Map<String, dynamic>> historyMessages,
  }) async {
    try {
      // 创建WebSocket连接
      _webSocketChannel = WebSocketChannel.connect(
        Uri.parse(baseUrl),
      );

      // 监听WebSocket消息
      _webSocketChannel!.stream.listen(
        (message) {
          _handleWebSocketMessage(message);
        },
        onError: (error) {
          debugPrint('WebSocket错误: $error');
        },
        onDone: () {
          debugPrint('WebSocket连接关闭');
          setState(() {
            _sessionId = null;
          });
        },
      );

      // 转换历史消息格式以匹配服务器期望的格式
      final formattedHistoryMessages = historyMessages.map((msg) => {
        'sender': msg['name'] ?? 'unknown',
        'content': msg['content'] ?? '',
        'timestamp': msg['time'] ?? '',
        'is_user': msg['is_me'] ?? false,
      }).toList();

      // 构建并发送对话启动数据包
      final startMessage = {
        'type': 'conversation_start',
        'data': {
          'username': username,
          'scenario_description': dialoguePackage.scenarioDescription,
          'response_count': dialoguePackage.responseCount.clamp(1, 5), // 确保在1-5之间
          'history_messages': formattedHistoryMessages,
        }
      };

      // 发送数据包
      _webSocketChannel!.sink.add(json.encode(startMessage));
      debugPrint('已发送对话启动数据包: ${json.encode(startMessage)}');
      
    } catch (e) {
      debugPrint('WebSocket连接错误: $e');
    }
  }

  void _handleWebSocketMessage(String message) {
    try {
      final data = json.decode(message);
      debugPrint('收到WebSocket消息: $data');
      debugPrint('消息类型: ${data['type']}');
      debugPrint('数据内容: ${data['data']}');

      if (data['type'] == 'session_created') {
        final sessionId = data['data']['session_id'] as String;
        debugPrint('提取到的session_id: $sessionId');
        setState(() {
          _sessionId = sessionId;
          _loadingStep = '会话已建立'; // 更新加载步骤
        });
        debugPrint('已设置_sessionId为: $_sessionId');
        debugPrint('UI应该刷新显示session ID');
        
        // 延迟一小段时间后隐藏加载状态
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        });
      }
      // 这里可以处理其他类型的WebSocket消息
    } catch (e) {
      debugPrint('处理WebSocket消息时出错: $e');
    }
  }

  void _clearChat() {
    _dialogueKey.currentState?.clear();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? _buildLoadingScreen()
          : Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildTopBar(),
                      Expanded(
                        child: ChatDialogue(
                          key: _dialogueKey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            _loadingStep,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: _toggleSidebar,
          ),
          const SizedBox(width: 16),
          const Text(
            '对话处理',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (_sessionId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1,
                ),
              ),
              child: Text(
                '会话: ${_sessionId!.substring(0, 5)}...',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey,
                  width: 1,
                ),
              ),
              child: const Text(
                '等待会话...',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _clearChat,
            tooltip: '清空对话',
          ),
        ],
      ),
    );
  }
}



