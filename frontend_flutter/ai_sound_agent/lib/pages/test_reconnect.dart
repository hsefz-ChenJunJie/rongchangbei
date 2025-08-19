// 测试重连机制的简单示例
// 这个文件可以用来测试WebSocket重连功能

import 'package:flutter/material.dart';
import 'package:ai_sound_agent/pages/main_processing.dart';

class ReconnectTestWidget extends StatelessWidget {
  const ReconnectTestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MainProcessingPage(),
    );
  }
}

// 使用说明：
// 1. 正常启动应用并建立WebSocket连接
// 2. 等待连接成功后，可以手动断开网络来测试重连机制
// 3. 观察橙色提示条显示重连进度
// 4. 重连成功后提示条会消失，session_id保持不变