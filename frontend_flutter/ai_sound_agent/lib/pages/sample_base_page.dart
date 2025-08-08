import 'package:flutter/material.dart';
import '../widgets/shared/base.dart';

class SampleBasePage extends BasePage {
  const SampleBasePage({Key? key}) : super(
    key: key,
    title: '示例页面',
    showBottomNav: true,
    showBreadcrumb: true,
    showSettingsFab: true,
  );

  @override
  _SampleBasePageState createState() => _SampleBasePageState();
}

class _SampleBasePageState extends BasePageState<SampleBasePage> {
  int _counter = 0;

  @override
  Widget buildContent(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '这是使用BasePage的示例页面',
            style: TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 20),
          Text(
            '计数器: $_counter',
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _counter++;
              });
            },
            child: const Text('增加计数'),
          ),
        ],
      ),
    );
  }

  @override
  void onPageChange(int index) {
    super.onPageChange(index);
    // 这里可以根据不同的底部导航索引切换内容
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('切换到页面: ${bottomNavItems[index].label}'),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }
}