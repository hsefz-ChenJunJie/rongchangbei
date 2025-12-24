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
    });
  }

  Future<void> _saveAlwaysSendAsMyself(bool value) async {
    await _userData.updatePreference('always_send_as_myself', value);
    setState(() {
      _alwaysSendAsMyself = value;
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
      ],
    );
  }
}