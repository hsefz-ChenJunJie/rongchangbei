import 'package:flutter/material.dart';
import '../widgets/shared/popup.dart';
import '../services/theme_manager.dart';

class PopupExample extends StatefulWidget {
  const PopupExample({Key? key}) : super(key: key);

  @override
  State<PopupExample> createState() => _PopupExampleState();
}

class _PopupExampleState extends State<PopupExample> {
  final GlobalKey<PopupState> _popupKey = GlobalKey<PopupState>();
  final ThemeManager _themeManager = ThemeManager();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Popup 示例'),
      ),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    _popupKey.currentState?.show();
                  },
                  child: const Text('显示弹出框'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    _popupKey.currentState?.toggle();
                  },
                  child: const Text('切换显示/隐藏'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    final isShown = _popupKey.currentState?.isShown() ?? false;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isShown ? '弹出框正在显示' : '弹出框已隐藏'),
                      ),
                    );
                  },
                  child: const Text('检查状态'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // 切换主题颜色示例
                    final colors = ['blue', 'green', 'red', 'purple', 'orange'];
                    final current = _themeManager.currentThemeColor.name;
                    final nextIndex = (colors.indexOf(current) + 1) % colors.length;
                    _themeManager.updateTheme(colors[nextIndex]);
                  },
                  child: const Text('切换主题颜色'),
                ),
              ],
            ),
          ),
          Popup(
            key: _popupKey,
            width: 300,
            height: 200,
            backgroundColor: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 48, color: Colors.green),
                  SizedBox(height: 16),
                  Text(
                    '这是一个弹出式模态框',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '点击右上角的关闭按钮或背景区域可以关闭',
                    style: TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}