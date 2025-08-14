// 引入必要的库
import 'package:flutter/material.dart';
import 'package:ai_sound_agent/widgets/shared/base_line_input.dart';
import 'package:ai_sound_agent/widgets/shared/base_elevated_button.dart';

// 使用示例
class BaseLineInputExamples extends StatefulWidget {
  const BaseLineInputExamples({Key? key}) : super(key: key);

  @override
  State<BaseLineInputExamples> createState() => _BaseLineInputExamplesState();
}

class _BaseLineInputExamplesState extends State<BaseLineInputExamples> {
  final TextEditingController _controller1 = TextEditingController(text: '');
  final TextEditingController _controller2 = TextEditingController(text: '预设文本');
  String _text3 = '';

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Base Line Input Examples')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          spacing: 24,
          children: [
            // 基本用法
            BaseLineInput(
              label: '用户名',
              placeholder: '请输入用户名',
              onChanged: (value) {
                print('用户名: $value');
              },
            ),

            // 带图标
            BaseLineInput(
              label: '邮箱',
              placeholder: '请输入邮箱地址',
              keyboardType: TextInputType.emailAddress,
              icon: const Icon(Icons.email),
              onChanged: (value) {
                print('邮箱: $value');
              },
            ),

            // 带图标和预设文本
            BaseLineInput(
              label: '描述',
              text: '预设文本',
              placeholder: '请输入描述',
              maxLines: 3,
              icon: const Icon(Icons.description),
              onChanged: (value) {
                print('描述: $value');
              },
            ),

            // 密码输入带图标
            BaseLineInput(
              label: '密码',
              placeholder: '请输入密码',
              obscureText: true,
              icon: const Icon(Icons.lock),
              onChanged: (value) {
                print('密码: $value');
              },
            ),

            // 自定义样式带图标
            BaseLineInput(
              label: '电话号码',
              placeholder: '请输入电话号码',
              keyboardType: TextInputType.phone,
              borderColor: Colors.purple,
              focusColor: Colors.purple,
              labelColor: Colors.purple,
              icon: const Icon(Icons.phone, color: Colors.purple),
              onChanged: (value) {
                print('电话: $value');
              },
            ),

            // 禁用状态带图标
            BaseLineInput(
              label: '禁用输入',
              text: '这是禁用状态的文本',
              placeholder: '无法输入',
              enabled: false,
              icon: const Icon(Icons.lock),
            ),

            // 显示当前值带图标
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BaseLineInput(
                  label: '动态显示',
                  placeholder: '输入内容会显示在下面',
                  text: _text3,
                  icon: const Icon(Icons.edit),
                  onChanged: (value) {
                    setState(() {
                      _text3 = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '当前输入: $_text3',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),

            // 操作按钮
            Row(
              spacing: 8,
              children: [
                BaseElevatedButton(
                  onPressed: () {
                    setState(() {
                      _controller1.text = '新设置的文本';
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('设置邮箱文本'),
                ),
                BaseElevatedButton(
                  onPressed: () {
                    _controller1.clear();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('清空邮箱'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}