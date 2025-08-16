import 'package:flutter/material.dart';
import 'package:ai_sound_agent/widgets/shared/base.dart';
import 'package:ai_sound_agent/widgets/shared/base_line_input.dart';
import 'package:ai_sound_agent/widgets/shared/base_text_area.dart';
import 'package:ai_sound_agent/widgets/shared/base_elevated_button.dart';  // 新增导入
import 'package:ai_sound_agent/widgets/chat_recording/chat_dialogue.dart';
import 'package:ai_sound_agent/widgets/chat_recording/chat_input.dart';
import 'package:ai_sound_agent/widgets/chat_recording/role_selector.dart';
import 'package:ai_sound_agent/widgets/chat_recording/role_manager.dart';
import 'package:ai_sound_agent/services/dp_manager.dart';
import 'package:ai_sound_agent/services/theme_manager.dart';
import 'package:ai_sound_agent/services/userdata_services.dart';
import 'dart:convert';
import 'dart:async';  // 新增：导入Timer
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:record/record.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:ai_sound_agent/widgets/shared/save_dialogue_popup.dart';
import 'package:ai_sound_agent/widgets/shared/edit_dialogue_info_popup.dart';

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

enum LoadingStep {
  readingFile,
  settingUpPage,
  sendingStartRequest,
  receivingSessionId,
  completed,
}

class _MainProcessingPageState extends BasePageState<MainProcessingPage> {
  final GlobalKey<ChatDialogueState> _dialogueKey = GlobalKey<ChatDialogueState>();
  final GlobalKey<ChatInputState> _inputKey = GlobalKey<ChatInputState>();
  bool _isSidebarOpen = false;
  bool _isLoading = true;
  String? _sessionId;
  WebSocketChannel? _webSocketChannel;
  LoadingStep _currentStep = LoadingStep.readingFile;

  final TextEditingController _scenarioSupplementController = TextEditingController();
  final TextEditingController _userOpinionController = TextEditingController();
  final TextEditingController _modificationController = TextEditingController();
  final TextEditingController _contentInputController = TextEditingController(); // 新增：内容输入控制器

  DialoguePackage? _currentDialoguePackage;
  
  // 新增：对话标题和描述
  String _dialogueTitle = '对话记录';
  String _dialogueDescription = '';
  
  // 新增：存储建议关键词的列表
  List<String> _suggestionKeywords = ['建议1', '建议2', '建议3'];
  
  // 新增：用户意见相关状态
  String _userOpinionBackup = '';
  Timer? _userOpinionTimer;
  bool _isUserOpinionTimerActive = false;
  
  // 新增：回答生成数控制
  int _responseCount = 3; // 默认值，将从dialoguePackage读取
  
  // 新增：LLM响应相关状态
  bool _isGeneratingResponse = false;
  String _generatingMessage = '';
  List<String> _responseSuggestions = [];

  // 音频录制相关状态
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String _recordingSender = '';
  
  // 新增：音频流订阅
  StreamSubscription<List<int>>? _audioStreamSubscription;

  // TTS相关状态
  final FlutterTts _flutterTts = FlutterTts();

  final Map<LoadingStep, String> _stepDescriptions = {
    LoadingStep.readingFile: '正在读取对话文件...',
    LoadingStep.settingUpPage: '正在设置页面...',
    LoadingStep.sendingStartRequest: '正在发送开始对话请求...',
    LoadingStep.receivingSessionId: '正在接收会话ID...',
    LoadingStep.completed: '加载完成',
  };

  @override
  void initState() {
    super.initState();
    
    // 初始化TTS
    _initializeTts();
    
    // 初始化默认角色并加载current.dp
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDefaultRoles();
      _loadCurrentDialogue();
    });
  }

  // 初始化TTS
  Future<void> _initializeTts() async {
    try {
      await _flutterTts.setLanguage("zh-CN");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
    } catch (e) {
      debugPrint('初始化TTS失败: $e');
    }
  }

  Future<void> _loadCurrentDialogue() async {
    try {
      setState(() {
        _isLoading = true;
        _currentStep = LoadingStep.readingFile;
      });

      // 初始化DPManager
      final dpManager = DPManager();
      await dpManager.init();

      setState(() {
        _currentStep = LoadingStep.settingUpPage;
      });

      // 检查current.dp是否存在，如果不存在则创建
      if (!await dpManager.exists('current')) {
        await dpManager.createNewDp('current', scenarioDescription: '当前对话');
      }

      // 获取current.dp
      final dialoguePackage = await dpManager.getDp('current');
      
      // 保存对话包数据并填充侧边栏
      _currentDialoguePackage = dialoguePackage;
      
      // 加载对话标题和描述
      setState(() {
        _dialogueTitle = dialoguePackage.packageName;
        _dialogueDescription = dialoguePackage.description;
      });
      
      // 填充侧边栏输入框的值
      _scenarioSupplementController.text = dialoguePackage.scenarioSupplement;
      _userOpinionController.text = dialoguePackage.userOpinion;
      _modificationController.text = dialoguePackage.modification;
      
      // 初始化回答生成数
      setState(() {
        _responseCount = dialoguePackage.responseCount.clamp(1, 5);
      });
      
      // 记录调试信息
      debugPrint('已加载对话包数据:');
      debugPrint('场景描述: ${dialoguePackage.scenarioDescription}');
      debugPrint('情景补充: ${dialoguePackage.scenarioSupplement}');
      debugPrint('用户意见: ${dialoguePackage.userOpinion}');
      debugPrint('修改意见: ${dialoguePackage.modification}');
      
      // 转换为ChatMessage列表并添加到对话中
      final chatMessages = dpManager.toChatMessages(dialoguePackage);
      debugPrint('从DP加载的消息数量: ${chatMessages.length}');
      debugPrint('消息内容: $chatMessages');
      
      // 根据对话消息自动添加新角色
      _autoAddRolesFromMessages(chatMessages);
      
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

      setState(() {
        _currentStep = LoadingStep.sendingStartRequest;
      });

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
        _currentStep = LoadingStep.completed;
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

  Future<void> _handleWebSocketMessage(String message) async {
    try {
      final data = json.decode(message);
      debugPrint('收到WebSocket消息: $data');

      if (data['type'] == 'session_created') {
        final sessionId = data['data']['session_id'] as String;
        setState(() {
          _sessionId = sessionId;
          _currentStep = LoadingStep.receivingSessionId;
        });
        debugPrint('会话已创建，session_id: $sessionId');
        
        // 短暂延迟后标记为完成
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _currentStep = LoadingStep.completed;
            });
          }
        });
      } else if (data['type'] == 'opinion_suggestions') {
        // 处理意见建议消息
        final receivedSessionId = data['data']['session_id'] as String;
        final suggestions = List<String>.from(data['data']['suggestions'] as List);
        
        // 检查session_id是否匹配
        if (_sessionId == receivedSessionId && mounted) {
          setState(() {
            _suggestionKeywords = suggestions;
          });
          debugPrint('已更新建议关键词: $suggestions');
        }
      } else if (data['type'] == 'status_update') {
        // 处理状态更新消息
        final receivedSessionId = data['data']['session_id'] as String;
        final status = data['data']['status'] as String;
        final messageText = data['data']['message'] as String? ?? '正在处理...';
        
        if (_sessionId == receivedSessionId && mounted) {
          setState(() {
            _isGeneratingResponse = true;
            _generatingMessage = messageText;
          });
          debugPrint('状态更新: $status - $messageText');
        }
      } else if (data['type'] == 'llm_response') {
        // 处理LLM响应消息
        final receivedSessionId = data['data']['session_id'] as String;
        final suggestions = List<String>.from(data['data']['suggestions'] as List);
        final requestId = data['data']['request_id'] as String?;
        
        if (_sessionId == receivedSessionId && mounted) {
          setState(() {
            _isGeneratingResponse = false;
            _responseSuggestions = suggestions;
          });
          debugPrint('收到LLM响应: $suggestions (request_id: $requestId)');
        }
      } else if (data['type'] == 'message_recorded') {
        // 处理消息记录消息
        final receivedSessionId = data['data']['session_id'] as String;
        final messageId = data['data']['message_id'] as String;
        final content = data['data']['content'] as String;
        final sender = data['data']['sender'] as String;
        
        final userdata = Userdata();
        await userdata.loadUserData();

        if (_sessionId == receivedSessionId && mounted) {
          // 将消息添加到对话中
          if (_dialogueKey.currentState != null) {
            _dialogueKey.currentState!.addMessage(
              name: sender,
              content: content,
              isMe: sender == userdata.username, // 根据sender判断是否是用户消息
            );
            debugPrint('已添加消息到对话: sender=$sender, content=$content, message_id=$messageId');
            
            // 自动为新发送者添加角色
            _autoAddRoleFromSender(sender);
          } else {
            debugPrint('对话组件状态为null，无法添加消息');
          }
        }
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

  Future<void> _startRecording() async {
    if (_isRecording) {
      // 如果正在录音，则停止录音
      await _stopRecording();
      return;
    }

    if (_sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先建立会话连接'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    try {
      // 检查并请求录音权限
      if (!await _audioRecorder.hasPermission()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('需要麦克风权限才能录音'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // 获取发送者名称
      String sender = await _getRecordingSender();
      _recordingSender = sender;

      // 发送message_start消息
      _sendMessageStart(sender);

      // 开始录音并获取音频流
      final stream = await _audioRecorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));

      setState(() {
        _isRecording = true;
      });

      // 启动音频流监听
      _startAudioStreamListener(stream);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('开始录音...'),
          duration: Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
      debugPrint('开始录音时出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('录音失败: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      debugPrint('正在停止录音...');
      
      // 先标记为不录音，防止继续发送数据
      setState(() {
        _isRecording = false;
      });

      // 取消音频流订阅
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;

      // 停止录音
      await _audioRecorder.stop();
      
      // 发送message_end消息
      _sendMessageEnd();

      debugPrint('录音已停止');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('录音已结束'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('停止录音时出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('停止录音失败: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<String> _getRecordingSender() async {
    final roleManager = RoleManager.instance;
    final userdata = Userdata();
    await userdata.loadUserData();
    
    final currentRole = roleManager.currentRole;
    if (currentRole.name == '我自己') {
      return userdata.username;
    } else {
      return currentRole.name;
    }
  }

  void _sendMessageStart(String sender) {
    final message = {
      'type': 'message_start',
      'data': {
        'session_id': _sessionId,
        'sender': sender,
      }
    };
    
    _webSocketChannel?.sink.add(json.encode(message));
    debugPrint('已发送message_start: ${json.encode(message)}');
  }

  void _sendMessageEnd() {
    final message = {
      'type': 'message_end',
      'data': {
        'session_id': _sessionId,
      }
    };
    
    _webSocketChannel?.sink.add(json.encode(message));
    debugPrint('已发送message_end: ${json.encode(message)}');
  }

  void _startAudioStreamListener(Stream<List<int>> stream) {
    List<int> audioBuffer = [];
    const int chunkSize = 1024; // 大约1秒的16kHz单声道PCM数据
    
    // 取消之前的订阅
    _audioStreamSubscription?.cancel();
    
    _audioStreamSubscription = stream.listen((chunk) {
      if (!_isRecording) return;
      
      audioBuffer.addAll(chunk);
      
      // 当缓冲区达到指定大小时，发送音频chunk
      if (audioBuffer.length >= chunkSize) {
        _sendBufferedAudioChunk(audioBuffer);
        audioBuffer.clear();
      }
    }, onError: (error) {
      debugPrint('音频流错误: $error');
      if (_isRecording) {
        _stopRecording(); // 出错时自动停止录音
      }
    }, onDone: () {
      debugPrint('音频流结束');
      // 音频流结束，发送剩余的音频数据
      if (audioBuffer.isNotEmpty && _isRecording) {
        _sendBufferedAudioChunk(audioBuffer);
      }
      
      // 确保录音状态已更新
      if (_isRecording) {
        setState(() {
          _isRecording = false;
        });
      }
    });
  }

  void _sendBufferedAudioChunk(List<int> audioData) {
    try {
      if (!_isRecording || _sessionId == null) return;

      // 将音频数据编码为base64
      final base64Audio = base64.encode(Uint8List.fromList(audioData));
      
      final message = {
        'type': 'audio_stream',
        'data': {
          'session_id': _sessionId,
          'audio_chunk': base64Audio,
        }
      };
      
      _webSocketChannel?.sink.add(json.encode(message));
      debugPrint('已发送audio_stream chunk，大小: ${audioData.length} bytes');
    } catch (e) {
      debugPrint('发送音频chunk时出错: $e');
    }
  }

  @override
  List<Widget> buildAdditionalFloatingActionButtons() {
    return [
      // 录音按钮 - 统一使用主题主色调
      FloatingActionButton(
        heroTag: 'record_button',
        onPressed: _startRecording,
        tooltip: _isRecording ? '停止录音' : '开始录音',
        backgroundColor: _isRecording ? Colors.red : Theme.of(context).colorScheme.primary,
        child: Icon(
          _isRecording ? Icons.stop : Icons.mic,
          color: Colors.white,
        ),
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
  String get title => _dialogueTitle;

  @override
  Widget buildContent(BuildContext context) {
    if (_isLoading) {
      return Stack(
        children: [
          // 主内容（在加载时不可见）
          _buildMainLayout(),
          
          // 白色半透明遮罩
          Container(
            color: Colors.white.withValues(alpha: 0.85),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 加载动画 - 使用官方推荐的参数
                  const SizedBox(
                    width: 72,
                    height: 72,
                    child: LoadingIndicator(
                      indicatorType: Indicator.ballSpinFadeLoader,
                      colors: [Colors.blue, Colors.green, Colors.orange],
                      strokeWidth: 2.0,
                      backgroundColor: Colors.transparent,
                      pathBackgroundColor: Colors.transparent,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 步骤提示文字
                  Text(
                    _stepDescriptions[_currentStep] ?? '加载中...',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.black87,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return _buildMainLayout();
  }

  @override
  void dispose() {
    // 发送 conversation_end 消息并关闭 WebSocket 连接
    _sendConversationEndAndClose();
    
    // 清理计时器
    _stopUserOpinionTimer();
    
    // 停止录音和音频流
    if (_isRecording) {
      _audioRecorder.stop();
    }
    _audioStreamSubscription?.cancel();
    _audioRecorder.dispose();
    
    // 停止TTS
    _flutterTts.stop();
    
    // 清理控制器
    _scenarioSupplementController.dispose();
    _userOpinionController.dispose();
    _modificationController.dispose();
    _contentInputController.dispose();
    
    super.dispose();
  }

  // 发送 conversation_end 消息并关闭 WebSocket 连接
  void _sendConversationEndAndClose() {
    if (_webSocketChannel != null && _sessionId != null) {
      try {
        final message = {
          'type': 'conversation_end',
          'data': {
            'session_id': _sessionId,
          }
        };
        
        _webSocketChannel!.sink.add(json.encode(message));
        debugPrint('已发送 conversation_end 消息: ${json.encode(message)}');
      } catch (e) {
        debugPrint('发送 conversation_end 消息时出错: $e');
      }
    }
    
    // 关闭 WebSocket 连接
    _webSocketChannel?.sink.close();
    debugPrint('WebSocket 连接已关闭');
  }

  // 处理移置对话框并语音合成
  Future<void> _handleMoveToDialogAndTTS() async {
    final content = _contentInputController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入内容后再执行此操作')),
      );
      return;
    }

    try {
      // 获取当前用户名称
      final userdata = Userdata();
      await userdata.loadUserData();
      final username = userdata.username;

      // 将内容添加到对话框
      if (_dialogueKey.currentState != null) {
        _dialogueKey.currentState!.addMessage(
          name: username,
          content: content,
          isMe: true,
        );
        debugPrint('已将内容添加到对话框: $content');
      }

      // 使用TTS语音合成
      await _flutterTts.speak(content);
      debugPrint('正在语音合成: $content');

      // 清空内容输入框
      _contentInputController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('内容已移置对话框并开始语音合成'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('移置对话框并语音合成时出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $e')),
      );
    }
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
                      _dialogueTitle,
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    tooltip: '编辑对话信息',
                    onPressed: _editDialogueInfo,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.save, size: 18),
                    tooltip: '保存为对话包',
                    onPressed: _saveDialoguePackage,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
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
      child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                // 场景描述展示
                Text(
                  '场景描述',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _currentDialoguePackage?.scenarioDescription ?? '当前对话场景的描述内容',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                
                // 情景补充输入框
                BaseLineInput(
                  label: '情景补充',
                  placeholder: '请输入情景补充信息; Enter发送',
                  controller: _scenarioSupplementController,
                  onChanged: (value) {
                    // TODO: 处理情景补充输入
                  },
                  onSubmitted: (value) {
                    // 当用户按下Enter键时发送情景补充并更新场景描述
                    final trimmedValue = value.trim();
                    if (trimmedValue.isNotEmpty && _sessionId != null) {
                      // 发送WebSocket消息
                      _sendScenarioSupplement(trimmedValue);
                      
                      // 将内容添加到场景描述
                      setState(() {
                        if (_currentDialoguePackage != null) {
                          if (_currentDialoguePackage!.scenarioDescription.isEmpty) {
                            _currentDialoguePackage!.scenarioDescription = trimmedValue;
                          } else {
                            _currentDialoguePackage!.scenarioDescription += '; $trimmedValue';
                          }
                        }
                      });
                      
                      // 清空输入框
                      _scenarioSupplementController.clear();
                    }
                  },
                ),
                const SizedBox(height: 16),
                
                // 分隔符
                Divider(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  thickness: 1,
                ),
                const SizedBox(height: 16),
                
                // 用户意见输入框
                BaseLineInput(
                  label: '用户意见',
                  placeholder: '请输入您的意见',
                  controller: _userOpinionController,
                  onChanged: (value) {
                    // 当用户开始输入时启动计时器（如果尚未启动）
                    if (!_isUserOpinionTimerActive && value.isNotEmpty) {
                      _startUserOpinionTimer();
                    }
                    
                    // 如果用户清空了输入，停止计时器
                    if (value.isEmpty && _isUserOpinionTimerActive) {
                      _stopUserOpinionTimer();
                      _userOpinionBackup = '';
                    }
                  },
                  onSubmitted: (value) {
                    final trimmedValue = value.trim();
                    if (trimmedValue.isNotEmpty && trimmedValue != _userOpinionBackup) {
                      _sendManualGenerate(trimmedValue);
                      _userOpinionBackup = trimmedValue;
                    }
                    
                    // 按Enter后清空输入框
                    _userOpinionController.clear();
                    
                    // 停止计时器
                    _stopUserOpinionTimer();
                    _userOpinionBackup = '';
                  },
                ),
                const SizedBox(height: 12),
                
                // 建议意见按钮行
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSuggestionButton(_suggestionKeywords.isNotEmpty ? _suggestionKeywords[0] : '建议1'),
                    _buildSuggestionButton(_suggestionKeywords.length > 1 ? _suggestionKeywords[1] : '建议2'),
                    _buildSuggestionButton(_suggestionKeywords.length > 2 ? _suggestionKeywords[2] : '建议3'),
                  ],
                ),
                const SizedBox(height: 16),
                
                // 分隔符
                Divider(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  thickness: 1,
                ),
                const SizedBox(height: 16),
                
                // 内容输入框
                BaseTextArea(
                  label: '内容输入',
                  placeholder: '请输入内容...',
                  maxLines: null, // 允许自动扩展
                  minLines: 3,
                  controller: _contentInputController, // 添加控制器
                  onChanged: (value) {
                    // TODO: 处理大输入框内容
                  },
                ),
                const SizedBox(height: 8),
                
                // 状态提示文字
                if (_isGeneratingResponse)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _generatingMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                
                // LLM响应建议按钮
                if (_responseSuggestions.isNotEmpty)
                  Column(
                    children: [
                      ..._responseSuggestions.map((suggestion) => 
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildLLMResponseButton(suggestion),
                        )
                      ).toList(),
                      const SizedBox(height: 8),
                    ],
                  ),
                const SizedBox(height: 4),
                
                // 回答生成数控制
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '回答生成数',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 减号按钮
                          BaseElevatedButton(
                            onPressed: _responseCount > 1 
                                ? () => _sendResponseCountUpdate(_responseCount - 1)
                                : null,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            width: 32,
                            height: 28,
                            borderRadius: 4,
                            backgroundColor: Colors.transparent,
                            foregroundColor: Theme.of(context).colorScheme.onSurface,
                            label: '-',
                          ),
                          
                          // 数字显示
                          Container(
                            width: 40,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.symmetric(
                                horizontal: BorderSide(
                                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Text(
                              '$_responseCount',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          
                          // 加号按钮
                          BaseElevatedButton(
                            onPressed: _responseCount < 5 
                                ? () => _sendResponseCountUpdate(_responseCount + 1)
                                : null,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            width: 32,
                            height: 28,
                            borderRadius: 4,
                            backgroundColor: Colors.transparent,
                            foregroundColor: Theme.of(context).colorScheme.onSurface,
                            label: '+',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // 修改意见输入框
                BaseLineInput(
                  label: '修改意见',
                  placeholder: '不满意？想改改？',
                  controller: _modificationController,
                  onChanged: (value) {
                    // TODO: 处理修改意见输入
                  },
                  onSubmitted: (value) {
                    // 当用户按下Enter键时发送修改建议
                    if (value.trim().isNotEmpty) {
                      _sendUserModification(value.trim());
                    }
                  },
                ),
                const SizedBox(height: 16),
                
                // 移置对话框并语音合成按钮
                BaseElevatedButton.icon(
                  onPressed: _handleMoveToDialogAndTTS,
                  label: '移置对话框并语音合成',
                  icon: const Icon(Icons.speaker_phone, size: 16),
                  expanded: true,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ],
            ),
      ),
    );
  }

  // 建议意见按钮构建方法
  // 修改 _buildSuggestionButton 方法以使用 BaseElevatedButton
  Widget _buildSuggestionButton(String suggestionText) {
    return BaseElevatedButton(
      onPressed: () {
        // 点击建议按钮时，将建议文本添加到用户意见输入框
        if (_userOpinionController.text.isEmpty) {
          _userOpinionController.text = suggestionText;
        } else {
          _userOpinionController.text = '${_userOpinionController.text} $suggestionText';
        }
      },
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      width: 60,
      height: 28,
      borderRadius: 4,
      label: suggestionText,
    );
  }



  // 发送情景补充消息到服务器
  void _sendScenarioSupplement(String supplement) {
    if (_webSocketChannel == null || _sessionId == null) {
      debugPrint('WebSocket连接或session_id为空，无法发送情景补充');
      return;
    }

    try {
      final message = {
        'type': 'scenario_supplement',
        'data': {
          'session_id': _sessionId,
          'supplement': supplement,
        }
      };

      _webSocketChannel!.sink.add(json.encode(message));
      debugPrint('已发送情景补充: ${json.encode(message)}');
      
      // 可选：发送后清空输入框
      // _scenarioSupplementController.clear();
    } catch (e) {
      debugPrint('发送情景补充时出错: $e');
    }
  }

  // 启动用户意见计时器
  void _startUserOpinionTimer() {
    if (_isUserOpinionTimerActive) {
      _userOpinionTimer?.cancel();
    }
    
    _isUserOpinionTimerActive = true;
    _userOpinionTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkAndSendUserOpinion();
    });
  }

  // 停止用户意见计时器
  void _stopUserOpinionTimer() {
    _userOpinionTimer?.cancel();
    _isUserOpinionTimerActive = false;
  }

  // 检查用户意见变化并发送消息
  void _checkAndSendUserOpinion() {
    final currentOpinion = _userOpinionController.text.trim();
    
    if (currentOpinion.isNotEmpty && currentOpinion != _userOpinionBackup) {
      _sendManualGenerate(currentOpinion);
      _userOpinionBackup = currentOpinion;
    }
  }

  // 发送手动生成消息
  void _sendManualGenerate(String userOpinion) {
    if (_webSocketChannel == null || _sessionId == null) {
      debugPrint('WebSocket连接或session_id为空，无法发送手动生成消息');
      return;
    }

    try {
      final message = {
        'type': 'manual_generate',
        'data': {
          'session_id': _sessionId,
          'user_opinion': userOpinion,
        }
      };

      _webSocketChannel!.sink.add(json.encode(message));
      debugPrint('已发送手动生成消息: ${json.encode(message)}');
    } catch (e) {
      debugPrint('发送手动生成消息时出错: $e');
    }
  }

  // 发送回答生成数更新消息
  void _sendResponseCountUpdate(int newCount) {
    if (_webSocketChannel == null || _sessionId == null) {
      debugPrint('WebSocket连接或session_id为空，无法发送回答生成数更新');
      return;
    }

    try {
      final message = {
        'type': 'response_count_update',
        'data': {
          'session_id': _sessionId,
          'response_count': newCount,
        }
      };

      _webSocketChannel!.sink.add(json.encode(message));
      debugPrint('已发送回答生成数更新: ${json.encode(message)}');
      
      // 更新本地状态
      setState(() {
        _responseCount = newCount;
      });
    } catch (e) {
      debugPrint('发送回答生成数更新时出错: $e');
    }
  }

  // 发送用户修改建议消息
  void _sendUserModification(String modificationText) {
    if (_webSocketChannel == null || _sessionId == null) {
      debugPrint('WebSocket连接或session_id为空，无法发送用户修改建议');
      return;
    }

    try {
      final message = {
        'type': 'user_modification',
        'data': {
          'session_id': _sessionId,
          'modification': modificationText,
        }
      };

      _webSocketChannel!.sink.add(json.encode(message));
      debugPrint('已发送用户修改建议: ${json.encode(message)}');
      
      // 可选：发送后清空输入框
      _modificationController.clear();
    } catch (e) {
      debugPrint('发送用户修改建议时出错: $e');
    }
  }

  // 发送用户选择的响应消息
  Future<void> _sendUserSelectedResponse(String selectedContent) async {
    if (_webSocketChannel == null || _sessionId == null) {
      debugPrint('WebSocket连接或session_id为空，无法发送用户选择的响应');
      return;
    }

    try {
      // 获取用户名
      final userdata = Userdata();
      await userdata.loadUserData();
      final username = userdata.username;

      // 构建 user_selected_response 消息
      final message = {
        'type': 'user_selected_response',
        'data': {
          'session_id': _sessionId,
          'selected_content': selectedContent,
          'sender': username,
        }
      };

      // 发送消息
      _webSocketChannel!.sink.add(json.encode(message));
      debugPrint('已发送用户选择的响应: ${json.encode(message)}');
    } catch (e) {
      debugPrint('发送用户选择的响应时出错: $e');
    }
  }

  // 构建LLM响应建议按钮
  Widget _buildLLMResponseButton(String suggestion) {
    return BaseElevatedButton(
      onPressed: () async {
        // 点击按钮将建议添加到内容输入框
        if (_contentInputController.text.isEmpty) {
          _contentInputController.text = suggestion;
        } else {
          _contentInputController.text = '${_contentInputController.text}\n$suggestion';
        }
        
        // 通过 WebSocket 发送 user_selected_response 消息
        await _sendUserSelectedResponse(suggestion);
      },
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      expanded: true,
      borderRadius: 4,
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      label: suggestion,
    );
  }

  // 编辑对话信息
  void _editDialogueInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EditDialogueInfoPopup(
          initialTitle: _dialogueTitle,
          initialDescription: _dialogueDescription,
          onSave: (newTitle, newDescription) {
            setState(() {
              _dialogueTitle = newTitle;
              _dialogueDescription = newDescription;
            });
            
            // 保存成功后显示提示
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('对话信息已更新')),
            );
          },
        );
      },
    );
  }

  // 保存对话包
  void _saveDialoguePackage() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SaveDialoguePopup(
          onSave: (fileName) async {
            try {
              // 获取所有聊天消息
              final chatMessages = _dialogueKey.currentState?.getAllMessages() ?? [];
              
              // 获取侧边栏数据
              final scenarioDescription = _currentDialoguePackage?.scenarioDescription ?? '';
              final scenarioSupplement = _scenarioSupplementController.text;
              final userOpinion = _userOpinionController.text;
              final modification = _modificationController.text;
              final responseCount = _responseCount;
              
              // 创建新的对话包
              final dpManager = DPManager();
              await dpManager.createDpFromChatSelection(
                fileName,
                chatMessages,
                packageName: _dialogueTitle,
                description: _dialogueDescription,
                scenarioDescription: scenarioDescription,
                responseCount: responseCount,
                modification: modification,
                userOpinion: userOpinion,
                scenarioSupplement: scenarioSupplement,
              );
              
              // 显示成功消息
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('对话包保存成功')),
                );
              }
            } catch (e) {
              debugPrint('保存对话包时出错: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('保存对话包失败')),
                );
              }
            }
          },
        );
      },
    );
  }
}


// 根据对话消息自动添加新角色
void _autoAddRolesFromMessages(List<Map<String, dynamic>> messages) {
  final roleManager = RoleManager.instance;
  final themeManager = ThemeManager();
  final baseColor = themeManager.baseColor;

  // 收集所有唯一的发送者名称
  final uniqueSenders = <String>{};
  for (final message in messages) {
    final senderName = message['name']?.toString() ?? '';
    if (senderName.isNotEmpty && senderName != '未知用户' && senderName != '错误用户') {
      uniqueSenders.add(senderName);
    }
  }

  // 为每个新发送者创建角色
  for (final senderName in uniqueSenders) {
  // 检查是否已存在该角色
    final existingRole = roleManager.allRoles.any((role) => role.name == senderName);
    if (!existingRole && senderName != 'system') {

      // 根据发送者名称确定图标和颜色
      IconData icon;
      Color color = baseColor;

      // 特殊角色处理
      switch (senderName.toLowerCase()) {
        case 'system':
          icon = Icons.settings;
          color = Colors.orange;
          break;
        case 'tips':
          icon = Icons.lightbulb;
          color = Colors.yellow;
          break;
        case 'document':
          icon = Icons.description;
          color = Colors.blue;
          break;
        default:
          icon = Icons.work; // 默认使用公文包图标
      }

      // 创建新角色
      final newRole = ChatRole(
        id: senderName.toLowerCase().replaceAll(' ', '_'),
        name: senderName,
        color: color,
        icon: icon,
      );

      // 添加角色到管理器
      roleManager.addRole(newRole);
      debugPrint('已自动添加新角色: $senderName');
    }
  }
}





// 根据单个发送者自动添加角色
// 根据单个发送者自动添加角色
void _autoAddRoleFromSender(String senderName) {
  if (senderName.isEmpty || senderName == '未知用户' || senderName == '错误用户') {
    return;
  }

  final roleManager = RoleManager.instance;
  final themeManager = ThemeManager();
  final baseColor = themeManager.baseColor;

  // 检查是否已存在该角色
  final existingRole = roleManager.allRoles.any((role) => role.name == senderName);
  if (!existingRole && senderName != 'system') {
    // 根据发送者名称确定图标和颜色
    IconData icon;
    Color color = baseColor;

    // 特殊角色处理
    switch (senderName.toLowerCase()) {
      case 'system':
        icon = Icons.settings;
        color = Colors.orange;
        break;
      case 'tips':
        icon = Icons.lightbulb;
        color = Colors.yellow;
        break;
      case 'document':
        icon = Icons.description;
        color = Colors.blue;
        break;
      default:
        icon = Icons.work; // 默认使用公文包图标
    }

    // 创建新角色
    final newRole = ChatRole(
      id: senderName.toLowerCase().replaceAll(' ', '_'),
      name: senderName,
      color: color,
      icon: icon,
    );

    // 添加角色到管理器
    roleManager.addRole(newRole);
    debugPrint('已自动添加新角色: $senderName');
  }
}

