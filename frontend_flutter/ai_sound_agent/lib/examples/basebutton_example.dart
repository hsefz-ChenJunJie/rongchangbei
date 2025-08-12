import 'package:flutter/material.dart';
import 'package:ai_sound_agent/widgets/shared/basebutton.dart';

// 使用示例
class BaseButtonExamples extends StatelessWidget {
  const BaseButtonExamples({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Base Button Examples')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 20,
          children: [
            // 只有图标
            BaseButton(
              icon: Icons.favorite,
              primaryColor: Colors.red,
              secondaryColor: Colors.red.shade700,
              onPressed: () => print('Favorite button pressed'),
            ),
            
            // 只有文字
            BaseButton(
              text: '点击我',
              primaryColor: Colors.blue,
              secondaryColor: Colors.blue.shade700,
              onPressed: () => print('Text button pressed'),
            ),
            
            // 图标和文字
            BaseButton(
              icon: Icons.send,
              text: '发送',
              primaryColor: Colors.green,
              secondaryColor: Colors.green.shade700,
              onPressed: () => print('Send button pressed'),
            ),
            
            // 自定义大小
            BaseButton(
              icon: Icons.settings,
              text: '设置',
              primaryColor: Colors.purple,
              secondaryColor: Colors.purple.shade700,
              width: 200,
              height: 60,
              onPressed: () => print('Settings button pressed'),
            ),
          ],
        ),
      ),
    );
  }
}