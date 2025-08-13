import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../widgets/shared/base.dart';
import '../widgets/chat_recording/chat_dialogue.dart';
import '../widgets/chat_recording/chat_input.dart';
import '../widgets/shared/base_elevated_button.dart';
import 'main_processing.dart';

class ChatRecordingPage extends BasePage {
  const ChatRecordingPage({super.key})
      : super(
          title: '聊天录音',
          showBottomNav: true,
          showBreadcrumb: true,
          showSettingsFab: true,
        );

  @override
  _ChatRecordingPageState createState() => _ChatRecordingPageState();
}

class _ChatRecordingPageState extends BasePageState<ChatRecordingPage> {
  // 对话状态管理
  String _conversationTitle = '新建对话';
  final GlobalKey<ChatDialogueState> _dialogueKey = GlobalKey<ChatDialogueState>();
  final GlobalKey<ChatInputState> _chatInputKey = GlobalKey<ChatInputState>();

  // 语音识别相关
  stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;
  bool _isProcessingStt = false;
  bool _speechEnabled = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    if (_isListening) {
      _speechToText.stop();
    }
    super.dispose();
  }

  /// 初始化语音识别
  void _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onStatus: (status) {
          if (mounted) {
            setState(() {
              _isListening = _speechToText.isListening;
            });
          }
        },
        onError: (errorNotification) {
          if (mounted) {
            setState(() {
              _isListening = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('语音识别错误: ${errorNotification.errorMsg}')),
            );
          }
        },
      );
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('初始化语音识别失败: $e')),
        );
      }
    }
  }

  /// 开始/停止语音识别
  Future<void> _toggleListening() async {
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('语音识别不可用')),
      );
      return;
    }

    if (_isListening) {
      // 停止语音识别
      try {
        await _speechToText.stop();
        if (mounted) {
          setState(() {
            _isListening = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isListening = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('停止语音识别失败: $e')),
          );
        }
      }
    } else {
      // 开始语音识别
      try {
        await _speechToText.listen(
          onResult: (result) {
            if (mounted && result.finalResult) {
              // 当语音识别完成时，将结果添加到输入框
              _chatInputKey.currentState?.addText(result.recognizedWords);
            }
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          localeId: 'zh_CN',
        );
        
        if (mounted) {
          setState(() {
            _isListening = true;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('开始语音识别失败: $e')),
          );
        }
      }
    }
  }

  // 发送消息到MainProcessingPage
  void _sendToMainProcessing() {
    // 首先检查是否有选中的消息
    final selectedMessages = _dialogueKey.currentState?.getSelection() ?? [];
    List<Map<String, dynamic>> messages;
    
    if (selectedMessages.isNotEmpty) {
      messages = selectedMessages;
    } else {
      // 如果没有选中的消息，则获取全部消息
      messages = _dialogueKey.currentState?.getAllMessages() ?? [];
    }
    
    if (messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有消息可发送')),
      );
      return;
    }

    // 构建对话文本
    String conversationText = '';
    for (var message in messages) {
      final name = message['name'] as String;
      final content = message['content'] as String;
      final isMe = message['is_me'] as bool;
      conversationText += '${isMe ? '我' : name}: $content\n';
    }

    // 导航到MainProcessingPage并传递对话内容
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MainProcessingPage(),
        settings: RouteSettings(
          arguments: {'conversation': conversationText.trim()},
        ),
      ),
    );
  }

  // 更新对话标题
  void _updateConversationTitle(String title) {
    setState(() {
      _conversationTitle = title;
    });
  }

  @override
  Widget buildContent(BuildContext context) {
    return Column(
      children: [
        // 顶部信息显示区
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _conversationTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  final controller = TextEditingController(text: _conversationTitle);
                  final result = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('修改对话标题'),
                      content: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: '输入新的对话标题',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, controller.text),
                          child: const Text('确定'),
                        ),
                      ],
                    ),
                  );
                  if (result != null && result.isNotEmpty) {
                    _updateConversationTitle(result);
                  }
                },
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Builder(
                builder: (context) {
                  // 等待ChatDialogue初始化完成
                  if (_dialogueKey.currentState == null) {
                    return const SizedBox.shrink();
                  }
                  return ChatInput(
                    key: _chatInputKey,
                    dialogueState: _dialogueKey.currentState!,
                    onSend: () {
                      // 发送消息后的回调
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              BaseElevatedButton.icon(
                onPressed: _sendToMainProcessing,
                icon: const Icon(Icons.send),
                label: '发送到语音处理中心',
                expanded: true,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  List<Widget> buildAdditionalFloatingActionButtons() {
    return [
      FloatingActionButton(
        heroTag: 'chat_recording_mic',
        onPressed: _toggleListening,
        backgroundColor: _isListening ? Colors.red : Theme.of(context).colorScheme.primary,
        child: _isListening
            ? const Icon(Icons.stop, color: Colors.white)
            : (!_speechEnabled
                ? const Icon(Icons.mic_off, color: Colors.white)
                : const Icon(Icons.mic, color: Colors.white)),
      ),
    ];
  }
}