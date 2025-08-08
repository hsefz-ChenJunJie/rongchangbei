import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import '../widgets/shared/base.dart';

class DeviceTestPage extends BasePage {
  const DeviceTestPage({super.key})
      : super(
          title: '设备功能测试',
          showBottomNav: false,
          showBreadcrumb: true,
          showSettingsFab: false,
        );

  @override
  _DeviceTestPageState createState() => _DeviceTestPageState();
}

class _DeviceTestPageState extends BasePageState<DeviceTestPage> {
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
  
  // 测试进度
  int _currentTestStep = 0;
  bool _testCompleted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTestProgress(),
          const SizedBox(height: 20),
          _buildNetworkTestCard(),
          const SizedBox(height: 16),
          _buildMicrophoneTestCard(),
          const SizedBox(height: 16),
          _buildSpeakerTestCard(),
          const SizedBox(height: 24),
          _buildTestSummary(),
        ],
      ),
    );
  }

  Widget _buildTestProgress() {
    return Card(
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
    );
  }

  Widget _buildNetworkTestCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wifi, size: 24, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  '网络连接测试',
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
              const SizedBox(height: 4),
              Text(
                '下载速度: ${_networkSpeed.toStringAsFixed(2)} Mbps',
                style: const TextStyle(fontSize: 14),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isTestingNetwork ? null : _testNetworkConnection,
                icon: _isTestingNetwork
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.network_check),
                label: const Text('开始测试'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMicrophoneTestCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.mic, size: 24, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  '麦克风测试',
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRecording ? null : _startRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.mic),
                    label: const Text('开始录音'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRecording ? _stopRecording : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('停止录音'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeakerTestCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.volume_up, size: 24, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  '扬声器测试',
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_hasRecordedAudio || _recordingStatus == '正常') && !_isPlaying
                    ? _playTestAudio
                    : null,
                icon: _isPlaying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_hasRecordedAudio ? '播放录音' : '播放测试音频'),
              ),
            ),
          ],
        ),
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

  Widget _buildTestSummary() {
    if (!_testCompleted) return const SizedBox();
    
    return Card(
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
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _resetAllTests,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重新测试'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check),
                    label: const Text('完成'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
}