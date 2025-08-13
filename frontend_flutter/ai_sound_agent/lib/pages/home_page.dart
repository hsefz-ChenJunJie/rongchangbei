import 'package:flutter/material.dart';
import 'package:ai_sound_agent/widgets/shared/base.dart';

class HomePage extends BasePage {
  const HomePage({super.key})
      : super(
          title: '首页',
          showBottomNav: true,
          showBreadcrumb: true,
          showSettingsFab: true,
        );

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends BasePageState<HomePage> {
  @override
  Widget buildContent(BuildContext context) {
    return const SizedBox.shrink();
  }
}



