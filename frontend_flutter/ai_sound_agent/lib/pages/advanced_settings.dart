import 'package:flutter/material.dart';
import '../widgets/shared/base.dart';

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
  @override
  Widget buildContent(BuildContext context) {
    return const Center(
      child: Text(
        '高级设置页面',
        style: TextStyle(fontSize: 24),
      ),
    );
  }
}