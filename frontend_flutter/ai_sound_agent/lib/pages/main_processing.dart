import 'package:flutter/material.dart';
import 'package:ai_sound_agent/widgets/shared/base.dart';

class MainProcessingPage extends BasePage {
  const MainProcessingPage({super.key})
      : super(
          title: '首页',
          showBottomNav: true,
          showBreadcrumb: true,
          showSettingsFab: true,
        );

  @override
  _MainProcessingPageState createState() => _MainProcessingPageState();
}

class _MainProcessingPageState extends BasePageState<MainProcessingPage> {
  @override
  Widget buildContent(BuildContext context) {
    return const SizedBox.shrink();
  }
}



