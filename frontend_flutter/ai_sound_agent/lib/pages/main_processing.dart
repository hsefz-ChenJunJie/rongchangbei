import 'package:flutter/material.dart';
import 'package:ai_sound_agent/widgets/shared/base.dart';
import 'package:ai_sound_agent/widgets/chat_recording/chat_dialogue.dart';
import 'package:ai_sound_agent/widgets/chat_recording/chat_input.dart';
import 'package:ai_sound_agent/widgets/chat_recording/role_selector.dart';
import 'package:ai_sound_agent/widgets/chat_recording/role_manager.dart';
import 'package:ai_sound_agent/services/dp_manager.dart';
import 'package:ai_sound_agent/services/userdata_services.dart';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'settings.dart';
import 'device_test_page.dart';
import 'advanced_settings.dart';

class MainProcessingPage extends BasePage {
  const MainProcessingPage({super.key})
      : super(
          title: 'AI语音助手',
          showBottomNav: true,
          showBreadcrumb: true,
          showSettingsFab: true,
        );

  @override
  _MainProcessingPageState createState() => _MainProcessingPageState();
}

// ignore: library_private_types_in_public_api
class _MainProcessingPageState extends BasePageState<MainProcessingPage> {
  final GlobalKey<ChatDialogueState> _dialogueKey = GlobalKey<ChatDialogueState>();
  final GlobalKey<ChatInputState> _inputKey = GlobalKey<ChatInputState>();
  bool _isSidebarOpen = false;
  bool _isLoading = true;
  String? _sessionId;
  WebSocketChannel? _webSocketChannel;

  @override
  void initState() {
    super.initState();
    
    // 初始化默认角色并加载current.dp
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDefaultRoles();
      _loadCurrentDialogue();
    });
  }

  Future<void> _loadCurrentDialogue() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // 初始化DPManager
      final dpManager = DPManager();
      await dpManager.init();

      // 检查current.dp是否存在，如果不存在则创建
      if (!await dpManager.exists('current')) {
        await dpManager.createNewDp('current', scenarioDescription: '当前对话');
      }

      // 获取current.dp
      final dialoguePackage = await dpManager.getDp('current');
      
      // 转换为ChatMessage列表并添加到对话中
      final chatMessages = dpManager.toChatMessages(dialoguePackage);
      debugPrint('从DP加载的消息数量: ${chatMessages.length}');
      debugPrint('消息内容: $chatMessages');
      
      if (chatMessages.isNotEmpty) {
        // 延迟添加消息，确保组件已完全加载
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_dialogueKey.currentState != null) {
            _dialogueKey.currentState!.addMessages(chatMessages);
            debugPrint('消息已添加到对话组件');
          } else {
            debugPrint('对话组件状态为null');
          }
        });
      }

      // 转换为历史消息列表（用于发送到服务器）
      final historyMessages = dpManager.toHistoryMessages(dialoguePackage);

      // 加载用户数据以获取用户名和base_url
      final userdata = Userdata();
      await userdata.loadUserData();
      final username = userdata.username;
      final baseUrl = userdata.preferences['base_url'] ?? 'ws://localhost:8000/conservation';

      // 建立持久WebSocket连接并发送对话启动数据包
      await _establishWebSocketConnection(
        baseUrl: baseUrl,
        username: username,
        dialoguePackage: dialoguePackage,
        historyMessages: historyMessages,
      );

    } catch (e) {
      debugPrint('加载current.dp或建立WebSocket连接时出错: $e');
    } finally {
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

      // 构建并发送对话启动数据包
      final startMessage = {
        'type': 'conversation_start',
        'data': {
          'username': username,
          'scenario_description': dialoguePackage.scenarioDescription,
          'response_count': dialoguePackage.responseCount.clamp(1, 5), // 确保在1-5之间
          'history_messages': historyMessages,
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

      if (data['type'] == 'session_created') {
        final sessionId = data['data']['session_id'] as String;
        setState(() {
          _sessionId = sessionId;
        });
        debugPrint('会话已创建，session_id: $sessionId');
      }
      // 这里可以处理其他类型的WebSocket消息
    } catch (e) {
      debugPrint('处理WebSocket消息时出错: $e');
    }
  }

  void _initializeDefaultRoles() {
    final roleManager = RoleManager.instance;
    
    // 添加默认角色（如果不存在）
    if (roleManager.allRoles.isEmpty) {
      roleManager.addRole(const ChatRole(
        id: 'me',
        name: '我',
        color: Colors.green,
        icon: Icons.person,
      ));
      
      roleManager.addRole(const ChatRole(
        id: 'ai',
        name: 'AI助手',
        color: Colors.blue,
        icon: Icons.smart_toy,
      ));
      
      roleManager.addRole(const ChatRole(
        id: 'system',
        name: '系统',
        color: Colors.orange,
        icon: Icons.settings,
      ));
    }
  }

  void _handleSendMessage() {
    // 消息发送后的回调，可以在这里添加额外逻辑
    // 例如：滚动到底部、触发AI响应等
  }

  void _clearChat() {
    _dialogueKey.currentState?.clear();
  }



  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
  }

  void _startRecording() {
    // TODO: 实现录音功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('录音功能开发中...'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  List<Widget> buildAdditionalFloatingActionButtons() {
    return [
      // 录音按钮 - 统一使用主题主色调
      FloatingActionButton(
        heroTag: 'record_button',
        onPressed: _startRecording,
        tooltip: '开始录音',
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.mic, color: Colors.white),
      ),
      
      // 侧边栏控制按钮 - 统一使用主题主色调
      FloatingActionButton(
        heroTag: 'sidebar_button',
        onPressed: _toggleSidebar,
        tooltip: '打开侧边栏',
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.menu, color: Colors.white),
      ),
    ];
  }

  @override
  Widget buildContent(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载对话...'),
          ],
        ),
      );
    }
    return _buildMainLayout();
  }

  @override
  void dispose() {
    _webSocketChannel?.sink.close();
    super.dispose();
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // 顶部操作栏
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '对话记录',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (_sessionId != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _sessionId!.length > 20 
                              ? '${_sessionId!.substring(0, 20)}...'
                              : _sessionId!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.clear_all, size: 18),
                tooltip: '清空对话',
                onPressed: _clearChat,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        
        // 聊天对话区域
        Expanded(
          child: ChatDialogue(
            key: _dialogueKey,
          ),
        ),
        
        // 聊天输入区域
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
          ),
          child: Builder(
            builder: (context) {
              final dialogueState = _dialogueKey.currentState;
              if (dialogueState == null) {
                return const SizedBox.shrink();
              }
              return ChatInput(
                key: _inputKey,
                dialogueState: dialogueState,
                onSend: _handleSendMessage,
              );
            }
          ),
        ),
      ],
    );
  }

  // 主布局 - 包含侧边栏和主内容
  Widget _buildMainLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        final isPortrait = screenWidth < screenHeight;
        
        if (isPortrait) {
          // 手机模式：使用覆盖式侧边栏
          return _buildMobileLayout();
        } else {
          // 平板/桌面模式：使用抽屉式侧边栏
          return _buildTabletLayout();
        }
      },
    );
  }

  // 手机模式布局
  Widget _buildMobileLayout() {
    return Stack(
      children: [
        // 主内容
        _buildMainContent(),
        
        // 侧边栏覆盖层
        if (_isSidebarOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleSidebar,
              child: Container(
                color: Colors.black54,
              ),
            ),
          ),
          
        // 侧边栏内容
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          left: _isSidebarOpen ? 0 : -MediaQuery.of(context).size.width * 0.75,
          top: 0,
          bottom: 0,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.75,
            color: Theme.of(context).colorScheme.surface,
            child: _buildSidebarMenu(),
          ),
        ),
      ],
    );
  }

  // 平板/桌面模式布局
  Widget _buildTabletLayout() {
    return Row(
      children: [
        // 侧边栏（抽屉式）
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: _isSidebarOpen ? 250 : 0,
          child: _isSidebarOpen
              ? Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: _buildSidebarMenu(),
                )
              : const SizedBox.shrink(),
        ),
          
        // 主内容区域
        Expanded(
          child: _buildMainContent(),
        ),
      ],
    );
  }

  // 侧边栏菜单内容
  Widget _buildSidebarMenu() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40), // 顶部间距
          Text(
            '功能菜单',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('设置'),
            onTap: () {
              _toggleSidebar();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Settings()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.devices),
            title: const Text('设备测试'),
            onTap: () {
              _toggleSidebar();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DeviceTestPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('高级设置'),
            onTap: () {
              _toggleSidebar();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdvancedSettingsPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  
}


