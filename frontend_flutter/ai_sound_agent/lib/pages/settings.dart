import 'package:flutter/material.dart';

class Settings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            Text('收到参数: ${args['message']}'),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, '操作成功'); // 返回结果
              },
              child: Text('返回'),
            ),
          ],
        ),
      ),
    );
  }
}