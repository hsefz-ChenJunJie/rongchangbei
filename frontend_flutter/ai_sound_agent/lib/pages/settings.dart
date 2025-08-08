import 'package:flutter/material.dart';
import '../widgets/shared/base.dart';

class Settings extends BasePage {
  const Settings({Key? key})
      : super(
          key: key,
          title: '设置',
          showBottomNav: true,
          showBreadcrumb: true,
          showSettingsFab: false,
        );

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends BasePageState<Settings> {
  @override
  Widget buildContent(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('收到参数: ${args['message'] ?? '无参数'}'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, '操作成功'); // 返回结果
                },
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}