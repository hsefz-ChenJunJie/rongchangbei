import 'package:flutter/material.dart';
import 'package:ai_sound_agent/widgets/shared/base.dart';
import 'package:ai_sound_agent/app/route.dart';
import 'package:ai_sound_agent/pages/device_test_page.dart';
import 'package:ai_sound_agent/pages/tabs_demo_simple.dart';


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
  final List<String> _pageTitles = const [
    '首页',
    '发现',
    '我的',
  ];

  int _currentPageIndex = 0;

  @override
  Widget buildContent(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '当前页面: ${_pageTitles[_currentPageIndex]}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                '这是使用BasePage的基础页面',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DeviceTestPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.devices),
                label: const Text('设备功能测试'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TabsDemoSimple(),
                ),
              );
            },
            icon: const Icon(Icons.tab),
            label: const Text('Tab组件演示'),
          ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // 测试面包屑导航
                  final routeState = AppRouteState();
                  routeState.push('settings');
                  setState(() {});
                },
                child: const Text('测试面包屑导航'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void onPageChange(int index) {
    super.onPageChange(index);
    setState(() {
      _currentPageIndex = index;
    });
  }

  // 使用默认的底部导航栏（来自constants.dart）
  // 如需自定义，可以重写此方法
}
