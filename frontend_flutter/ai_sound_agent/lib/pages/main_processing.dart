import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:ai_sound_agent/services/api_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ai_sound_agent/widgets/shared/base.dart';
import 'package:ai_sound_agent/widgets/shared/base_line_input.dart';
import 'package:ai_sound_agent/widgets/shared/base_text_area.dart';
import 'package:ai_sound_agent/widgets/shared/base_elevated_button.dart';

class MainProcessingPage extends BasePage {
  const MainProcessingPage({super.key}) : super(
    title: '语音处理中心',
    showBottomNav: true,
    showBreadcrumb: true,
    showSettingsFab: true,
  );

  @override
  _MainProcessingPageState createState() => _MainProcessingPageState();
}

class _MainProcessingPageState extends BasePageState<MainProcessingPage> {
  // 文本控制器
  final TextEditingController _sceneHintController = TextEditingController();
  final TextEditingController _userOpinionController = TextEditingController();
  final TextEditingController _conversationController = TextEditingController();
  final TextEditingController _largeTextController = TextEditingController();

  // 录音和播放
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // 状态变量
  bool _isRecording = false;
  bool _isProcessingStt = false;
  bool _isProcessingTts = false;
  bool _isGeneratingSuggestions = false;
  String? _recordedAudioPath;
  List<String> _suggestions = [];
  Timer? _suggestionTimer;

  @override
  void initState() {
    super.initState();
    
    // 检查是否有从ChatRecordingPage传递的对话内容
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map<String, dynamic>) {
        final conversation = args['conversation'] as String?;
        if (conversation != null && conversation.isNotEmpty) {
          setState(() {
            _conversationController.text = conversation;
          });
          // 立即生成建议
          _generateSuggestions();
        }
      }
    });
    
    _startSuggestionTimer();
  }

  @override
  void dispose() {
    _suggestionTimer?.cancel();
    _sceneHintController.dispose();
    _userOpinionController.dispose();
    _conversationController.dispose();
    _largeTextController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
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
          // 使用默认录音配置
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
        setState(() {
          // 追加内容而不是替换
          final currentText = _conversationController.text;
          if (currentText.isEmpty) {
            _conversationController.text = recognizedText;
          } else {
            _conversationController.text = '$currentText\n$recognizedText';
          }
          _isProcessingStt = false;
        });

        // 立即生成建议
        await _generateSuggestions();
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

  // 生成建议
  Future<void> _generateSuggestions() async {
    if (_conversationController.text.isEmpty) return;

    if (mounted) {
      setState(() {
        _isGeneratingSuggestions = true;
      });
    }

    try {
      final suggestions = await ApiService.generateSuggestion(
        scenarioContext: _sceneHintController.text,
        userOpinion: _userOpinionController.text,
        targetDialogue: _conversationController.text,
        suggestionCount: 6,
      );

      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _isGeneratingSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGeneratingSuggestions = false;
        });
      }
    }
  }

  // 语音合成
  Future<void> _processTextToSpeech() async {
    if (_largeTextController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入要合成的文本')),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isProcessingTts = true;
      });
    }

    try {
      final audioBytes = await ApiService.textToSpeech(_largeTextController.text);
      
      if (audioBytes.isNotEmpty) {
        // 保存音频文件并播放
        final tempDir = await getTemporaryDirectory();
        final audioFile = File('${tempDir.path}/tts_audio.mp3');
        await audioFile.writeAsBytes(audioBytes);
        
        await _audioPlayer.play(DeviceFileSource(audioFile.path));
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('语音合成完成并开始播放')),
          );
        }
      } else {
        throw Exception('音频数据为空');
      }

      if (mounted) {
        setState(() {
          _isProcessingTts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingTts = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('语音合成失败: $e')),
        );
      }
    }
  }

  // 读取音频文件为字节数组
  Future<List<int>> _readAudioFile(String path) async {
    final file = File(path);
    return await file.readAsBytes();
  }

  // 处理建议按钮点击
  void _onSuggestionTap(String suggestion) {
    setState(() {
      _largeTextController.text = suggestion;
    });
  }

  @override
  Widget buildContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 场景提示输入框
          BaseLineInput(
            label: '场景提示',
            placeholder: '请输入场景提示...',
            controller: _sceneHintController,
            keyboardType: TextInputType.text,
            onChanged: (value) => _generateSuggestions(),
          ),

          const SizedBox(height: 20),

          // 对话场景输入框
          BaseTextArea(
            label: '对话场景',
            placeholder: '语音识别结果将显示在这里...',
            controller: _conversationController,
            maxLines: 4,
            minLines: 2,
            enabled: true,
          ),

          const SizedBox(height: 16),

          // 用户观点输入框
          BaseLineInput(
            label: '用户观点',
            placeholder: '请输入您的观点或意见...',
            controller: _userOpinionController,
            keyboardType: TextInputType.text,
            onChanged: (value) => _generateSuggestions(),
          ),

          const SizedBox(height: 20),

          // 建议生成区域
          _buildSection(
            title: '智能建议',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isGeneratingSuggestions)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('正在生成建议...'),
                      ],
                    ),
                  ),
                if (_suggestions.isEmpty && !_isGeneratingSuggestions)
                  const Text(
                    '暂无建议，请先录音或输入内容',
                    style: TextStyle(color: Colors.grey),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestions.map((suggestion) {
                    return ActionChip(
                      label: Text(suggestion),
                      onPressed: () => _onSuggestionTap(suggestion),
                      avatar: const Icon(Icons.smart_toy, size: 16),
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 大文本输入框
          BaseTextArea(
            label: '文本内容',
            placeholder: '建议内容将显示在这里，可编辑...',
            controller: _largeTextController,
            maxLines: 6,
            minLines: 3,
          ),

          const SizedBox(height: 16),

          // 语音合成按钮
          BaseElevatedButton.icon(
            onPressed: _isProcessingTts ? null : _processTextToSpeech,
            icon: _isProcessingTts
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.volume_up),
            label: _isProcessingTts ? '合成中...' : '开始语音合成',
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            expanded: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
  
  // 定时生成建议
  void _startSuggestionTimer() {
    _suggestionTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_conversationController.text.isNotEmpty) {
        _generateSuggestions();
      }
    });
  }

  @override
  List<Widget> buildAdditionalFloatingActionButtons() {
    return [
      FloatingActionButton(
        heroTag: 'main_processing_mic',
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