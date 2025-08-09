import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:ai_sound_agent/services/api_service.dart';
import 'package:path_provider/path_provider.dart';

class MainProcessingPage extends StatefulWidget {
  const MainProcessingPage({super.key});

  @override
  State<MainProcessingPage> createState() => _MainProcessingPageState();
}

class _MainProcessingPageState extends State<MainProcessingPage> {
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
          _conversationController.text = recognizedText;
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('语音处理中心'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 场景提示输入框
            _buildSection(
              title: '场景提示',
              child: TextField(
                controller: _sceneHintController,
                decoration: const InputDecoration(
                  hintText: '请输入场景提示...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lightbulb_outline),
                ),
                maxLines: 1,
                onChanged: (value) => _generateSuggestions(),
              ),
            ),

            const SizedBox(height: 20),

            // 对话场景输入框
            _buildSection(
              title: '对话场景',
              child: TextField(
                controller: _conversationController,
                decoration: const InputDecoration(
                  hintText: '语音识别结果将显示在这里...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.chat_bubble_outline),
                ),
                maxLines: 4,
                readOnly: true,
              ),
            ),

            const SizedBox(height: 16),

            // 录音控制按钮
            ElevatedButton.icon(
              onPressed: _toggleRecording,
              icon: _isRecording
                  ? const Icon(Icons.stop)
                  : (_isProcessingStt
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.mic)),
              label: Text(_isRecording
                  ? '停止录音'
                  : (_isProcessingStt ? '识别中...' : '开始录音')),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _isRecording ? Colors.red : Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 20),

            // 用户观点输入框
            _buildSection(
              title: '用户观点',
              child: TextField(
                controller: _userOpinionController,
                decoration: const InputDecoration(
                  hintText: '请输入您的观点或意见...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                maxLines: 1,
                onChanged: (value) => _generateSuggestions(),
              ),
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
            _buildSection(
              title: '文本内容',
              child: TextField(
                controller: _largeTextController,
                decoration: const InputDecoration(
                  hintText: '建议内容将显示在这里，可编辑...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
                maxLines: 6,
              ),
            ),

            const SizedBox(height: 16),

            // 语音合成按钮
            ElevatedButton.icon(
              onPressed: _isProcessingTts ? null : _processTextToSpeech,
              icon: _isProcessingTts
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.volume_up),
              label: Text(_isProcessingTts ? '合成中...' : '开始语音合成'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
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
}