import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:ai_sound_agent/services/api_service.dart';
import 'package:path_provider/path_provider.dart';
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

  // 录音相关
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isProcessingStt = false;
  String? _recordedAudioPath;

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  // 开始/停止录音
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // 停止录音
      try {
        final path = await _audioRecorder.stop();
        if (path != null && mounted) {
          setState(() {
            _isRecording = false;
            _recordedAudioPath = path;
          });
          
          // 自动进行语音识别
          await _processSpeechRecognition();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isRecording = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('停止录音失败: $e')),
          );
        }
      }
    } else {
      // 开始录音
      try {
        // 检查并请求权限
        if (await _audioRecorder.hasPermission()) {
          final tempDir = await getTemporaryDirectory();
          final filePath = '${tempDir.path}/recorded_audio.m4a';
          
          // 使用正确的record插件API
          await _audioRecorder.start(const RecordConfig(), path: filePath);
          
          if (mounted) {
            setState(() {
              _isRecording = true;
              _recordedAudioPath = null;
            });
          }
        } else {
          throw Exception('没有录音权限');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('录音失败: $e')),
          );
        }
      }
    }
  }

  // 语音识别
  Future<void> _processSpeechRecognition() async {
    if (_recordedAudioPath == null) return;

    if (mounted) {
      setState(() {
        _isProcessingStt = true;
      });
    }

    try {
      // 读取音频文件
      final audioBytes = await _readAudioFile(_recordedAudioPath!);
      
      // 调用API进行语音识别
      final recognizedText = await ApiService.speechToText(audioBytes);
      
      if (mounted) {
        // 使用chat_input的addText方法添加到光标处
        _chatInputKey.currentState?.addText(recognizedText);
        
        setState(() {
          _isProcessingStt = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('语音识别完成')),
        );
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingStt = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('语音识别失败: $e')),
        );
      }
    }
  }

  // 读取音频文件为字节数组
  Future<List<int>> _readAudioFile(String path) async {
    final file = File(path);
    return await file.readAsBytes();
  }

  // 发送消息到MainProcessingPage
  void _sendToMainProcessing() {
    final messages = _dialogueKey.currentState?.getAllMessages() ?? [];
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
        onPressed: _toggleRecording,
        backgroundColor: _isRecording ? Colors.red : Theme.of(context).colorScheme.primary,
        child: _isRecording
            ? const Icon(Icons.stop, color: Colors.white)
            : (_isProcessingStt
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.mic, color: Colors.white)),
      ),
    ];
  }
}