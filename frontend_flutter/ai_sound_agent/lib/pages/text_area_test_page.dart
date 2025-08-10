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