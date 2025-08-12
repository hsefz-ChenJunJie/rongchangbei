// 引入必要的库
import 'package:flutter/material.dart';
import 'package:ai_sound_agent/widgets/shared/base_elevated_button.dart';

// 使用示例
class BaseElevatedButtonExamples extends StatelessWidget {
  const BaseElevatedButtonExamples({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Base Elevated Button Examples')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          spacing: 16,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 基本用法
            BaseElevatedButton(
              onPressed: () {},
              child: const Text('基础按钮'),
            ),

            // 图标按钮
            BaseElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: '添加',
            ),

            // 特殊颜色按钮
            BaseElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.delete),
              label: '删除',
              isSpecial: true,
              backgroundColor: Colors.red,
            ),

            // 禁用状态
            const BaseElevatedButton(
              onPressed: null,
              child: Text('禁用按钮'),
            ),

            // 自定义尺寸
            BaseElevatedButton(
              onPressed: () {},
              width: 200,
              height: 50,
              child: const Text('自定义尺寸'),
            ),

            // 扩展宽度
            BaseElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.save),
              label: '保存',
              expanded: true,
            ),
          ],
        ),
      ),
    );
  }
}