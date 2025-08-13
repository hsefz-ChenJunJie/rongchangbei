import 'package:flutter/material.dart';
import '../widgets/shared/base_text_area.dart';

class TextAreaTestPage extends StatelessWidget {
  const TextAreaTestPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BaseTextArea 测试页面'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const BaseTextAreaExamples(),
    );
  }
}

// 使用示例
class BaseTextAreaExamples extends StatefulWidget {
  const BaseTextAreaExamples({Key? key}) : super(key: key);

  @override
  State<BaseTextAreaExamples> createState() => _BaseTextAreaExamplesState();
}

class _BaseTextAreaExamplesState extends State<BaseTextAreaExamples> {
  final TextEditingController _controller1 = TextEditingController(text: '');
  final TextEditingController _controller2 = TextEditingController(text: '这是一段预设的多行文本内容。\n可以包含多行文字，\n用于展示文本域的预设内容效果。');
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
      appBar: AppBar(title: const Text('Base Text Area Examples')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          spacing: 24,
          children: [
            // 基本用法
            BaseTextArea(
              label: '评论内容',
              placeholder: '请输入您的评论内容...',
              onChanged: (value) {
                print('评论: $value');
              },
            ),

            // 带图标
            BaseTextArea(
              label: '详细描述',
              placeholder: '请详细描述您的问题或建议...',
              maxLines: 4,
              minLines: 2,
              maxLength: 200,
              icon: const Icon(Icons.description),
              onChanged: (value) {
                print('描述: $value');
              },
            ),

            // 带图标和预设文本
            BaseTextArea(
              label: '反馈内容',
              text: '这是一段预设的多行文本内容。\n可以包含多行文字，\n用于展示文本域的预设内容效果。',
              placeholder: '请输入反馈内容...',
              maxLines: 6,
              icon: const Icon(Icons.feedback),
              onChanged: (value) {
                print('反馈: $value');
              },
            ),

            // 自定义样式
            BaseTextArea(
              label: '备注信息',
              placeholder: '请输入备注信息...',
              maxLines: 3,
              borderColor: Colors.purple,
              focusColor: Colors.purple,
              labelColor: Colors.purple,
              backgroundColor: Colors.purple.shade50,
              icon: const Icon(Icons.note, color: Colors.purple),
              onChanged: (value) {
                print('备注: $value');
              },
            ),

            // 禁用状态
            BaseTextArea(
              label: '禁用文本域',
              text: '这是禁用状态的文本内容，\n用户无法进行编辑。',
              placeholder: '无法输入',
              enabled: false,
              maxLines: 3,
              icon: const Icon(Icons.lock),
            ),

            // 展开填充
            BaseTextArea(
              label: '自适应高度',
              placeholder: '此文本域会根据内容自动调整高度...',
              expands: true,
              maxLines: null,
              minLines: null,
              maxLength: 500,
              icon: const Icon(Icons.auto_awesome),
              onChanged: (value) {
                print('自适应: $value');
              },
            ),

            // 显示当前值
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BaseTextArea(
                  label: '动态显示',
                  placeholder: '输入内容会显示在下面...',
                  text: _text3,
                  maxLines: 3,
                  maxLength: 100,
                  icon: const Icon(Icons.edit),
                  onChanged: (value) {
                    setState(() {
                      _text3 = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '当前输入:\n$_text3',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
              ],
            ),

            // 操作按钮
            Row(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _controller1.text = '这是通过按钮设置的新文本内容，\n包含多行文本，\n用于演示程序化设置文本的功能。';
                    });
                  },
                  child: const Text('设置描述文本'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _controller1.clear();
                  },
                  child: const Text('清空描述'),
                ),
                ElevatedButton(
                  onPressed: () {
                    FocusScope.of(context).requestFocus(FocusNode());
                  },
                  child: const Text('收起键盘'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}