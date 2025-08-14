import 'package:flutter/material.dart';
import 'package:ai_sound_agent/widgets/shared/base.dart';
import 'package:ai_sound_agent/widgets/chat_recording/chat_dialogue.dart';
import 'package:ai_sound_agent/widgets/chat_recording/chat_input.dart';
import 'package:ai_sound_agent/widgets/chat_recording/role_selector.dart';
import 'package:ai_sound_agent/widgets/chat_recording/role_manager.dart';
import 'package:ai_sound_agent/widgets/shared/responsive_sidebar.dart';
import 'package:ai_sound_agent/services/theme_manager.dart';

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

class _MainProcessingPageState extends BasePageState<MainProcessingPage> {
  final GlobalKey<ChatDialogueState> _dialogueKey = GlobalKey<ChatDialogueState>();
  final GlobalKey<ChatInputState> _inputKey = GlobalKey<ChatInputState>();
  final GlobalKey<ResponsiveSidebarState> _sidebarKey = GlobalKey<ResponsiveSidebarState>();

  @override
  void initState() {
    super.initState();
    // 初始化默认角色
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDefaultRoles();
    });
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

  void _addSampleMessages() {
    // 示例消息功能已移除
  }

  void _toggleSidebar() {
    _sidebarKey.currentState?.toggle();
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
    return ResponsiveSidebar(
      key: _sidebarKey,
      isLeft: true, // 从左侧滑出
      child: Container(
        constraints: const BoxConstraints(maxWidth: double.infinity),
        child: _buildSidebarContent(),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: Colors.black54,
    );
  }

  Widget _buildSidebarContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          child: Column(
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
                      child: Text(
                        '对话记录',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
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
          ),
        );
      }
    );
  }

  @override
  void dispose() {
    // 清理资源
    super.dispose();
  }
}



