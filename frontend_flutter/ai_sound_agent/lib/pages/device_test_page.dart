import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../widgets/shared/base.dart';
import '../widgets/shared/base_elevated_button.dart';
import '../widgets/shared/tabs.dart';

class DeviceTestPage extends BasePage {
  const DeviceTestPage({super.key})
      : super(
          title: '设备功能测试',
          showBottomNav: false,
          showBreadcrumb: true,
          showSettingsFab: false,
        );

  @override
  DeviceTestPageState createState() => DeviceTestPageState();
}

class DeviceTestPageState extends BasePageState<DeviceTestPage> {
  // 网络测试相关
  bool _isTestingNetwork = false;
  String _networkStatus = '未测试';
  double _networkSpeed = 0.0;
  
  // 麦克风测试相关
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _hasRecordedAudio = false;
  String _recordingStatus = '未测试';
  String? _recordedFilePath;
  
  // 扬声器测试相关
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String _speakerStatus = '未测试';
  
  // TTS测试相关
  late FlutterTts _flutterTts;
  String _ttsStatus = '未测试';
  bool _isSpeaking = false;
  String? _ttsText;
  double _ttsVolume = 0.5;
  double _ttsPitch = 1.0;
  double _ttsRate = 0.5;
  List<dynamic> _availableLanguages = [];
  String? _selectedLanguage;
  
  // 测试进度
  int _currentTestStep = 0;
  bool _testCompleted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _initTts();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    // 检查麦克风权限
    bool hasPermission = await _audioRecorder.hasPermission();
    setState(() {
      _recordingStatus = hasPermission ? '未测试' : '需要权限';
    });
  }





  @override
  Widget buildContent(BuildContext context) {
    final tabs = [
      TabConfig(
        label: '网络测试',
        icon: Icons.wifi,
        content: _buildNetworkTestTab(),
      ),
      TabConfig(
        label: '麦克风测试',
        icon: Icons.mic,
        content: _buildMicrophoneTestTab(),
      ),
      TabConfig(
        label: '扬声器测试',
        icon: Icons.volume_up,
        content: _buildSpeakerTestTab(),
      ),
      TabConfig(
        label: '测试总结',
        icon: Icons.assessment,
        content: _buildTestSummaryTab(),
      ),
    ];

    return Column(
      children: [
        _buildTestProgress(),
        Expanded(
          child: LightweightCardTabs(
            tabs: tabs,
            onTabChanged: (index) {
              // Tab切换时的逻辑可以在这里添加
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTestProgress() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                '测试进度',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _testCompleted ? 1.0 : _currentTestStep / 3,
                  backgroundColor: Colors.grey[300],
                  minHeight: 8,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _testCompleted ? '测试完成' : '步骤 $_currentTestStep/3',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkTestTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wifi,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '网络连接测试',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '检测网络连接状态和速度',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '连接状态',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      _buildStatusIcon(_networkStatus),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '状态: $_networkStatus',
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (_networkSpeed > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '下载速度: ${_networkSpeed.toStringAsFixed(2)} Mbps',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: BaseElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isTestingNetwork ? null : _testNetworkConnection,
                      icon: _isTestingNetwork
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.network_check, size: 20),
                      label: '开始网络测试',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicrophoneTestTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mic,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '麦克风测试',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '测试麦克风录音功能',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '录音状态',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      _buildStatusIcon(_recordingStatus),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '状态: $_recordingStatus',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: BaseElevatedButton.icon(
                          onPressed: _isRecording ? _stopRecording : _startRecording,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isRecording ? Colors.orange : Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: Icon(_isRecording ? Icons.stop : Icons.mic, size: 20),
                          label: _isRecording ? '停止录音' : '开始录音',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: BaseElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _resetAllTests,
                          icon: const Icon(Icons.refresh),
                          label: '重新测试',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSpeakerTestTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.volume_up,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '扬声器与TTS测试',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '测试音频播放和文字转语音功能',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // 音频播放测试
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '音频播放状态',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      _buildStatusIcon(_speakerStatus),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '状态: $_speakerStatus',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: BaseElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: (_hasRecordedAudio || _recordingStatus == '正常') && !_isPlaying
                          ? _playTestAudio
                          : null,
                      icon: _isPlaying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow, size: 20),
                      label: _hasRecordedAudio ? '播放录音' : '播放测试音频',
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // TTS测试
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'TTS状态',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      _buildStatusIcon(_ttsStatus),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '状态: $_ttsStatus',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  
                  // 语言选择
                  if (_availableLanguages.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('选择语言:'),
                        const SizedBox(height: 8),
                        DropdownButton<String>(
                          value: _selectedLanguage,
                          items: _availableLanguages.map<DropdownMenuItem<String>>((language) {
                            return DropdownMenuItem<String>(
                              value: language,
                              child: Text(language),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedLanguage = newValue;
                            });
                          },
                          isExpanded: true,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  
                  // 文本输入
                  const Text('测试文本:'),
                  const SizedBox(height: 8),
                  TextField(
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: '输入要朗读的文本...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _onTtsTextChanged,
                  ),
                  const SizedBox(height: 16),
                  
                  // TTS参数控制
                  const Text('音量:'),
                  Slider(
                    value: _ttsVolume,
                    onChanged: (value) {
                      setState(() {
                        _ttsVolume = value;
                      });
                    },
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    label: _ttsVolume.toStringAsFixed(1),
                  ),
                  
                  const Text('音调:'),
                  Slider(
                    value: _ttsPitch,
                    onChanged: (value) {
                      setState(() {
                        _ttsPitch = value;
                      });
                    },
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    label: _ttsPitch.toStringAsFixed(1),
                  ),
                  
                  const Text('语速:'),
                  Slider(
                    value: _ttsRate,
                    onChanged: (value) {
                      setState(() {
                        _ttsRate = value;
                      });
                    },
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    label: _ttsRate.toStringAsFixed(1),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // TTS控制按钮
                  Row(
                    children: [
                      Expanded(
                        child: BaseElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _isSpeaking ? null : _speak,
                          icon: const Icon(Icons.play_arrow, size: 20),
                          label: '朗读',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: BaseElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _isSpeaking ? _stopTts : null,
                          icon: const Icon(Icons.stop, size: 20),
                          label: '停止',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    Color color;
    IconData icon;
    
    switch (status) {
      case '正常':
      case '已连接':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case '失败':
      case '错误':
      case '无权限':
        color = Colors.red;
        icon = Icons.error;
        break;
      case '测试中...':
      case '录音中...':
      case '播放中...':
        color = Colors.orange;
        icon = Icons.access_time;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }
    
    return Icon(icon, color: color, size: 20);
  }

  Widget _buildTestSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assessment,
                    size: 48,
                    color: _testCompleted ? Colors.green : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _testCompleted ? '测试完成' : '测试进行中',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _testCompleted ? '查看测试结果总结' : '完成所有测试后查看总结',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_testCompleted)
            Card(
              elevation: 4,
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      '测试结果总结',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryItem('网络连接', _networkStatus, _networkStatus == '正常'),
                    _buildSummaryItem('麦克风', _recordingStatus, _recordingStatus == '正常'),
                    _buildSummaryItem('扬声器', _speakerStatus, _speakerStatus == '正常'),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            )
          else
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.info_outline, size: 48, color: Colors.blue),
                    const SizedBox(height: 16),
                    const Text(
                      '测试尚未完成',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '请完成所有三个测试项目后查看总结',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    '操作选项',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: BaseElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _resetAllTests,
                          icon: const Icon(Icons.refresh),
                          label: '重新测试',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: BaseElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.check),
                          label: '完成',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String name, String status, bool isSuccess) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(fontSize: 14)),
          Row(
            children: [
              Text(
                status,
                style: TextStyle(
                  color: isSuccess ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? Colors.green : Colors.red,
                size: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 网络连接测试
  Future<void> _testNetworkConnection() async {
    setState(() {
      _isTestingNetwork = true;
      _networkStatus = '测试中...';
      _currentTestStep = 1;
    });

    try {
      final dio = Dio();
      final startTime = DateTime.now();
      
      // 测试连接到常用的网络服务
      final response = await dio.get(
        'https://www.google.com/generate_204',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;
      final speed = (1024 / duration * 1000) / 1024; // 简化的速度计算
      
      if (response.statusCode == 204) {
        setState(() {
          _networkStatus = '正常';
          _networkSpeed = speed;
        });
      } else {
        setState(() {
          _networkStatus = '失败';
        });
      }
    } catch (e) {
      // 如果Google测试失败，尝试测试其他服务
      try {
        final response = await Dio().get(
          'https://www.baidu.com',
          options: Options(
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
        
        if (response.statusCode == 200) {
          setState(() {
            _networkStatus = '正常';
            _networkSpeed = 0.5; // 默认速度
          });
        } else {
          setState(() {
            _networkStatus = '失败';
          });
        }
      } catch (e) {
        setState(() {
          _networkStatus = '失败';
        });
      }
    } finally {
      setState(() {
        _isTestingNetwork = false;
        if (_currentTestStep == 1) _currentTestStep = 2;
      });
    }
  }

  // 麦克风测试
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        setState(() {
          _recordingStatus = '录音中...';
        });
        
        final tempDir = Directory.systemTemp;
        final filePath = '${tempDir.path}/test_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(const RecordConfig(), path: filePath);
        setState(() {
          _isRecording = true;
          _recordedFilePath = filePath;
        });
      } else {
        setState(() {
          _recordingStatus = '无权限';
        });
      }
    } catch (e) {
      setState(() {
        _recordingStatus = '失败';
        _isRecording = false;
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _hasRecordedAudio = path != null;
        _recordingStatus = path != null ? '正常' : '失败';
        if (_currentTestStep == 2) _currentTestStep = 3;
      });
    } catch (e) {
      setState(() {
        _recordingStatus = '失败';
        _isRecording = false;
      });
    }
  }

  // 扬声器测试
  Future<void> _playTestAudio() async {
    try {
      setState(() {
        _isPlaying = true;
        _speakerStatus = '播放中...';
      });
      
      if (_recordedFilePath != null && File(_recordedFilePath!).existsSync()) {
        // 播放录制的音频
        await _audioPlayer.play(DeviceFileSource(_recordedFilePath!));
      } else {
        // 播放在线测试音频
        const testAudioUrl = 'https://www.soundjay.com/misc/sounds/bell-ringing-05.wav';
        await _audioPlayer.play(UrlSource(testAudioUrl));
      }
      
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _speakerStatus = '正常';
            _testCompleted = true;
          });
        }
      });
    } catch (e) {
      setState(() {
        _isPlaying = false;
        _speakerStatus = '失败';
        _testCompleted = true;
      });
    }
  }

  void _resetAllTests() {
    setState(() {
      _networkStatus = '未测试';
      _networkSpeed = 0.0;
      _recordingStatus = '未测试';
      _speakerStatus = '未测试';
      _currentTestStep = 0;
      _testCompleted = false;
      _hasRecordedAudio = false;
      _recordedFilePath = null;
    });
  }
  
  /// 初始化TTS
  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    
    // 设置TTS事件处理
    _flutterTts.setStartHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = true;
          _ttsStatus = '正在播放';
        });
      }
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _ttsStatus = '播放完成';
        });
      }
    });

    _flutterTts.setCancelHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _ttsStatus = '已取消';
        });
      }
    });

    _flutterTts.setErrorHandler((msg) {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _ttsStatus = '错误: $msg';
        });
      }
    });

    // 获取可用语言
    await _getLanguages();
    
    // 设置初始参数
    await _flutterTts.setVolume(_ttsVolume);
    await _flutterTts.setPitch(_ttsPitch);
    await _flutterTts.setSpeechRate(_ttsRate);
  }

  Future<void> _getLanguages() async {
    try {
      final languages = await _flutterTts.getLanguages;
      if (mounted) {
        setState(() {
          _availableLanguages = languages;
          if (languages.isNotEmpty) {
            _selectedLanguage = languages.first;
          }
        });
      }
    } catch (e) {
      debugPrint('获取TTS语言失败: $e');
    }
  }

  Future<void> _speak() async {
    if (_ttsText == null || _ttsText!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入要朗读的文本')),
      );
      return;
    }

    try {
      await _flutterTts.setLanguage(_selectedLanguage ?? 'zh-CN');
      await _flutterTts.setVolume(_ttsVolume);
      await _flutterTts.setPitch(_ttsPitch);
      await _flutterTts.setSpeechRate(_ttsRate);
      
      await _flutterTts.speak(_ttsText!);
    } catch (e) {
      if (mounted) {
        setState(() {
          _ttsStatus = '播放失败: $e';
        });
      }
    }
  }

  Future<void> _stopTts() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('停止TTS失败: $e');
    }
  }

  void _onTtsTextChanged(String text) {
    setState(() {
      _ttsText = text;
    });
  }

}
