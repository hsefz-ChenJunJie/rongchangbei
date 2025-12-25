import 'package:flutter/material.dart';
import '../widgets/shared/base.dart';
import '../app/route.dart';
import '../services/userdata_services.dart';

class AdvancedSettingsPage extends BasePage {
  const AdvancedSettingsPage({super.key})
      : super(
          title: '高级设置',
          showBottomNav: true,
          showBreadcrumb: true,
          showSettingsFab: false,
        );

  @override
  State<AdvancedSettingsPage> createState() => _AdvancedSettingsPageState();
}

class _AdvancedSettingsPageState extends BasePageState<AdvancedSettingsPage> {
  bool _alwaysSendAsMyself = false;
  bool _llmResponseSameScreen = false;
  bool _clickToSwitch = false;
  Userdata _userData = Userdata();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    await _userData.loadUserData();
    setState(() {
      _alwaysSendAsMyself = _userData.preferences['always_send_as_myself'] ?? false;
      _llmResponseSameScreen = _userData.preferences['llm_response_same_screen'] ?? false;
      _clickToSwitch = _userData.preferences['click_to_switch'] ?? false;
    });
  }

  Future<void> _saveAlwaysSendAsMyself(bool value) async {
    await _userData.updatePreference('always_send_as_myself', value);
    setState(() {
      _alwaysSendAsMyself = value;
    });
  }

  Future<void> _saveLlmResponseSameScreen(bool value) async {
    await _userData.updatePreference('llm_response_same_screen', value);
    
    if (value) { // 如果llm同屏开启
      // 自动将clickToSwitch设置为false
      await _userData.updatePreference('click_to_switch', false);
      setState(() {
        _llmResponseSameScreen = value;
        _clickToSwitch = false; // 同时更新本地状态
      });
    } else {
      setState(() {
        _llmResponseSameScreen = value;
      });
    }
  }

  Future<void> _saveClickToSwitch(bool value) async {
    await _userData.updatePreference('click_to_switch', value);
    setState(() {
      _clickToSwitch = value;
    });
  }

  @override
  Widget buildContent(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.lightbulb_outline),
            title: const Text('默认建议意见'),
            subtitle: const Text('管理和编辑默认建议意见'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.pushNamed(context, Routes.defaultSuggestions);
            },
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.person),
            title: const Text('文本发送时恒为自己'),
            subtitle: const Text('发送消息时始终使用"我自己"身份'),
            trailing: Switch(
              value: _alwaysSendAsMyself,
              onChanged: _saveAlwaysSendAsMyself,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.screen_share),
            title: const Text('llm response同屏'),
            subtitle: const Text('在同屏模式下显示LLM响应'),
            trailing: Switch(
              value: _llmResponseSameScreen,
              onChanged: _saveLlmResponseSameScreen,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.sync_alt),
            title: const Text('点击后切换'),
            subtitle: const Text('点击建议意见后自动切换到LLM响应标签页'),
            trailing: Switch(
              value: _clickToSwitch, // 显示实际的clickToSwitch值
              onChanged: _llmResponseSameScreen 
                ? null // 当llm同屏开启时禁用切换
                : (bool value) {
                    // 当llm同屏关闭时才允许更改
                    _saveClickToSwitch(value);
                  },
            ),
          ),
        ),
      ],
    );
  }
}