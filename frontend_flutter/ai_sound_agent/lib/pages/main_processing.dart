import 'package:flutter/material.dart';
import 'package:idialogue/widgets/shared/base.dart';
import 'package:idialogue/widgets/shared/base_line_input.dart';
import 'package:idialogue/widgets/shared/base_text_area.dart';
import 'package:idialogue/widgets/shared/base_elevated_button.dart';  // 新增导入
import 'package:idialogue/widgets/chat_recording/chat_dialogue.dart';
import 'package:idialogue/widgets/chat_recording/chat_input.dart';
import 'package:idialogue/widgets/chat_recording/role_selector.dart';
import 'package:idialogue/widgets/chat_recording/role_manager.dart';
import 'package:idialogue/widgets/chat_recording/ai_generation_panel.dart';  // 新增导入AI生成面板
import 'package:idialogue/services/dp_manager.dart';
import 'package:idialogue/services/theme_manager.dart';
import 'package:idialogue/services/userdata_services.dart';
import 'package:idialogue/models/partner_profile.dart';  // 新增导入
import 'package:idialogue/services/profile_manager.dart';  // 新增导入
import 'package:idialogue/pages/partner_profile_detail_page.dart';  // 新增导入
import 'dart:convert';
import 'dart:async';  // 新增：导入Timer
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:record/record.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:idialogue/widgets/shared/save_dialogue_popup.dart';
import 'package:idialogue/widgets/shared/edit_dialogue_info_popup.dart';

class MainProcessingPage extends BasePage {
  final String? dpfile;
  final PartnerProfile? partnerProfile;  // 新增：对话人档案
  
  const MainProcessingPage({super.key, this.dpfile, this.partnerProfile})
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
  bool _isLoading = true;
  String? _sessionId;
  WebSocketChannel? _webSocketChannel;
  LoadingStep _currentStep = LoadingStep.readingFile;

  DialoguePackage? _currentDialoguePackage;
  
  // 新增：对话标题和描述
  String _dialogueTitle = '对话记录';
  String _dialogueDescription = '';
  
  // 新增：存储建议关键词的列表
  List<String> _suggestionKeywords = ['建议1', '建议2', '建议3'];
  

  
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

  // 新增：角色队列
  List<String> _roleQueue = [];

  // 新增：重连相关状态
  int _reconnectAttempts = 0;
  bool _isReconnecting = false;
  Timer? _reconnectTimer;
  static const int maxReconnectAttempts = 5;
  static const Duration baseReconnectDelay = Duration(seconds: 1);

  // 对话人档案相关状态
  PartnerProfile? _currentPartnerProfile;

  // AI生成面板相关状态
  bool _isAIPanelVisible = false;

  // 侧边栏输入控制器
  final TextEditingController _scenarioSupplementController = TextEditingController();
  final TextEditingController _userOpinionController = TextEditingController();
  final TextEditingController _modificationController = TextEditingController();
  final TextEditingController _contentInputController = TextEditingController();

  // 用户意见备份和计时器
  String _userOpinionBackup = '';
  Timer? _userOpinionTimer;
  bool _isUserOpinionTimerActive = false;

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
    
    // 设置对话人档案
    _currentPartnerProfile = widget.partnerProfile;
    
    // 初始化默认角色并加载current.dp
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDefaultRoles();
      _loadCurrentDialogue();
      _startUserOpinionTimer(); // 启动用户意见计时器
    });
  }

  // 处理断线重连
  Future<void> _handleDisconnectionAndReconnect() async {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      debugPrint('已达到最大重连次数，停止重连');
      if (mounted) {
        setState(() {
          _sessionId = null;
          _isReconnecting = false;
        });
      }
      return;
    }

    // 保存当前进度到current.dp
    await _saveCurrentProgress();

    // 开始重连
    if (mounted) {
      setState(() {
        _isReconnecting = true;
        _reconnectAttempts++;
      });
    }

    final delay = baseReconnectDelay * (1 << (_reconnectAttempts - 1)); // 指数退避
    debugPrint('WebSocket连接断开，${delay.inSeconds}秒后尝试第$_reconnectAttempts次重连');

    _reconnectTimer = Timer(delay, () async {
      await _attemptReconnect();
    });
  }

  // 保存当前进度到current.dp
  Future<void> _saveCurrentProgress() async {
    try {
      if (_currentDialoguePackage == null) return;

      final dpManager = DPManager();
      await dpManager.init();

      // 确定要保存的dp文件名
      String targetDpFile = 'current';
      if (widget.dpfile != null && widget.dpfile!.isNotEmpty) {
        if (await dpManager.exists(widget.dpfile!)) {
          targetDpFile = widget.dpfile!;
        }
      }

      // 获取当前对话消息
      final currentMessages = _dialogueKey.currentState?.getAllMessages() ?? [];
      
      // 保存到DP
      await dpManager.createDpFromChatSelection(
        targetDpFile,
        currentMessages, 
        packageName: _dialogueTitle,
        description: _dialogueDescription,
        scenarioDescription: _scenarioSupplementController.text,
        responseCount: _responseCount,
        modification: _modificationController.text,
        userOpinion: _inputKey.currentState?.getUserOpinion() ?? '', // 从ChatInput组件获取用户意见
        override: true,
      );
      debugPrint('当前进度已保存到$targetDpFile.dp');
    } catch (e) {
      debugPrint('保存当前进度时出错: $e');
    }
  }

  // 尝试重新连接 - 使用原session_id恢复会话
  Future<void> _attemptReconnect() async {
    try {
      final userdata = Userdata();
      await userdata.loadUserData();
      final baseUrl = userdata.preferences['base_url'] ?? 'ws://localhost:8000/conservation';

      if (_sessionId == null) {
        debugPrint('没有可用的session_id，无法进行会话恢复，创建新会话');
        // 如果没有session_id，回退到创建新会话
        final currentMessages = _dialogueKey.currentState?.getAllMessages() ?? [];
        if (_currentDialoguePackage != null) {
          await _establishWebSocketConnection(
            baseUrl: baseUrl,
            username: userdata.username,
            dialoguePackage: _currentDialoguePackage!,
            historyMessages: currentMessages,
          );
        }
      } else {
        // 使用原session_id恢复会话
        await _resumeWebSocketSession(
          baseUrl: baseUrl,
          sessionId: _sessionId!,
        );
      }
      
      debugPrint('WebSocket重连成功');
      if (mounted) {
        setState(() {
          _isReconnecting = false;
          _reconnectAttempts = 0;
        });
      }
    } catch (e) {
      debugPrint('WebSocket重连失败: $e');
      if (mounted) {
        // 重连失败，继续下一次重连尝试
        _handleDisconnectionAndReconnect();
      }
    }
  }

  // 恢复WebSocket会话 - 使用原session_id
  Future<void> _resumeWebSocketSession({
    required String baseUrl,
    required String sessionId,
  }) async {
    try {
      // 创建WebSocket连接
      _webSocketChannel = WebSocketChannel.connect(
        Uri.parse(baseUrl),
      );

      // 添加连接超时处理
      await _webSocketChannel!.ready.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('WebSocket会话恢复连接超时');
          throw TimeoutException('WebSocket会话恢复连接超时');
        },
      );

      // 监听WebSocket消息
      _webSocketChannel!.stream.listen(
        (message) {
          _handleWebSocketMessage(message);
        },
        onError: (error) {
          debugPrint('WebSocket会话恢复错误: $error');
          if (mounted && !_isReconnecting) {
            // 会话恢复失败，触发重连
            _handleDisconnectionAndReconnect();
          }
        },
        onDone: () {
          debugPrint('WebSocket会话恢复连接关闭');
          if (mounted && !_isReconnecting) {
            // 会话恢复连接断开，触发重连
            _handleDisconnectionAndReconnect();
          }
        },
      );

      // 发送会话恢复消息
      final resumeMessage = {
        'type': 'session_resume',
        'data': {
          'session_id': sessionId,
        }
      };

      // 发送数据包
      _webSocketChannel!.sink.add(json.encode(resumeMessage));
      debugPrint('已发送会话恢复消息: ${json.encode(resumeMessage)}');
      
      // 显示恢复中状态
      if (mounted) {
        setState(() {
          _isLoading = true;
          _currentStep = LoadingStep.sendingStartRequest;
        });
      }
      
    } catch (e) {
      debugPrint('WebSocket会话恢复失败: $e');
      rethrow;
    }
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
      if (mounted) {
        setState(() {
          _isLoading = true;
          _currentStep = LoadingStep.readingFile;
        });
      }

      // 初始化DPManager
      final dpManager = DPManager();
      await dpManager.init();

      // 确定要使用的dp文件名
      String targetDpFile = 'current';
      if (widget.dpfile != null && widget.dpfile!.isNotEmpty) {
        // 检查指定的文件是否存在
        if (await dpManager.exists(widget.dpfile!)) {
          targetDpFile = widget.dpfile!;
          debugPrint('使用指定的dp文件: $targetDpFile');
        } else {
          debugPrint('指定的dp文件不存在，使用默认的current.dp');
        }
      }

      if (mounted) {
        setState(() {
          _currentStep = LoadingStep.settingUpPage;
        });
      }

      // 检查目标dp文件是否存在，如果不存在则创建（仅当是current.dp时）
      if (targetDpFile == 'current' && !await dpManager.exists('current')) {
        await dpManager.createNewDp('current', scenarioDescription: '当前对话');
      }

      // 获取目标dp文件
      final dialoguePackage = await dpManager.getDp(targetDpFile);
      
      // 保存对话包数据并填充侧边栏
      _currentDialoguePackage = dialoguePackage;
      
      // 加载对话标题和描述
      if (mounted) {
        setState(() {
          _dialogueTitle = dialoguePackage.packageName;
          _dialogueDescription = dialoguePackage.description;
        });
      }
      

      
      // 初始化回答生成数
      if (mounted) {
        setState(() {
          _responseCount = dialoguePackage.responseCount.clamp(1, 5);
        });
      }
      
      // 记录调试信息
      debugPrint('已加载对话包数据:');
      debugPrint('场景描述: ${dialoguePackage.scenarioDescription}');
      debugPrint('情景补充: ${dialoguePackage.scenarioSupplement}');
      debugPrint('用户意见: ${dialoguePackage.userOpinion}');
      debugPrint('修改意见: ${dialoguePackage.modification}');
      
      // 将用户意见设置到输入组件中
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_inputKey.currentState != null) {
          _inputKey.currentState!.setUserOpinion(dialoguePackage.userOpinion);
        }
      });
      
      // 转换为ChatMessage列表并添加到对话中，但不指定message_id
      List<Map<String, dynamic>> chatMessages = dpManager.toChatMessages(dialoguePackage);
      debugPrint('从DP加载的消息数量: ${chatMessages.length}');
      debugPrint('消息内容: $chatMessages');
      
      // 根据对话消息自动添加新角色
      _autoAddRolesFromMessages(chatMessages);
      
      // 将消息添加到对话组件（仅用于显示，不用于发送）
      if (chatMessages.isNotEmpty) {
        final completer = Completer<void>();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_dialogueKey.currentState != null) {
            _dialogueKey.currentState!.addMessages(chatMessages);
            debugPrint('消息已添加到对话组件');
            chatMessages = _dialogueKey.currentState!.getAllMessages();
            debugPrint('已经重新读取消息: $chatMessages');
          } else {
            debugPrint('对话组件状态为null');
          }
          completer.complete();
        });
        await completer.future; // 等待消息处理完成
      }

      // 加载用户数据以获取用户名和base_url
      final userdata = Userdata();
      await userdata.loadUserData();
      final username = userdata.username;
      final baseUrl = userdata.preferences['base_url'] ?? 'ws://localhost:8000/conservation';

      if (mounted) {
        setState(() {
          _currentStep = LoadingStep.sendingStartRequest;
        });
      }

      // 建立WebSocket连接并直接发送包含历史消息的启动包
      await _establishWebSocketConnection(
        baseUrl: baseUrl,
        username: username,
        dialoguePackage: dialoguePackage,
        historyMessages: chatMessages,
      );

    } catch (e) {
      debugPrint('加载current.dp或建立WebSocket连接时出错: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStep = LoadingStep.completed;
        });
      }
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

      // 添加连接超时处理
      await _webSocketChannel!.ready.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('WebSocket连接超时');
          throw TimeoutException('WebSocket连接超时');
        },
      );

      // 监听WebSocket消息
      _webSocketChannel!.stream.listen(
        (message) {
          _handleWebSocketMessage(message);
        },
        onError: (error) {
          debugPrint('WebSocket错误: $error');
          if (mounted) {
            if (_isLoading) {
              setState(() {
                _isLoading = false;
                _currentStep = LoadingStep.completed;
              });
            } else if (!_isReconnecting && _sessionId != null) {
              // 中途连接错误，触发重连
              _handleDisconnectionAndReconnect();
            }
          }
        },
        onDone: () {
          debugPrint('WebSocket连接关闭');
          if (mounted) {
            // 如果是正常加载过程中，不触发重连
            if (_isLoading) {
              setState(() {
                _isLoading = false;
                _currentStep = LoadingStep.completed;
              });
            } else if (!_isReconnecting && _sessionId != null) {
              // 中途断开连接，触发重连
              _handleDisconnectionAndReconnect();
            }
          }
        },
      );

      // 转换历史消息格式为符合websocket要求的格式
      final formattedHistoryMessages = historyMessages.map((msg) {
        return {
          'message_id': msg['message_id']?.toString() ?? '',
          'sender': msg['name']?.toString() ?? '',
          'content': msg['content']?.toString() ?? '',
        };
      }).toList();

      // 构建场景描述，如果存在当前聊天对象则附加其信息
      String enhancedScenarioDescription = dialoguePackage.scenarioDescription;
      if (_currentPartnerProfile != null) {
        final partnerInfo = _buildPartnerInfoString();
        enhancedScenarioDescription = '${dialoguePackage.scenarioDescription}\n\n你现在的聊天对象：$partnerInfo';
      }

      // 构建并发送对话启动数据包（包含历史消息）
      final startMessage = {
        'type': 'conversation_start',
        'data': {
          'username': username,
          'scenario_description': enhancedScenarioDescription,
          'response_count': dialoguePackage.responseCount.clamp(1, 5), // 确保在1-5之间
          'history_messages': formattedHistoryMessages,
        }
      };

      // 发送数据包
      _webSocketChannel!.sink.add(json.encode(startMessage));
      debugPrint('已发送对话启动数据包: ${json.encode(startMessage)}');
      
    } catch (e) {
      debugPrint('WebSocket连接错误: $e');
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _currentStep = LoadingStep.completed;
        });
      }
    }
  }

  Future<void> _handleWebSocketMessage(String message) async {
    try {
      final data = json.decode(message);
      debugPrint('收到WebSocket消息: $data');

      if (data['type'] == 'session_created') {
        final sessionId = data['data']['session_id'] as String;
        if (mounted) {
          setState(() {
            _sessionId = sessionId;
            _currentStep = LoadingStep.receivingSessionId;
          });
        }
        debugPrint('会话已创建，session_id: $sessionId');
        
        // 收到session_created消息后才标记为完成
        if (mounted) {
          setState(() {
            _currentStep = LoadingStep.completed;
            _isLoading = false;
          });
        }
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
      } else if (data['type'] == 'opinion_prediction_response') {
        // 处理意见预测响应消息
        final receivedSessionId = data['data']['session_id'] as String;
        final prediction = data['data']['prediction'] as Map<String, dynamic>;
        final requestId = data['data']['request_id'] as String?;
        
        // 检查session_id是否匹配
        if (_sessionId == receivedSessionId && mounted) {
          // 从预测数据中提取建议关键词
          final tendency = prediction['tendency'] as String? ?? '';
          final mood = prediction['mood'] as String? ?? '';
          final tone = prediction['tone'] as String? ?? '';
          
          // 构建建议列表（基于预测结果）
          final List<String> suggestions = [];
          if (tendency.isNotEmpty) suggestions.add('倾向:$tendency');
          if (mood.isNotEmpty) suggestions.add('心情:$mood');
          if (tone.isNotEmpty) suggestions.add('语气:$tone');
          
          // 如果没有有效的预测数据，使用默认建议
          if (suggestions.isEmpty) {
            suggestions.addAll(['建议1', '建议2', '建议3']);
          }
          
          setState(() {
            _suggestionKeywords = suggestions;
          });
          debugPrint('已根据意见预测更新建议关键词: $suggestions (request_id: $requestId)');
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
        final content = data['data']['message_content'] as String;

        String? sender = data['data']['sender'];

        if (sender == null) {
          debugPrint('收到消息但.sender为空');
          sender = _roleQueue[0];
          _roleQueue.removeAt(0);
        }


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
      } else if (data['type'] == 'session_restored') {
        // 处理会话恢复消息
        final receivedSessionId = data['data']['session_id'] as String;
        final status = data['data']['status'] as String;
        final messageCount = data['data']['message_count'] as int;
        final responseCount = data['data']['response_count'] as int;
        final hasModifications = data['data']['has_modifications'] as bool;
        final restoredAt = data['data']['restored_at'] as String;
        final scenarioDescription = data['data']['scenario_description'] as String?;
        
        if (_sessionId == receivedSessionId && mounted) {
          setState(() {
            _responseCount = responseCount;
            _isLoading = false;
            _currentStep = LoadingStep.completed;
          });
          
          debugPrint('会话恢复成功: $status, 消息数: $messageCount, 恢复时间: $restoredAt');
          
          // 显示恢复成功的提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('会话恢复成功，共 $messageCount 条消息'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else if (data['type'] == 'error') {
        // 处理错误消息
        final errorCode = data['data']['error_code'] as String;
        final errorMessage = data['data']['message'] as String;
        final details = data['data']['details'] as String?;
        final sessionId = data['data']['session_id'] as String?;
        
        debugPrint('收到错误消息: $errorCode - $errorMessage');
        if (details != null) {
          debugPrint('错误详情: $details');
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('错误: $errorMessage'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      // 这里可以处理其他类型的WebSocket消息
    } catch (e) {
      debugPrint('处理WebSocket消息时出错: $e');
    }
  }

  /// 构建聊天对象的详细信息字符串
  String _buildPartnerInfoString() {
    if (_currentPartnerProfile == null) return '';
    
    final profile = _currentPartnerProfile!;
    final parts = <String>[];
    
    // 基本信息
    parts.add('姓名：${profile.name}');
    parts.add('关系：${profile.fullRelationship}');
    
    // 年龄性别信息
    if (profile.ageGenderDisplay.isNotEmpty) {
      parts.add(profile.ageGenderDisplay);
    }
    
    // 性格标签
    if (profile.personalityTags.isNotEmpty) {
      parts.add('性格特点：${profile.personalityTags.join('、')}');
    }
    
    // 禁忌话题
    if (profile.tabooTopics != null && profile.tabooTopics!.isNotEmpty) {
      parts.add('禁忌话题：${profile.tabooTopics}');
    }
    
    // 共同经历
    if (profile.sharedExperiences != null && profile.sharedExperiences!.isNotEmpty) {
      parts.add('共同经历：${profile.sharedExperiences}');
    }
    
    return parts.join('\n');
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
    
    // 有一定概率添加"我想想……"填充消息
    _maybeAddThinkingMessage();
  }
  
  // 随机添加"我想想……"填充消息
  void _maybeAddThinkingMessage() {
    // 30%的概率触发
    if (_shouldShowThinkingMessage()) {
      // 延迟1-3秒后添加填充消息，模拟思考时间
      final delay = Duration(milliseconds: 1000 + (DateTime.now().millisecond % 2000));
      
      Future.delayed(delay, () {
        if (mounted && _sessionId != null) {
          // 添加"我想想……"消息到对话中
          if (_dialogueKey.currentState != null) {
            _dialogueKey.currentState!.addMessage(
              name: 'system',
              content: '我想想……',
              isMe: false,
            );
            debugPrint('已添加"我想想……"填充消息');
          }
        }
      });
    }
  }
  
  // 决定是否显示思考消息（30%概率）
  bool _shouldShowThinkingMessage() {
    return DateTime.now().millisecond % 100 < 30; // 30%概率
  }

  void _clearChat() {
    _dialogueKey.currentState?.clear();
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
      _roleQueue.add(sender);


      // 发送message_start消息
      _sendMessageStart(sender);

      // 开始录音并获取音频流
      // 注意：流模式不支持opus编码，使用pcm编码
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
    const int chunkSize = 32000; // PCM16编码数据，16000Hz采样率，单声道，大约1秒的音频（32000字节/秒）
    int totalBytes = 0;
    int chunkCount = 0;
    
    // 取消之前的订阅
    _audioStreamSubscription?.cancel();
    
    debugPrint('开始音频流监听，分块大小: $chunkSize bytes');
    
    _audioStreamSubscription = stream.listen((chunk) {
      if (!_isRecording) return;
      
      audioBuffer.addAll(chunk);
      totalBytes += chunk.length;
      
      debugPrint('接收到音频数据块，大小: ${chunk.length} bytes，缓冲区: ${audioBuffer.length} bytes');
      
      // 当缓冲区达到指定大小时，发送音频chunk
      if (audioBuffer.length >= chunkSize) {
        chunkCount++;
        debugPrint('发送第$chunkCount个音频分块，大小: ${audioBuffer.length} bytes');
        _sendBufferedAudioChunk(audioBuffer);
        audioBuffer.clear();
      }
    }, onError: (error) {
      debugPrint('音频流错误: $error，总接收字节: $totalBytes');
      if (_isRecording) {
        _stopRecording(); // 出错时自动停止录音
      }
    }, onDone: () {
      debugPrint('音频流结束，总接收字节: $totalBytes');
      // 音频流结束，发送剩余的音频数据
      if (audioBuffer.isNotEmpty && _isRecording) {
        chunkCount++;
        debugPrint('发送最后音频分块，大小: ${audioBuffer.length} bytes');
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
      
      // 计算音频时长（基于16kHz采样率，单声道，PCM16编码）
      // PCM16: 16位 = 2字节，16000Hz采样率，单声道
      // 时长 = 字节数 / (2字节/样本 * 16000样本/秒 * 1声道)
      double duration = audioData.length / 32000.0; // 估算时长
      
      final message = {
        'type': 'audio_stream',
        'data': {
          'session_id': _sessionId,
          'audio_chunk': base64Audio,
          'duration': duration, // 添加音频时长信息
          'format': 'pcm16', // 音频格式改为pcm16
          'sample_rate': 16000, // 添加采样率信息
          'channels': 1, // 添加声道信息
        }
      };
      
      _webSocketChannel?.sink.add(json.encode(message));
      debugPrint('已发送audio_stream chunk，大小: ${audioData.length} bytes，时长: ${duration.toStringAsFixed(2)}秒');
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
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                          _sessionId!.length > 5 
                              ? '${_sessionId!.substring(0, 5)}...'
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
                dialogueState: _dialogueKey.currentState!,
                onSend: _handleSendMessage,
                onPlusButtonPressed: () {
                  // 切换AI生成面板的显示状态
                  setState(() {
                    _isAIPanelVisible = !_isAIPanelVisible;
                  });
                },
                onAppendText: (text) {
                  // 处理追加文本的回调
                  if (_inputKey.currentState != null) {
                    _inputKey.currentState!.addText(text);
                  }
                },
              );
            }
          ),
        ),
        
        // AI生成面板
        if (_isAIPanelVisible)
          SizedBox(
            height: 300, // Limit the height of the AI panel
            child: AIGenerationPanel(
              isVisible: _isAIPanelVisible,
              onSuggestionSelected: (text) {
                // 将AI生成的文本追加到输入框
                if (_inputKey.currentState != null) {
                  _inputKey.currentState!.addText(text);
                }
              },
              onClose: () {
                // 关闭AI生成面板
                setState(() {
                  _isAIPanelVisible = false;
                });
              },
            ),
          ),
      ],
    );
  }

  // 主布局 - 简化版，移除侧边栏
  Widget _buildMainLayout() {
    return _buildMainContent();
  }

  // 建议意见按钮构建方法
  // 修改 _buildSuggestionButton 方法以使用 BaseElevatedButton
  Widget _buildSuggestionButton(String suggestionText) {
    return BaseElevatedButton(
      onPressed: () {
        // 点击建议按钮时，将建议文本添加到用户意见输入框
        if (_inputKey.currentState != null) {
          _inputKey.currentState!.appendUserOpinion(suggestionText);
        }
      },
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      height: 28,
      borderRadius: 4,
      label: suggestionText,
      expanded: true, // 让按钮自动扩展填充可用空间
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
    final currentOpinion = _inputKey.currentState?.getUserOpinion().trim() ?? '';
    
    if (currentOpinion.isNotEmpty && currentOpinion != _userOpinionBackup && mounted) {
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
          'focused_message_ids': [], // 可选：用户选择聚焦的消息ID数组
          'user_corpus': '', // 可选：用户提供的语料库文本
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
      if (mounted) {
        setState(() {
          _responseCount = newCount;
        });
      }
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
            if (mounted) {
              setState(() {
                _dialogueTitle = newTitle;
                _dialogueDescription = newDescription;
              });
            }
            
            // 保存成功后显示提示
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('对话信息已更新')),
              );
            }
          },
        );
      },
    );
  }

  // 保存对话包
  void _saveDialoguePackage() {
    // 确定要保存的文件名
    String targetFileName = 'current';
    if (widget.dpfile != null && widget.dpfile!.isNotEmpty) {
      targetFileName = widget.dpfile!;
    }

    // 如果有指定文件，直接保存，不弹出对话框
    if (widget.dpfile != null && widget.dpfile!.isNotEmpty) {
      _saveToFile(targetFileName);
    } else {
      // 未指定文件，弹出文件名输入框
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return SaveDialoguePopup(
            onSave: (fileName) async {
              await _saveToFile(fileName);
            },
          );
        },
      );
    }
  }

  Future<void> _saveToFile(String fileName) async {
    try {
      // 获取所有聊天消息
      final chatMessages = _dialogueKey.currentState?.getAllMessages() ?? [];
      
      // 获取相关数据
      final scenarioDescription = _currentDialoguePackage?.scenarioDescription ?? '';
      // 从ChatInput组件获取用户意见
      final userOpinion = _inputKey.currentState?.getUserOpinion() ?? '';
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
        userOpinion: userOpinion,
        override: true,
      );
      
      // 显示成功消息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('对话包保存成功: $fileName.dp')),
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









